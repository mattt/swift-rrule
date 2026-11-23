import Foundation
import Testing

import RRULE

@Suite("Recurrences")
struct RecurrencesTests {
    /// Returns the UTC times of the first dates of a rule from a local start time.
    private func expand(
        _ rule: String,
        from start: String,
        in timeZone: String,
        limit: Int = 10,
        calendar: Calendar? = nil
    ) throws -> [String] {
        let zone = try #require(TimeZone(identifier: timeZone))
        var calendar = calendar ?? Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = zone
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let startDate = try #require(parser.date(from: start))
        return try expand(rule, from: startDate, limit: limit, calendar: calendar)
    }

    private func expand(_ rule: String, from start: Date, limit: Int = 10, calendar: Calendar) throws -> [String] {
        let formatter = ISO8601DateFormatter()
        return try RecurrenceRule.parse(rule).recurrences(of: start, calendar: calendar).prefix(limit).map(formatter.string(from:))
    }

    private func utc(_ string: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: string))
    }

    // MARK: Daylight saving time

    // In New York, clocks went forward from 2:00 AM EST to 3:00 AM EDT on March 9, 2025,
    // and back from 2:00 AM EDT to 1:00 AM EST on November 2, 2025.

    @Test("A local time that doesn't exist moves forward by the gap")
    func springForward() throws {
        let dates = try expand("FREQ=DAILY;COUNT=3", from: "2025-03-08T02:30:00", in: "America/New_York")
        // 2:30 AM EST, then 3:30 AM EDT in place of 2:30 AM, then 2:30 AM EDT.
        #expect(dates == ["2025-03-08T07:30:00Z", "2025-03-09T07:30:00Z", "2025-03-10T06:30:00Z"])
    }

    @Test("A local time that occurs twice refers to its first occurrence")
    func fallBack() throws {
        let dates = try expand("FREQ=DAILY;COUNT=3", from: "2025-11-01T01:30:00", in: "America/New_York")
        // 1:30 AM EDT, then the first 1:30 AM (EDT), then 1:30 AM EST.
        #expect(dates == ["2025-11-01T05:30:00Z", "2025-11-02T05:30:00Z", "2025-11-03T06:30:00Z"])
    }

    @Test("An hourly rule skips the duplicate at the gap and counts each date once")
    func hourlySpringForward() throws {
        let dates = try expand("FREQ=HOURLY;COUNT=4", from: "2025-03-09T00:00:00", in: "America/New_York")
        // 12:00 AM and 1:00 AM EST; 2:00 AM becomes 3:00 AM EDT, which then repeats once.
        #expect(dates == ["2025-03-09T05:00:00Z", "2025-03-09T06:00:00Z", "2025-03-09T07:00:00Z", "2025-03-09T08:00:00Z"])
    }

    @Test("An hourly rule gives the repeated hour once")
    func hourlyFallBack() throws {
        let dates = try expand("FREQ=HOURLY;COUNT=4", from: "2025-11-02T00:00:00", in: "America/New_York")
        // 12:00 AM and 1:00 AM EDT, then 2:00 AM and 3:00 AM EST.
        #expect(dates == ["2025-11-02T04:00:00Z", "2025-11-02T05:00:00Z", "2025-11-02T07:00:00Z", "2025-11-02T08:00:00Z"])
    }

    @Test("A start date in the second occurrence of a repeated time is the first date")
    func startInRepeatedTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        // 1:30 AM EST, the second 1:30 AM of November 2, 2025.
        let dates = try expand("FREQ=DAILY;COUNT=2", from: try utc("2025-11-02T06:30:00Z"), calendar: calendar)
        #expect(dates == ["2025-11-02T06:30:00Z", "2025-11-03T06:30:00Z"])
    }

    @Test("A time zone without daylight saving time keeps the same offset")
    func noDaylightSavingTime() throws {
        let daily = try expand("FREQ=DAILY;COUNT=4", from: "2025-03-08T02:30:00", in: "Asia/Kolkata")
        #expect(daily == ["2025-03-07T21:00:00Z", "2025-03-08T21:00:00Z", "2025-03-09T21:00:00Z", "2025-03-10T21:00:00Z"])
        let hourly = try expand("FREQ=HOURLY;INTERVAL=12;COUNT=3", from: "2025-11-02T00:00:00", in: "UTC")
        #expect(hourly == ["2025-11-02T00:00:00Z", "2025-11-02T12:00:00Z", "2025-11-03T00:00:00Z"])
    }

    // MARK: Start date, range, and end

    @Test("The sequence starts at the first match after a start date that the rule doesn't match")
    func unmatchedStart() throws {
        let dates = try expand("FREQ=MONTHLY;BYDAY=1SU;COUNT=2", from: "2026-01-15T09:00:00", in: "UTC")
        // COUNT counts from the first date that the rule matches.
        #expect(dates == ["2026-02-01T09:00:00Z", "2026-03-01T09:00:00Z"])
    }

    @Test("The start date keeps its fraction of a second")
    func fractionalStart() throws {
        let rule = try RecurrenceRule.parse("FREQ=SECONDLY;INTERVAL=10;COUNT=3")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let start = Date(timeIntervalSince1970: 1_800_000_000.5)
        let dates = Array(rule.recurrences(of: start, calendar: calendar))
        #expect(dates.map(\.timeIntervalSince1970) == [1_800_000_000.5, 1_800_000_010.5, 1_800_000_020.5])
    }

    @Test("A range limits the dates, and COUNT counts the dates before it")
    func range() throws {
        let rule = try RecurrenceRule.parse("FREQ=DAILY;COUNT=5")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let start = try utc("2026-01-01T09:00:00Z")
        let range = try utc("2026-01-03T00:00:00Z") ..< utc("2026-01-10T00:00:00Z")
        let formatter = ISO8601DateFormatter()
        let dates = rule.recurrences(of: start, in: range, calendar: calendar).map(formatter.string(from:))
        #expect(dates == ["2026-01-03T09:00:00Z", "2026-01-04T09:00:00Z", "2026-01-05T09:00:00Z"])

        let endless = try RecurrenceRule.parse("FREQ=WEEKLY;BYDAY=MO")
        let later = try utc("2030-01-01T00:00:00Z") ..< utc("2030-01-15T00:00:00Z")
        #expect(
            endless.recurrences(of: start, in: later, calendar: calendar).map(formatter.string(from:))
                == ["2030-01-07T09:00:00Z", "2030-01-14T09:00:00Z"]
        )
    }

    @Test("UNTIL includes a date equal to it")
    func inclusiveUntil() throws {
        let dates = try expand("FREQ=DAILY;UNTIL=20260103T090000Z", from: "2026-01-01T09:00:00", in: "UTC")
        #expect(dates == ["2026-01-01T09:00:00Z", "2026-01-02T09:00:00Z", "2026-01-03T09:00:00Z"])
    }

    @Test("The second 60 means the second 59")
    func leapSecond() throws {
        let dates = try expand("FREQ=MINUTELY;BYSECOND=60;COUNT=2", from: "2026-01-01T09:00:00", in: "UTC")
        #expect(dates == ["2026-01-01T09:00:59Z", "2026-01-01T09:01:59Z"])
    }

    // MARK: Laziness and bounds

    @Test("The sequence of an endless rule is lazy")
    func laziness() throws {
        let rule = try RecurrenceRule.parse("FREQ=SECONDLY")
        let start = try utc("2026-01-01T00:00:00Z")
        let sequence = rule.recurrences(of: start, calendar: Calendar(identifier: .gregorian))
        var iterator = sequence.makeIterator()
        #expect(iterator.next() == start)
        #expect(iterator.next() == start.addingTimeInterval(1))
        #expect(Array(sequence.prefix(3)).count == 3)
    }

    @Test(
        "A rule that never matches ends its sequence",
        arguments: [
            "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30",
            "FREQ=MONTHLY;BYMONTH=4,6,9,11;BYMONTHDAY=31",
            "FREQ=WEEKLY;INTERVAL=2;BYMONTH=2;BYMONTHDAY=30",
            "FREQ=DAILY;BYMONTH=2;BYMONTHDAY=-30",
            "FREQ=YEARLY;BYWEEKNO=53;BYMONTH=6",
            "FREQ=HOURLY;BYMONTH=2;BYMONTHDAY=30",
            "FREQ=HOURLY;INTERVAL=2;BYHOUR=1",
            "FREQ=MINUTELY;INTERVAL=10;BYMINUTE=5",
            "FREQ=SECONDLY;INTERVAL=2;BYSECOND=1",
            "FREQ=HOURLY;INTERVAL=168;BYDAY=TU",
        ]
    )
    func neverMatches(_ string: String) throws {
        let rule = try RecurrenceRule.parse(string)
        // Thursday, January 1, 2026, at midnight
        let start = try utc("2026-01-01T00:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(Array(rule.recurrences(of: start, calendar: calendar)).isEmpty)
    }

    @Test("A rule with a long gap between dates doesn't end early")
    func longGap() throws {
        // February 29 every 500 years falls only in years divisible by 2,000.
        let dates = try expand("FREQ=YEARLY;INTERVAL=500;BYMONTH=2;BYMONTHDAY=29", from: "2000-02-29T00:00:00", in: "UTC", limit: 2)
        #expect(dates == ["2000-02-29T00:00:00Z", "4000-02-29T00:00:00Z"])
    }

    // MARK: Calendar

    @Test("Only the calendar's time zone affects the dates")
    func calendarIndependence() throws {
        let rules = ["FREQ=YEARLY;BYWEEKNO=1;BYDAY=MO", "FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,SU", "FREQ=MONTHLY;BYMONTHDAY=30"]
        var other = Calendar(identifier: .hebrew)
        other.firstWeekday = 1
        other.minimumDaysInFirstWeek = 1
        for rule in rules {
            let gregorian = try expand(rule, from: "2026-01-01T09:00:00", in: "Europe/London")
            #expect(try expand(rule, from: "2026-01-01T09:00:00", in: "Europe/London", calendar: other) == gregorian)
        }
    }
}
