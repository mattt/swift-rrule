import Foundation
import Testing

@testable import RRULE

/// A rule, a start date, and the dates that the rule's expansion must produce.
struct ExpansionExample: CustomTestStringConvertible, Sendable {
    let rule: String
    let start: String
    let timeZone: String
    let expected: [String]
    let knownIssue: String?

    var testDescription: String { rule }

    /// Creates an example.
    ///
    /// - Parameters:
    ///   - rule: The rule in RFC 5545 form.
    ///   - start: The start date and time, as `yyyy-MM-dd'T'HH:mm`.
    ///   - timeZone: The identifier of the time zone of the start date.
    ///   - expected: The first dates of the expansion, as `yyyy-MM-dd`.
    ///     For a rule without an end,
    ///     the test compares this many dates.
    ///   - knownIssue: A description of the way Foundation's expansion differs,
    ///     or `nil` if Foundation produces the expected dates.
    init(
        _ rule: String,
        from start: String,
        in timeZone: String = "America/New_York",
        expected: [String],
        knownIssue: String? = nil
    ) {
        self.rule = rule
        self.start = start
        self.timeZone = timeZone
        self.expected = expected
        self.knownIssue = knownIssue
    }
}

@Suite("Foundation Expansion")
struct ExpansionTests {
    /// The examples in RFC 5545, section 3.8.5.3,
    /// with the dates that the RFC lists for them.
    ///
    /// Each example in the RFC starts at 9:00 AM in New York.
    static let rfcExamples: [ExpansionExample] = [
        .init(
            "FREQ=DAILY;COUNT=10",
            from: "1997-09-02T09:00",
            expected: [
                "1997-09-02", "1997-09-03", "1997-09-04", "1997-09-05", "1997-09-06",
                "1997-09-07", "1997-09-08", "1997-09-09", "1997-09-10", "1997-09-11",
            ]
        ),
        .init(
            "FREQ=WEEKLY;INTERVAL=2;UNTIL=19971224T000000Z;WKST=SU;BYDAY=MO,WE,FR",
            from: "1997-09-01T09:00",
            expected: [
                "1997-09-01", "1997-09-03", "1997-09-05", "1997-09-15", "1997-09-17", "1997-09-19", "1997-09-29",
                "1997-10-01", "1997-10-03", "1997-10-13", "1997-10-15", "1997-10-17",
                "1997-10-27", "1997-10-29", "1997-10-31",
                "1997-11-10", "1997-11-12", "1997-11-14", "1997-11-24", "1997-11-26", "1997-11-28",
                "1997-12-08", "1997-12-10", "1997-12-12", "1997-12-22",
            ]
        ),
        // Monthly on the first Friday for 10 occurrences.
        .init(
            "FREQ=MONTHLY;COUNT=10;BYDAY=1FR",
            from: "1997-09-05T09:00",
            expected: [
                "1997-09-05", "1997-10-03", "1997-11-07", "1997-12-05", "1998-01-02",
                "1998-02-06", "1998-03-06", "1998-04-03", "1998-05-01", "1998-06-05",
            ]
        ),
        .init(
            "FREQ=MONTHLY;UNTIL=19971224T000000Z;BYDAY=1FR",
            from: "1997-09-05T09:00",
            expected: ["1997-09-05", "1997-10-03", "1997-11-07", "1997-12-05"]
        ),
        // Every other month on the first and last Sunday of the month for 10 occurrences.
        .init(
            "FREQ=MONTHLY;INTERVAL=2;COUNT=10;BYDAY=1SU,-1SU",
            from: "1997-09-07T09:00",
            expected: [
                "1997-09-07", "1997-09-28", "1997-11-02", "1997-11-30", "1998-01-04",
                "1998-01-25", "1998-03-01", "1998-03-29", "1998-05-03", "1998-05-31",
            ]
        ),
        // Monthly on the second-to-last Monday of the month for 6 months.
        .init(
            "FREQ=MONTHLY;COUNT=6;BYDAY=-2MO",
            from: "1997-09-22T09:00",
            expected: ["1997-09-22", "1997-10-20", "1997-11-17", "1997-12-22", "1998-01-19", "1998-02-16"]
        ),
        .init(
            "FREQ=MONTHLY;BYMONTHDAY=-3",
            from: "1997-09-28T09:00",
            expected: ["1997-09-28", "1997-10-29", "1997-11-28", "1997-12-29", "1998-01-29", "1998-02-26"]
        ),
        // Every Tuesday, every other month.
        .init(
            "FREQ=MONTHLY;INTERVAL=2;BYDAY=TU",
            from: "1997-09-02T09:00",
            expected: [
                "1997-09-02", "1997-09-09", "1997-09-16", "1997-09-23", "1997-09-30",
                "1997-11-04", "1997-11-11", "1997-11-18", "1997-11-25",
            ],
            knownIssue: "Foundation gives only the first Tuesday of each month: 1997-09-02, 1997-11-04, 1998-01-06."
        ),
        .init(
            "FREQ=YEARLY;INTERVAL=3;COUNT=10;BYYEARDAY=1,100,200",
            from: "1997-01-01T09:00",
            expected: [
                "1997-01-01", "1997-04-10", "1997-07-19", "2000-01-01", "2000-04-09",
                "2000-07-18", "2003-01-01", "2003-04-10", "2003-07-19", "2006-01-01",
            ]
        ),
        // Monday of week number 20, where the week starts on Monday.
        .init(
            "FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO",
            from: "1997-05-12T09:00",
            expected: ["1997-05-12", "1998-05-11", "1999-05-17"],
            knownIssue: "Foundation keeps the start date's day of the month, and gives 1997-05-12, 2003-05-12, and 2014-05-12."
        ),
        .init(
            "FREQ=YEARLY;BYMONTH=3;BYDAY=TH",
            from: "1997-03-13T09:00",
            expected: [
                "1997-03-13", "1997-03-20", "1997-03-27",
                "1998-03-05", "1998-03-12", "1998-03-19", "1998-03-26",
            ],
            knownIssue: "Foundation gives only the first Thursday of each March, from 1998: 1998-03-05, 1999-03-04, 2000-03-02."
        ),
        // Every Friday the 13th.
        // The RFC excludes the start date with `EXDATE`,
        // because the start date doesn't match the rule.
        .init(
            "FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13",
            from: "1997-09-02T09:00",
            expected: ["1998-02-13", "1998-03-13", "1998-11-13", "1999-08-13", "2000-10-13"]
        ),
        // The first Saturday that follows the first Sunday of the month.
        .init(
            "FREQ=MONTHLY;BYDAY=SA;BYMONTHDAY=7,8,9,10,11,12,13",
            from: "1997-09-13T09:00",
            expected: [
                "1997-09-13", "1997-10-11", "1997-11-08", "1997-12-13", "1998-01-10",
                "1998-02-07", "1998-03-07", "1998-04-11", "1998-05-09", "1998-06-13",
            ]
        ),
        // Every 4 years, the first Tuesday after a Monday in November
        // (U.S. Presidential Election day).
        .init(
            "FREQ=YEARLY;INTERVAL=4;BYMONTH=11;BYDAY=TU;BYMONTHDAY=2,3,4,5,6,7,8",
            from: "1996-11-05T09:00",
            expected: ["1996-11-05", "2000-11-07", "2004-11-02"]
        ),
        // The third instance into the month of one of Tuesday, Wednesday, or Thursday.
        .init(
            "FREQ=MONTHLY;COUNT=3;BYDAY=TU,WE,TH;BYSETPOS=3",
            from: "1997-09-04T09:00",
            expected: ["1997-09-04", "1997-10-07", "1997-11-06"],
            knownIssue: "Foundation selects from the first week of each month, and gives 1997-10-07, 1997-11-06, and 1997-12-04."
        ),
        // The second-to-last weekday of the month.
        .init(
            "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-2",
            from: "1997-09-29T09:00",
            expected: ["1997-09-29", "1997-10-30", "1997-11-27", "1997-12-30", "1998-01-29", "1998-02-26", "1998-03-30"],
            knownIssue: "Foundation selects from the first week of each month, and gives 1997-10-06, 1997-11-06, and 1997-12-04 first."
        ),
        // The days that the rule generates depend on the week start.
        .init(
            "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=MO",
            from: "1997-08-05T09:00",
            expected: ["1997-08-05", "1997-08-10", "1997-08-19", "1997-08-24"]
        ),
        .init(
            "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=SU",
            from: "1997-08-05T09:00",
            expected: ["1997-08-05", "1997-08-17", "1997-08-19", "1997-08-31"]
        ),
    ]

    /// Examples outside the RFC, with dates that a calendar confirms.
    static let otherExamples: [ExpansionExample] = [
        // Thanksgiving in the United States.
        .init(
            "FREQ=YEARLY;BYMONTH=11;BYDAY=4TH",
            from: "2026-01-01T00:00",
            in: "America/Los_Angeles",
            expected: ["2026-11-26", "2027-11-25", "2028-11-23", "2029-11-22", "2030-11-28"]
        ),
        .init(
            "FREQ=MONTHLY;BYDAY=1SU",
            from: "2026-11-01T00:00",
            in: "America/Los_Angeles",
            expected: ["2026-11-01", "2026-12-06", "2027-01-03", "2027-02-07"]
        ),
        .init(
            "FREQ=YEARLY;INTERVAL=4;BYMONTH=11;BYDAY=TU;BYMONTHDAY=2,3,4,5,6,7,8",
            from: "2024-11-05T00:00",
            in: "America/Los_Angeles",
            expected: ["2024-11-05", "2028-11-07", "2032-11-02"]
        ),
        // The last weekday of the month.
        .init(
            "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1",
            from: "2026-01-01T00:00",
            in: "America/Los_Angeles",
            expected: ["2026-01-30", "2026-02-27", "2026-03-31", "2026-04-30", "2026-05-29", "2026-06-30"],
            knownIssue: "Foundation selects from the first week of each month, and gives 2026-01-07, 2026-02-06, and 2026-03-06 first."
        ),
    ]

    /// The RFC's example of every 20th Monday of the year.
    static let twentiethMonday = ExpansionExample(
        "FREQ=YEARLY;BYDAY=20MO",
        from: "1997-05-19T09:00",
        expected: ["1997-05-19", "1998-05-18", "1999-05-17"]
    )

    @Test("Expansion matches RFC 5545", arguments: rfcExamples)
    func rfcExpansion(_ example: ExpansionExample) throws {
        try expectExpansion(example)
    }

    @Test("Expansion matches the calendar", arguments: otherExamples)
    func otherExpansion(_ example: ExpansionExample) throws {
        try expectExpansion(example)
    }

    #if compiler(>=6.2) && os(macOS)
        /// Foundation searches for about a minute for an ordinal weekday of the year,
        /// and then traps, so the expansion runs in a separate process.
        /// The test is off by default because of the time it takes.
        @Test(
            "Expansion of an ordinal weekday of the year matches RFC 5545",
            .disabled("Foundation searches for about a minute, then traps with CalendarEnumerationError.notAdvancing.")
        )
        func ordinalWeekdayOfYear() async {
            guard #available(macOS 15, *) else { return }
            await withKnownIssue("Foundation traps with CalendarEnumerationError.notAdvancing.") {
                await #expect(processExitsWith: .success) {
                    let example = ExpansionTests.twentiethMonday
                    precondition(try! ExpansionTests.expansion(of: example) == ExpansionTests.expectedExpansion(of: example))
                }
            }
        }
    #endif

    private func expectExpansion(_ example: ExpansionExample) throws {
        guard #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) else { return }
        let dates = try Self.expansion(of: example)
        if let knownIssue = example.knownIssue {
            withKnownIssue(Comment(rawValue: knownIssue)) {
                #expect(dates == Self.expectedExpansion(of: example))
            }
        } else {
            #expect(dates == Self.expectedExpansion(of: example))
        }
    }

    /// The expected dates, with the time of day of the start date.
    static func expectedExpansion(of example: ExpansionExample) -> [String] {
        let time = example.start.split(separator: "T").last ?? ""
        return example.expected.map { "\($0)T\(time)" }
    }

    /// Converts the example's rule, expands it from the example's start date,
    /// and returns the dates as `yyyy-MM-dd'T'HH:mm` in the example's time zone.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    static func expansion(of example: ExpansionExample) throws -> [String] {
        let timeZone = try #require(TimeZone(identifier: example.timeZone))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let rule = try #require(RecurrenceRule(parsing: example.rule))
        let foundationRule = try #require(Calendar.RecurrenceRule(rule, calendar: calendar))
        let start = try #require(formatter.date(from: example.start))

        // Take one more date than expected, to detect extra dates from a rule with an end.
        let limit = rule.count == nil && rule.until == nil ? example.expected.count : example.expected.count + 1
        return foundationRule.recurrences(of: start).prefix(limit).map(formatter.string(from:))
    }
}

@Suite("Foundation Conversion")
struct FoundationConversionTests {
    static let representableRules = [
        "FREQ=MINUTELY;INTERVAL=15;COUNT=6",
        "FREQ=HOURLY;INTERVAL=3;UNTIL=19970902T170000Z",
        "FREQ=DAILY;BYHOUR=9,10;BYMINUTE=0,20,40;BYSECOND=0,30",
        "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;WKST=SU",
        "FREQ=MONTHLY;BYDAY=1SU,-1SU",
        "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1",
        "FREQ=MONTHLY;BYMONTHDAY=1,-1",
        "FREQ=YEARLY;BYYEARDAY=1,100,-1",
        "FREQ=YEARLY;BYWEEKNO=20,-1;BYDAY=MO;WKST=TH",
        "FREQ=YEARLY;INTERVAL=4;BYMONTH=11;BYDAY=TU;BYMONTHDAY=2,3,4,5,6,7,8",
        "FREQ=YEARLY;BYMONTH=11;BYDAY=4TH",
    ]

    @Test("A converted rule converts back to the same rule", arguments: representableRules)
    func roundTrip(_ string: String) throws {
        guard #available(macOS 15.2, iOS 18.2, tvOS 18.2, watchOS 11.2, visionOS 2.2, *) else { return }
        let rule = try #require(RecurrenceRule(parsing: string))
        let calendar = Calendar(identifier: .gregorian)
        let foundationRule = try #require(Calendar.RecurrenceRule(rule, calendar: calendar))
        #expect(RecurrenceRule(foundationRule) == rule)
    }

    @Test("Conversion carries every rule part")
    func ruleParts() throws {
        guard #available(macOS 15.2, iOS 18.2, tvOS 18.2, watchOS 11.2, visionOS 2.2, *) else { return }
        let rule = try #require(RecurrenceRule(parsing: "FREQ=MONTHLY;INTERVAL=2;COUNT=5;BYDAY=1SU,-1MO,FR;BYSETPOS=1,-1"))
        let foundationRule = try #require(Calendar.RecurrenceRule(rule, calendar: Calendar(identifier: .gregorian)))
        #expect(foundationRule.frequency == .monthly)
        #expect(foundationRule.interval == 2)
        #expect(foundationRule.end.occurrences == 5)
        #expect(foundationRule.weekdays == [.nth(1, .sunday), .nth(-1, .monday), .every(.friday)])
        #expect(foundationRule.setPositions == [1, -1])
        #expect(foundationRule.matchingPolicy == .nextTimePreservingSmallerComponents)
        #expect(foundationRule.repeatedTimePolicy == .first)
    }

    @Test("Conversion sets the week and keeps the time zone and locale")
    func calendarProperties() throws {
        guard #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1

        let rule = try #require(RecurrenceRule(parsing: "FREQ=WEEKLY"))
        let converted = try #require(Calendar.RecurrenceRule(rule, calendar: calendar)).calendar
        #expect(converted.firstWeekday == 2)
        #expect(converted.minimumDaysInFirstWeek == 4)
        #expect(converted.timeZone == calendar.timeZone)
        #expect(converted.locale == calendar.locale)

        let sunday = try #require(RecurrenceRule(parsing: "FREQ=WEEKLY;WKST=SU"))
        #expect(Calendar.RecurrenceRule(sunday, calendar: calendar)?.calendar.firstWeekday == 1)
    }

    @Test("Conversion fails for rules that Foundation can't represent")
    func unrepresentableRules() throws {
        guard #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) else { return }
        let gregorian = Calendar(identifier: .gregorian)
        let secondly = try #require(RecurrenceRule(parsing: "FREQ=SECONDLY"))
        #expect(Calendar.RecurrenceRule(secondly, calendar: gregorian) == nil)

        let leapSecond = try #require(RecurrenceRule(parsing: "FREQ=MINUTELY;BYSECOND=60"))
        #expect(Calendar.RecurrenceRule(leapSecond, calendar: gregorian) == nil)

        let monthly = try #require(RecurrenceRule(parsing: "FREQ=MONTHLY;BYMONTHDAY=1"))
        #expect(Calendar.RecurrenceRule(monthly, calendar: Calendar(identifier: .hebrew)) == nil)
        #expect(Calendar.RecurrenceRule(monthly, calendar: Calendar(identifier: .buddhist)) != nil)
    }
}
