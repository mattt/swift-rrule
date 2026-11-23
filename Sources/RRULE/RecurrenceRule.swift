import Foundation

/// An iCalendar recurrence rule, as RFC 5545 defines it.
///
/// A recurrence rule describes a repeating pattern.
/// Some patterns take part of their meaning
/// from the start date (`DTSTART`) of the event that carries the rule.
/// For example, `FREQ=MONTHLY` repeats on the day of the month of the start date.
/// To name that day in a description,
/// pass the start date to ``localizedDescription(in:startingAt:)``.
///
/// To list the dates of a rule, call ``recurrences(of:in:calendar:)``.
///
/// Every stored value is in the range that RFC 5545 defines.
/// The initializer that takes the values of rule parts
/// traps on a value outside its range,
/// as other Foundation value types trap on invalid arguments.
/// To read untrusted text, use ``parse(_:)`` or ``init(parsing:)``,
/// which report invalid input without trapping.
public struct RecurrenceRule: Sendable, Hashable {
    /// How often a rule repeats, from the `FREQ` rule part.
    public enum Frequency: String, Sendable, Hashable, Codable, CaseIterable {
        /// Repeats every second, or every `interval` seconds.
        case secondly = "SECONDLY"
        /// Repeats every minute, or every `interval` minutes.
        case minutely = "MINUTELY"
        /// Repeats every hour, or every `interval` hours.
        case hourly = "HOURLY"
        /// Repeats every day, or every `interval` days.
        case daily = "DAILY"
        /// Repeats every week, or every `interval` weeks.
        case weekly = "WEEKLY"
        /// Repeats every month, or every `interval` months.
        case monthly = "MONTHLY"
        /// Repeats every year, or every `interval` years.
        case yearly = "YEARLY"
    }

    /// A day of the week, with its two-letter RFC 5545 code as the raw value.
    public enum Weekday: String, Sendable, Hashable, Codable, CaseIterable {
        /// Sunday (`SU`).
        case sunday = "SU"
        /// Monday (`MO`).
        case monday = "MO"
        /// Tuesday (`TU`).
        case tuesday = "TU"
        /// Wednesday (`WE`).
        case wednesday = "WE"
        /// Thursday (`TH`).
        case thursday = "TH"
        /// Friday (`FR`).
        case friday = "FR"
        /// Saturday (`SA`).
        case saturday = "SA"

        /// The `Calendar` weekday component value, where Sunday is 1.
        var calendarWeekday: Int {
            switch self {
            case .sunday: 1
            case .monday: 2
            case .tuesday: 3
            case .wednesday: 4
            case .thursday: 5
            case .friday: 6
            case .saturday: 7
            }
        }

        /// Creates a weekday from a `Calendar` weekday component value, where Sunday is 1.
        init?(calendarWeekday: Int) {
            switch calendarWeekday {
            case 1: self = .sunday
            case 2: self = .monday
            case 3: self = .tuesday
            case 4: self = .wednesday
            case 5: self = .thursday
            case 6: self = .friday
            case 7: self = .saturday
            default: return nil
            }
        }
    }

    /// An entry of the `BYDAY` rule part,
    /// such as every Monday (`MO`) or the first Sunday (`1SU`).
    public struct WeekdayRule: Sendable, Hashable, Codable {
        /// The day of the week.
        public let weekday: Weekday

        /// The occurrence of the weekday within the month or year,
        /// or `nil` for every occurrence.
        ///
        /// A positive value counts from the start of the period,
        /// and a negative value counts back from the end,
        /// so `-1` is the last occurrence.
        public let occurrence: Int?

        /// Creates an entry of the `BYDAY` rule part.
        ///
        /// - Parameters:
        ///   - weekday: The day of the week.
        ///   - occurrence: The occurrence of the weekday within the month or year,
        ///     or `nil` for every occurrence.
        /// - Precondition: `occurrence` is in `-53...-1` or `1...53`.
        public init(weekday: Weekday, occurrence: Int? = nil) {
            if let occurrence {
                precondition(
                    RecurrenceRule.isValidSignedOrdinal(occurrence, limit: 53),
                    "Weekday occurrence must be in -53...-1 or 1...53."
                )
            }
            self.weekday = weekday
            self.occurrence = occurrence
        }

        /// The RFC 5545 form of the entry, such as `1SU`.
        var stringRepresentation: String {
            if let occurrence {
                return "\(occurrence)\(weekday.rawValue)"
            }
            return weekday.rawValue
        }
    }

    /// How often the rule repeats (`FREQ`).
    public let frequency: Frequency

    /// The number of frequency periods between repetitions (`INTERVAL`),
    /// which is 1 or more.
    public let interval: Int

    /// The number of occurrences after which the rule ends (`COUNT`),
    /// or `nil` if the count doesn't limit the rule.
    public let count: Int?

    /// The last date on which the rule can occur (`UNTIL`),
    /// or `nil` if no date limits the rule.
    public let until: Date?

    /// The seconds of the minute, in `0...60` (`BYSECOND`).
    public let bySeconds: [Int]

    /// The minutes of the hour, in `0...59` (`BYMINUTE`).
    public let byMinutes: [Int]

    /// The hours of the day, in `0...23` (`BYHOUR`).
    public let byHours: [Int]

    /// The days of the week, each with an optional occurrence (`BYDAY`).
    public let byWeekdays: [WeekdayRule]

    /// The days of the month, in `-31...-1` or `1...31` (`BYMONTHDAY`).
    ///
    /// A negative value counts back from the end of the month.
    public let byMonthDays: [Int]

    /// The days of the year, in `-366...-1` or `1...366` (`BYYEARDAY`).
    ///
    /// A negative value counts back from the end of the year.
    public let byYearDays: [Int]

    /// The weeks of the year, in `-53...-1` or `1...53` (`BYWEEKNO`).
    ///
    /// A negative value counts back from the end of the year.
    public let byWeeks: [Int]

    /// The months of the year, in `1...12` (`BYMONTH`).
    public let byMonths: [Int]

    /// The positions within each set of occurrences that the rule keeps,
    /// in `-366...-1` or `1...366` (`BYSETPOS`).
    ///
    /// A negative value counts back from the end of the set.
    public let bySetPositions: [Int]

    /// The day on which the week starts (`WKST`).
    public let weekStart: Weekday

    /// Creates a recurrence rule from the values of its rule parts.
    ///
    /// The initializer removes repeated values from each list
    /// and keeps the first appearance of each value.
    ///
    /// - Parameters:
    ///   - frequency: How often the rule repeats.
    ///   - interval: The number of frequency periods between repetitions.
    ///   - count: The number of occurrences after which the rule ends.
    ///   - until: The last date on which the rule can occur.
    ///   - bySeconds: The seconds of the minute, in `0...60`.
    ///   - byMinutes: The minutes of the hour, in `0...59`.
    ///   - byHours: The hours of the day, in `0...23`.
    ///   - byWeekdays: The days of the week.
    ///   - byMonthDays: The days of the month, in `-31...-1` or `1...31`.
    ///   - byYearDays: The days of the year, in `-366...-1` or `1...366`.
    ///   - byWeeks: The weeks of the year, in `-53...-1` or `1...53`.
    ///   - byMonths: The months of the year, in `1...12`.
    ///   - bySetPositions: The positions within each set of occurrences,
    ///     in `-366...-1` or `1...366`.
    ///   - weekStart: The day on which the week starts.
    /// - Precondition: Every value is in its range,
    ///   `interval` is 1 or more,
    ///   `count` is 1 or more and appears without `until`,
    ///   and `bySetPositions` appears with at least one other `by` list.
    public init(
        frequency: Frequency,
        interval: Int = 1,
        count: Int? = nil,
        until: Date? = nil,
        bySeconds: [Int] = [],
        byMinutes: [Int] = [],
        byHours: [Int] = [],
        byWeekdays: [WeekdayRule] = [],
        byMonthDays: [Int] = [],
        byYearDays: [Int] = [],
        byWeeks: [Int] = [],
        byMonths: [Int] = [],
        bySetPositions: [Int] = [],
        weekStart: Weekday = .monday
    ) {
        guard
            let validated = RecurrenceRule.validated(
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
            preconditionFailure("RecurrenceRule values are outside the ranges RFC 5545 permits.")
        }
        self = validated
    }

    /// Creates a rule without validation, for use after the values pass validation.
    init(
        uncheckedFrequency frequency: Frequency,
        interval: Int,
        count: Int?,
        until: Date?,
        bySeconds: [Int],
        byMinutes: [Int],
        byHours: [Int],
        byWeekdays: [WeekdayRule],
        byMonthDays: [Int],
        byYearDays: [Int],
        byWeeks: [Int],
        byMonths: [Int],
        bySetPositions: [Int],
        weekStart: Weekday
    ) {
        self.frequency = frequency
        self.interval = interval
        self.count = count
        self.until = until
        self.bySeconds = bySeconds
        self.byMinutes = byMinutes
        self.byHours = byHours
        self.byWeekdays = byWeekdays
        self.byMonthDays = byMonthDays
        self.byYearDays = byYearDays
        self.byWeeks = byWeeks
        self.byMonths = byMonths
        self.bySetPositions = bySetPositions
        self.weekStart = weekStart
    }

    /// Returns whether a value is in `-limit...-1` or `1...limit`.
    static func isValidSignedOrdinal(_ value: Int, limit: Int) -> Bool {
        (-limit ... -1).contains(value) || (1 ... limit).contains(value)
    }

    /// Returns a normalized rule if every value is in its RFC 5545 range,
    /// or `nil` otherwise.
    ///
    /// Normalization removes repeated values from each list
    /// and keeps the first appearance of each value.
    static func validated(
        frequency: Frequency,
        interval: Int,
        count: Int?,
        until: Date?,
        bySeconds: [Int],
        byMinutes: [Int],
        byHours: [Int],
        byWeekdays: [WeekdayRule],
        byMonthDays: [Int],
        byYearDays: [Int],
        byWeeks: [Int],
        byMonths: [Int],
        bySetPositions: [Int],
        weekStart: Weekday
    ) -> RecurrenceRule? {
        guard interval >= 1 else { return nil }
        if let count {
            guard count >= 1, until == nil else { return nil }
        }
        guard bySeconds.allSatisfy({ (0 ... 60).contains($0) }) else { return nil }
        guard byMinutes.allSatisfy({ (0 ... 59).contains($0) }) else { return nil }
        guard byHours.allSatisfy({ (0 ... 23).contains($0) }) else { return nil }
        guard byMonthDays.allSatisfy({ isValidSignedOrdinal($0, limit: 31) }) else { return nil }
        guard byYearDays.allSatisfy({ isValidSignedOrdinal($0, limit: 366) }) else { return nil }
        guard byWeeks.allSatisfy({ isValidSignedOrdinal($0, limit: 53) }) else { return nil }
        guard byMonths.allSatisfy({ (1 ... 12).contains($0) }) else { return nil }
        guard bySetPositions.allSatisfy({ isValidSignedOrdinal($0, limit: 366) }) else { return nil }
        for rule in byWeekdays {
            if let occurrence = rule.occurrence, !isValidSignedOrdinal(occurrence, limit: 53) {
                return nil
            }
        }
        if !bySetPositions.isEmpty {
            let hasCompanion =
                !bySeconds.isEmpty || !byMinutes.isEmpty || !byHours.isEmpty
                || !byWeekdays.isEmpty || !byMonthDays.isEmpty || !byYearDays.isEmpty
                || !byWeeks.isEmpty || !byMonths.isEmpty
            guard hasCompanion else { return nil }
        }

        return RecurrenceRule(
            uncheckedFrequency: frequency,
            interval: interval,
            count: count,
            until: until,
            bySeconds: deduplicated(bySeconds),
            byMinutes: deduplicated(byMinutes),
            byHours: deduplicated(byHours),
            byWeekdays: deduplicated(byWeekdays),
            byMonthDays: deduplicated(byMonthDays),
            byYearDays: deduplicated(byYearDays),
            byWeeks: deduplicated(byWeeks),
            byMonths: deduplicated(byMonths),
            bySetPositions: deduplicated(bySetPositions),
            weekStart: weekStart
        )
    }

    /// Returns the values without repeats, in the order of first appearance.
    static func deduplicated<Element: Hashable>(_ values: [Element]) -> [Element] {
        var seen: Set<Element> = []
        return values.filter { seen.insert($0).inserted }
    }
}

// MARK: - Codable

extension RecurrenceRule.WeekdayRule {
    enum CodingKeys: String, CodingKey {
        case weekday, occurrence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let weekday = try container.decode(RecurrenceRule.Weekday.self, forKey: .weekday)
        let occurrence = try container.decodeIfPresent(Int.self, forKey: .occurrence)
        if let occurrence, !RecurrenceRule.isValidSignedOrdinal(occurrence, limit: 53) {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Weekday occurrence must be in -53...-1 or 1...53."
                )
            )
        }
        self.weekday = weekday
        self.occurrence = occurrence
    }
}

extension RecurrenceRule: Codable {
    enum CodingKeys: String, CodingKey {
        case frequency, interval, count, until, bySeconds, byMinutes, byHours, byWeekdays
        case byMonthDays, byYearDays, byWeeks, byMonths, bySetPositions, weekStart
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let frequency = try container.decode(Frequency.self, forKey: .frequency)
        let interval = try container.decode(Int.self, forKey: .interval)
        let count = try container.decodeIfPresent(Int.self, forKey: .count)
        let until = try container.decodeIfPresent(Date.self, forKey: .until)
        let bySeconds = try container.decode([Int].self, forKey: .bySeconds)
        let byMinutes = try container.decode([Int].self, forKey: .byMinutes)
        let byHours = try container.decode([Int].self, forKey: .byHours)
        let byWeekdays = try container.decode([WeekdayRule].self, forKey: .byWeekdays)
        let byMonthDays = try container.decode([Int].self, forKey: .byMonthDays)
        let byYearDays = try container.decode([Int].self, forKey: .byYearDays)
        let byWeeks = try container.decode([Int].self, forKey: .byWeeks)
        let byMonths = try container.decode([Int].self, forKey: .byMonths)
        let bySetPositions = try container.decode([Int].self, forKey: .bySetPositions)
        let weekStart = try container.decode(Weekday.self, forKey: .weekStart)

        guard
            let validated = RecurrenceRule.validated(
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
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Recurrence rule values are outside the ranges RFC 5545 permits."
                )
            )
        }
        self = validated
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(interval, forKey: .interval)
        try container.encodeIfPresent(count, forKey: .count)
        try container.encodeIfPresent(until, forKey: .until)
        try container.encode(bySeconds, forKey: .bySeconds)
        try container.encode(byMinutes, forKey: .byMinutes)
        try container.encode(byHours, forKey: .byHours)
        try container.encode(byWeekdays, forKey: .byWeekdays)
        try container.encode(byMonthDays, forKey: .byMonthDays)
        try container.encode(byYearDays, forKey: .byYearDays)
        try container.encode(byWeeks, forKey: .byWeeks)
        try container.encode(byMonths, forKey: .byMonths)
        try container.encode(bySetPositions, forKey: .bySetPositions)
        try container.encode(weekStart, forKey: .weekStart)
    }
}

// MARK: - Formatting

extension RecurrenceRule {
    /// Formats the rule with a format style.
    ///
    /// - Parameter style: The format style to apply.
    /// - Returns: The formatted rule.
    public func formatted<S: Foundation.FormatStyle>(_ style: S) -> S.FormatOutput where S.FormatInput == RecurrenceRule {
        style.format(self)
    }

    /// Describes the rule in natural language for the current locale.
    ///
    /// - Returns: A description of the rule, such as "Every 3 hours".
    public func formatted() -> String {
        formatted(RecurrenceRule.FormatStyle())
    }

    /// Describes the rule in natural language for a locale.
    ///
    /// The locale's language selects the sentence templates:
    /// English, German, Spanish, or French,
    /// with English for any other language.
    ///
    /// - Parameters:
    ///   - locale: The locale for the language
    ///     and for the names, lists, numbers, and dates in the description.
    ///   - startDate: The start date of the first event, if you know it.
    ///     For a weekly, monthly, or yearly rule that selects no day,
    ///     the description names the day that the start date implies.
    /// - Returns: A description of the rule, such as "Monthly on the 15th".
    public func localizedDescription(in locale: Locale = .current, startingAt startDate: Date? = nil) -> String {
        formatted(RecurrenceRule.FormatStyle(locale: locale, startDate: startDate))
    }
}

// MARK: - CustomStringConvertible

extension RecurrenceRule: CustomStringConvertible {
    /// The rule in RFC 5545 form, such as `FREQ=WEEKLY;BYDAY=MO,WE`.
    ///
    /// The string leaves out rule parts that have their default values,
    /// and writes `UNTIL` as a UTC date and time.
    /// For a description in natural language, use ``formatted()``
    /// or ``localizedDescription(in:startingAt:)``.
    public var description: String {
        var parts: [String] = ["FREQ=\(frequency.rawValue)"]

        if interval > 1 {
            parts.append("INTERVAL=\(interval)")
        }
        if let count {
            parts.append("COUNT=\(count)")
        }
        if let until {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            parts.append("UNTIL=\(formatter.string(from: until))")
        }
        if !bySeconds.isEmpty {
            parts.append("BYSECOND=\(bySeconds.map(String.init).joined(separator: ","))")
        }
        if !byMinutes.isEmpty {
            parts.append("BYMINUTE=\(byMinutes.map(String.init).joined(separator: ","))")
        }
        if !byHours.isEmpty {
            parts.append("BYHOUR=\(byHours.map(String.init).joined(separator: ","))")
        }
        if !byWeekdays.isEmpty {
            parts.append("BYDAY=\(byWeekdays.map(\.stringRepresentation).joined(separator: ","))")
        }
        if !byMonthDays.isEmpty {
            parts.append("BYMONTHDAY=\(byMonthDays.map(String.init).joined(separator: ","))")
        }
        if !byYearDays.isEmpty {
            parts.append("BYYEARDAY=\(byYearDays.map(String.init).joined(separator: ","))")
        }
        if !byWeeks.isEmpty {
            parts.append("BYWEEKNO=\(byWeeks.map(String.init).joined(separator: ","))")
        }
        if !byMonths.isEmpty {
            parts.append("BYMONTH=\(byMonths.map(String.init).joined(separator: ","))")
        }
        if !bySetPositions.isEmpty {
            parts.append("BYSETPOS=\(bySetPositions.map(String.init).joined(separator: ","))")
        }
        if weekStart != .monday {
            parts.append("WKST=\(weekStart.rawValue)")
        }

        return parts.joined(separator: ";")
    }
}
