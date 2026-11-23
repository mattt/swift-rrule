import Foundation

extension RecurrenceRule {
    /// An error that describes why a string isn't a valid recurrence rule.
    public enum ParseError: Error, Equatable, Sendable {
        /// The string is empty.
        case emptyString
        /// A semicolon-separated component is not of the form `KEY=VALUE`.
        case malformedComponent(String)
        /// A rule part name isn't one of the RFC 5545 rule parts.
        case unknownRulePart(String)
        /// A rule part appears more than once.
        case duplicateRulePart(String)
        /// The required `FREQ` rule part is absent.
        case missingFrequency
        /// The `FREQ` value isn't one of the RFC 5545 frequencies.
        case invalidFrequency(String)
        /// A rule part value is malformed or outside its range.
        case invalidValue(rulePart: String, value: String)
        /// The rule parts are valid alone,
        /// but RFC 5545 doesn't permit them together,
        /// as with `COUNT` and `UNTIL`.
        case invalidCombination(String)
    }

    /// Creates a recurrence rule by parsing an RFC 5545 recurrence rule string,
    /// such as `FREQ=HOURLY;INTERVAL=3`.
    ///
    /// The parser accepts an optional `RRULE:` prefix,
    /// and ignores the case of rule part names, frequencies, and weekdays.
    /// It rejects a rule part that is unknown, repeated, or malformed,
    /// and a value outside the range that RFC 5545 permits,
    /// because a description of the rule would leave out that part.
    /// To learn why a string isn't valid, use ``parse(_:)``.
    ///
    /// - Parameter string: The recurrence rule string to parse.
    public init?(parsing string: String) {
        guard let parsed = try? RecurrenceRuleParser.parse(string) else { return nil }
        self = parsed
    }

    /// Parses an RFC 5545 recurrence rule string,
    /// and reports why a string isn't valid.
    ///
    /// The parser accepts the same strings as ``init(parsing:)``.
    ///
    /// - Parameter string: The recurrence rule string to parse.
    /// - Returns: The recurrence rule that the string describes.
    /// - Throws: ``ParseError`` if the string isn't a valid recurrence rule.
    public static func parse(_ string: String) throws -> RecurrenceRule {
        try RecurrenceRuleParser.parse(string)
    }
}

/// Parses RFC 5545 recurrence rule strings.
enum RecurrenceRuleParser {
    static func parse(_ rawInput: String) throws -> RecurrenceRule {
        var input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty {
            throw RecurrenceRule.ParseError.emptyString
        }

        if input.uppercased().hasPrefix("RRULE:") {
            input = String(input.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if input.isEmpty {
                throw RecurrenceRule.ParseError.emptyString
            }
        }

        var frequency: RecurrenceRule.Frequency?
        var interval = 1
        var count: Int?
        var until: Date?
        var bySeconds: [Int] = []
        var byMinutes: [Int] = []
        var byHours: [Int] = []
        var byWeekdays: [RecurrenceRule.WeekdayRule] = []
        var byMonthDays: [Int] = []
        var byYearDays: [Int] = []
        var byWeeks: [Int] = []
        var byMonths: [Int] = []
        var bySetPositions: [Int] = []
        var weekStart: RecurrenceRule.Weekday = .monday
        var seenKeys: Set<String> = []

        for component in input.split(separator: ";", omittingEmptySubsequences: false) {
            let pair = component.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2, !pair[0].isEmpty, !pair[1].isEmpty else {
                throw RecurrenceRule.ParseError.malformedComponent(String(component))
            }
            let key = pair[0].trimmingCharacters(in: .whitespaces).uppercased()
            let value = pair[1].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else {
                throw RecurrenceRule.ParseError.malformedComponent(String(component))
            }
            guard seenKeys.insert(key).inserted else {
                throw RecurrenceRule.ParseError.duplicateRulePart(key)
            }

            switch key {
            case "FREQ":
                guard let parsed = RecurrenceRule.Frequency(rawValue: value.uppercased()) else {
                    throw RecurrenceRule.ParseError.invalidFrequency(value)
                }
                frequency = parsed
            case "INTERVAL":
                interval = try parseInteger(value, rulePart: key)
                guard interval >= 1 else {
                    throw RecurrenceRule.ParseError.invalidValue(rulePart: key, value: value)
                }
            case "COUNT":
                count = try parseInteger(value, rulePart: key)
                guard let count, count >= 1 else {
                    throw RecurrenceRule.ParseError.invalidValue(rulePart: key, value: value)
                }
            case "UNTIL":
                guard let parsed = parseUntilDate(value) else {
                    throw RecurrenceRule.ParseError.invalidValue(rulePart: key, value: value)
                }
                until = parsed
            case "BYDAY":
                byWeekdays = try parseByDay(value)
            case "BYMONTHDAY":
                byMonthDays = try parseSignedOrdinalList(value, rulePart: key, limit: 31)
            case "BYYEARDAY":
                byYearDays = try parseSignedOrdinalList(value, rulePart: key, limit: 366)
            case "BYWEEKNO":
                byWeeks = try parseSignedOrdinalList(value, rulePart: key, limit: 53)
            case "BYMONTH":
                byMonths = try parseIntegerList(value, rulePart: key, range: 1 ... 12)
            case "BYSETPOS":
                bySetPositions = try parseSignedOrdinalList(value, rulePart: key, limit: 366)
            case "BYHOUR":
                byHours = try parseIntegerList(value, rulePart: key, range: 0 ... 23)
            case "BYMINUTE":
                byMinutes = try parseIntegerList(value, rulePart: key, range: 0 ... 59)
            case "BYSECOND":
                bySeconds = try parseIntegerList(value, rulePart: key, range: 0 ... 60)
            case "WKST":
                guard let parsed = RecurrenceRule.Weekday(rawValue: value.uppercased()) else {
                    throw RecurrenceRule.ParseError.invalidValue(rulePart: key, value: value)
                }
                weekStart = parsed
            default:
                throw RecurrenceRule.ParseError.unknownRulePart(key)
            }
        }

        guard let frequency else {
            throw RecurrenceRule.ParseError.missingFrequency
        }
        if count != nil && until != nil {
            throw RecurrenceRule.ParseError.invalidCombination("COUNT and UNTIL must not appear in the same rule.")
        }
        if !bySetPositions.isEmpty {
            let hasCompanion =
                !bySeconds.isEmpty || !byMinutes.isEmpty || !byHours.isEmpty
                || !byWeekdays.isEmpty || !byMonthDays.isEmpty || !byYearDays.isEmpty
                || !byWeeks.isEmpty || !byMonths.isEmpty
            if !hasCompanion {
                throw RecurrenceRule.ParseError.invalidCombination("BYSETPOS requires another BYxxx rule part.")
            }
        }

        guard
            let rule = RecurrenceRule.validated(
                frequency: frequency,
                interval: interval,
                count: count,
                until: until,
                bySeconds: bySeconds,
                byMinutes: byMinutes,
                byHours: byHours,
                byWeekdays: byWeekdays,
                byMonthDays: byMonthDays,
                byYearDays: byYearDays,
                byWeeks: byWeeks,
                byMonths: byMonths,
                bySetPositions: bySetPositions,
                weekStart: weekStart
            )
        else {
            throw RecurrenceRule.ParseError.invalidCombination("Rule parts form an invalid combination.")
        }
        return rule
    }

    private static func parseInteger(_ value: String, rulePart: String) throws -> Int {
        guard let parsed = Int(value) else {
            throw RecurrenceRule.ParseError.invalidValue(rulePart: rulePart, value: value)
        }
        return parsed
    }

    private static func listItems(_ value: String, rulePart: String) throws -> [String] {
        let items = value.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        if items.isEmpty || items.contains(where: \.isEmpty) {
            throw RecurrenceRule.ParseError.invalidValue(rulePart: rulePart, value: value)
        }
        return items
    }

    private static func parseIntegerList(_ value: String, rulePart: String, range: ClosedRange<Int>) throws -> [Int] {
        try listItems(value, rulePart: rulePart).map { item in
            let parsed = try parseInteger(item, rulePart: rulePart)
            guard range.contains(parsed) else {
                throw RecurrenceRule.ParseError.invalidValue(rulePart: rulePart, value: value)
            }
            return parsed
        }
    }

    private static func parseSignedOrdinalList(_ value: String, rulePart: String, limit: Int) throws -> [Int] {
        try listItems(value, rulePart: rulePart).map { item in
            let parsed = try parseInteger(item, rulePart: rulePart)
            guard RecurrenceRule.isValidSignedOrdinal(parsed, limit: limit) else {
                throw RecurrenceRule.ParseError.invalidValue(rulePart: rulePart, value: value)
            }
            return parsed
        }
    }

    private static func parseByDay(_ value: String) throws -> [RecurrenceRule.WeekdayRule] {
        try listItems(value, rulePart: "BYDAY").map { item in
            guard item.count >= 2 else {
                throw RecurrenceRule.ParseError.invalidValue(rulePart: "BYDAY", value: value)
            }
            let dayCode = String(item.suffix(2)).uppercased()
            guard let weekday = RecurrenceRule.Weekday(rawValue: dayCode) else {
                throw RecurrenceRule.ParseError.invalidValue(rulePart: "BYDAY", value: value)
            }
            let prefix = String(item.dropLast(2))
            var occurrence: Int?
            if !prefix.isEmpty {
                let parsed = try parseInteger(prefix, rulePart: "BYDAY")
                guard RecurrenceRule.isValidSignedOrdinal(parsed, limit: 53) else {
                    throw RecurrenceRule.ParseError.invalidValue(rulePart: "BYDAY", value: value)
                }
                occurrence = parsed
            }
            return RecurrenceRule.WeekdayRule(weekday: weekday, occurrence: occurrence)
        }
    }

    private static func parseUntilDate(_ value: String) -> Date? {
        // Format 1: YYYYMMDD'T'HHMMSS'Z' in UTC.
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        // Formats 2 and 3 have no time zone,
        // so they resolve in the current time zone,
        // as a floating or date-only `DTSTART` does.
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        if let date = localFormatter.date(from: value) {
            return date
        }

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateOnlyFormatter.dateFormat = "yyyyMMdd"
        return dateOnlyFormatter.date(from: value)
    }
}
