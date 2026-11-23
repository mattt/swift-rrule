import Foundation
import Testing

import RRULE

/// An example from RFC 5545, section 3.8.5.3,
/// with its start date and the local times that the RFC lists for it.
struct RFCExample: CustomTestStringConvertible, Sendable {
    let rule: String
    let start: String
    let expected: [String]

    var testDescription: String { rule }

    /// Creates an example.
    ///
    /// - Parameters:
    ///   - rule: The rule, as the RFC gives it.
    ///   - start: The local start date and time in New York (`DTSTART`), as `yyyy-MM-dd'T'HH:mm`.
    ///   - expected: The local dates and times that the RFC lists, as `yyyy-MM-dd'T'HH:mm`.
    ///     For a rule without `COUNT` or `UNTIL`, the RFC lists the first dates,
    ///     and the test compares that many.
    init(_ rule: String, from start: String, _ expected: [String]) {
        self.rule = rule
        self.start = start
        self.expected = expected
    }
}

/// Returns the dates at 9:00 AM, the time of every example's start date but the last.
private func at9(_ dates: String...) -> [String] {
    dates.map { "\($0)T09:00" }
}

/// Returns the dates from one date through another, every `step` days, at 9:00 AM.
private func days(from first: String, through last: String, every step: Int = 1) -> [String] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    var date = formatter.date(from: first)!
    let end = formatter.date(from: last)!
    var result: [String] = []
    while date <= end {
        result.append("\(formatter.string(from: date))T09:00")
        date = calendar.date(byAdding: .day, value: step, to: date)!
    }
    return result
}

/// Returns the times on a date.
private func on(_ date: String, _ times: String...) -> [String] {
    times.map { "\(date)T\($0)" }
}

@Suite("RFC 5545 Examples")
struct RFCExampleTests {
    /// Every example in RFC 5545, section 3.8.5.3, in the order of the RFC.
    ///
    /// Every example starts in the `America/New_York` time zone.
    static let examples: [RFCExample] = [
        // Daily for 10 occurrences
        .init("FREQ=DAILY;COUNT=10", from: "1997-09-02T09:00", days(from: "1997-09-02", through: "1997-09-11")),
        // Daily until December 24, 1997
        .init("FREQ=DAILY;UNTIL=19971224T000000Z", from: "1997-09-02T09:00", days(from: "1997-09-02", through: "1997-12-23")),
        // Every other day - forever
        .init("FREQ=DAILY;INTERVAL=2", from: "1997-09-02T09:00", days(from: "1997-09-02", through: "1997-12-03", every: 2)),
        // Every 10 days, 5 occurrences
        .init(
            "FREQ=DAILY;INTERVAL=10;COUNT=5",
            from: "1997-09-02T09:00",
            at9("1997-09-02", "1997-09-12", "1997-09-22", "1997-10-02", "1997-10-12")
        ),
        // Every day in January, for 3 years
        .init(
            "FREQ=YEARLY;UNTIL=20000131T140000Z;BYMONTH=1;BYDAY=SU,MO,TU,WE,TH,FR,SA",
            from: "1998-01-01T09:00",
            days(from: "1998-01-01", through: "1998-01-31") + days(from: "1999-01-01", through: "1999-01-31")
                + days(from: "2000-01-01", through: "2000-01-31")
        ),
        .init(
            "FREQ=DAILY;UNTIL=20000131T140000Z;BYMONTH=1",
            from: "1998-01-01T09:00",
            days(from: "1998-01-01", through: "1998-01-31") + days(from: "1999-01-01", through: "1999-01-31")
                + days(from: "2000-01-01", through: "2000-01-31")
        ),
        // Weekly for 10 occurrences
        .init(
            "FREQ=WEEKLY;COUNT=10",
            from: "1997-09-02T09:00",
            at9(
                "1997-09-02",
                "1997-09-09",
                "1997-09-16",
                "1997-09-23",
                "1997-09-30",
                "1997-10-07",
                "1997-10-14",
                "1997-10-21",
                "1997-10-28",
                "1997-11-04"
            )
        ),
        // Weekly until December 24, 1997
        .init(
            "FREQ=WEEKLY;UNTIL=19971224T000000Z",
            from: "1997-09-02T09:00",
            days(from: "1997-09-02", through: "1997-12-23", every: 7)
        ),
        // Every other week - forever
        .init(
            "FREQ=WEEKLY;INTERVAL=2;WKST=SU",
            from: "1997-09-02T09:00",
            at9(
                "1997-09-02",
                "1997-09-16",
                "1997-09-30",
                "1997-10-14",
                "1997-10-28",
                "1997-11-11",
                "1997-11-25",
                "1997-12-09",
                "1997-12-23",
                "1998-01-06",
                "1998-01-20",
                "1998-02-03",
                "1998-02-17"
            )
        ),
        // Weekly on Tuesday and Thursday for five weeks
        .init(
            "FREQ=WEEKLY;UNTIL=19971007T000000Z;WKST=SU;BYDAY=TU,TH",
            from: "1997-09-02T09:00",
            at9(
                "1997-09-02",
                "1997-09-04",
                "1997-09-09",
                "1997-09-11",
                "1997-09-16",
                "1997-09-18",
                "1997-09-23",
                "1997-09-25",
                "1997-09-30",
                "1997-10-02"
            )
        ),
        .init(
            "FREQ=WEEKLY;COUNT=10;WKST=SU;BYDAY=TU,TH",
            from: "1997-09-02T09:00",
            at9(
                "1997-09-02",
                "1997-09-04",
                "1997-09-09",
                "1997-09-11",
                "1997-09-16",
                "1997-09-18",
                "1997-09-23",
                "1997-09-25",
                "1997-09-30",
                "1997-10-02"
            )
        ),
        // Every other week on Monday, Wednesday, and Friday until December 24, 1997,
        // starting on Monday, September 1, 1997
        .init(
            "FREQ=WEEKLY;INTERVAL=2;UNTIL=19971224T000000Z;WKST=SU;BYDAY=MO,WE,FR",
            from: "1997-09-01T09:00",
            at9(
                "1997-09-01",
                "1997-09-03",
                "1997-09-05",
                "1997-09-15",
                "1997-09-17",
                "1997-09-19",
                "1997-09-29",
                "1997-10-01",
                "1997-10-03",
                "1997-10-13",
                "1997-10-15",
                "1997-10-17",
                "1997-10-27",
                "1997-10-29",
                "1997-10-31",
                "1997-11-10",
                "1997-11-12",
                "1997-11-14",
                "1997-11-24",
                "1997-11-26",
                "1997-11-28",
                "1997-12-08",
                "1997-12-10",
                "1997-12-12",
                "1997-12-22"
            )
        ),
        // Every other week on Tuesday and Thursday, for 8 occurrences
        .init(
            "FREQ=WEEKLY;INTERVAL=2;COUNT=8;WKST=SU;BYDAY=TU,TH",
            from: "1997-09-02T09:00",
            at9("1997-09-02", "1997-09-04", "1997-09-16", "1997-09-18", "1997-09-30", "1997-10-02", "1997-10-14", "1997-10-16")
        ),
        // Monthly on the first Friday for 10 occurrences
        .init(
            "FREQ=MONTHLY;COUNT=10;BYDAY=1FR",
            from: "1997-09-05T09:00",
            at9(
                "1997-09-05",
                "1997-10-03",
                "1997-11-07",
                "1997-12-05",
                "1998-01-02",
                "1998-02-06",
                "1998-03-06",
                "1998-04-03",
                "1998-05-01",
                "1998-06-05"
            )
        ),
        // Monthly on the first Friday until December 24, 1997
        .init(
            "FREQ=MONTHLY;UNTIL=19971224T000000Z;BYDAY=1FR",
            from: "1997-09-05T09:00",
            at9("1997-09-05", "1997-10-03", "1997-11-07", "1997-12-05")
        ),
        // Every other month on the first and last Sunday of the month for 10 occurrences
        .init(
            "FREQ=MONTHLY;INTERVAL=2;COUNT=10;BYDAY=1SU,-1SU",
            from: "1997-09-07T09:00",
            at9(
                "1997-09-07",
                "1997-09-28",
                "1997-11-02",
                "1997-11-30",
                "1998-01-04",
                "1998-01-25",
                "1998-03-01",
                "1998-03-29",
                "1998-05-03",
                "1998-05-31"
            )
        ),
        // Monthly on the second-to-last Monday of the month for 6 months
        .init(
            "FREQ=MONTHLY;COUNT=6;BYDAY=-2MO",
            from: "1997-09-22T09:00",
            at9("1997-09-22", "1997-10-20", "1997-11-17", "1997-12-22", "1998-01-19", "1998-02-16")
        ),
        // Monthly on the third-to-the-last day of the month, forever
        .init(
            "FREQ=MONTHLY;BYMONTHDAY=-3",
            from: "1997-09-28T09:00",
            at9("1997-09-28", "1997-10-29", "1997-11-28", "1997-12-29", "1998-01-29", "1998-02-26")
        ),
        // Monthly on the 2nd and 15th of the month for 10 occurrences
        .init(
            "FREQ=MONTHLY;COUNT=10;BYMONTHDAY=2,15",
            from: "1997-09-02T09:00",
            at9(
                "1997-09-02",
                "1997-09-15",
                "1997-10-02",
                "1997-10-15",
                "1997-11-02",
                "1997-11-15",
                "1997-12-02",
                "1997-12-15",
                "1998-01-02",
                "1998-01-15"
            )
        ),
        // Monthly on the first and last day of the month for 10 occurrences
        .init(
            "FREQ=MONTHLY;COUNT=10;BYMONTHDAY=1,-1",
            from: "1997-09-30T09:00",
            at9(
                "1997-09-30",
                "1997-10-01",
                "1997-10-31",
                "1997-11-01",
                "1997-11-30",
                "1997-12-01",
                "1997-12-31",
                "1998-01-01",
                "1998-01-31",
                "1998-02-01"
            )
        ),
        // Every 18 months on the 10th thru 15th of the month for 10 occurrences
        .init(
            "FREQ=MONTHLY;INTERVAL=18;COUNT=10;BYMONTHDAY=10,11,12,13,14,15",
            from: "1997-09-10T09:00",
            days(from: "1997-09-10", through: "1997-09-15") + days(from: "1999-03-10", through: "1999-03-13")
        ),
        // Every Tuesday, every other month
        .init(
            "FREQ=MONTHLY;INTERVAL=2;BYDAY=TU",
            from: "1997-09-02T09:00",
            at9(
                "1997-09-02",
                "1997-09-09",
                "1997-09-16",
                "1997-09-23",
                "1997-09-30",
                "1997-11-04",
                "1997-11-11",
                "1997-11-18",
                "1997-11-25",
                "1998-01-06",
                "1998-01-13",
                "1998-01-20",
                "1998-01-27",
                "1998-03-03",
                "1998-03-10",
                "1998-03-17",
                "1998-03-24",
                "1998-03-31"
            )
        ),
        // Yearly in June and July for 10 occurrences
        .init(
            "FREQ=YEARLY;COUNT=10;BYMONTH=6,7",
            from: "1997-06-10T09:00",
            at9(
                "1997-06-10",
                "1997-07-10",
                "1998-06-10",
                "1998-07-10",
                "1999-06-10",
                "1999-07-10",
                "2000-06-10",
                "2000-07-10",
                "2001-06-10",
                "2001-07-10"
            )
        ),
        // Every other year on January, February, and March for 10 occurrences
        .init(
            "FREQ=YEARLY;INTERVAL=2;COUNT=10;BYMONTH=1,2,3",
            from: "1997-03-10T09:00",
            at9(
                "1997-03-10",
                "1999-01-10",
                "1999-02-10",
                "1999-03-10",
                "2001-01-10",
                "2001-02-10",
                "2001-03-10",
                "2003-01-10",
                "2003-02-10",
                "2003-03-10"
            )
        ),
        // Every third year on the 1st, 100th, and 200th day for 10 occurrences
        .init(
            "FREQ=YEARLY;INTERVAL=3;COUNT=10;BYYEARDAY=1,100,200",
            from: "1997-01-01T09:00",
            at9(
                "1997-01-01",
                "1997-04-10",
                "1997-07-19",
                "2000-01-01",
                "2000-04-09",
                "2000-07-18",
                "2003-01-01",
                "2003-04-10",
                "2003-07-19",
                "2006-01-01"
            )
        ),
        // Every 20th Monday of the year, forever
        .init("FREQ=YEARLY;BYDAY=20MO", from: "1997-05-19T09:00", at9("1997-05-19", "1998-05-18", "1999-05-17")),
        // Monday of week number 20 (where the default start of the week is Monday), forever
        .init("FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO", from: "1997-05-12T09:00", at9("1997-05-12", "1998-05-11", "1999-05-17")),
        // Every Thursday in March, forever
        .init(
            "FREQ=YEARLY;BYMONTH=3;BYDAY=TH",
            from: "1997-03-13T09:00",
            at9(
                "1997-03-13",
                "1997-03-20",
                "1997-03-27",
                "1998-03-05",
                "1998-03-12",
                "1998-03-19",
                "1998-03-26",
                "1999-03-04",
                "1999-03-11",
                "1999-03-18",
                "1999-03-25"
            )
        ),
        // Every Thursday, but only during June, July, and August, forever
        .init(
            "FREQ=YEARLY;BYDAY=TH;BYMONTH=6,7,8",
            from: "1997-06-05T09:00",
            at9(
                "1997-06-05",
                "1997-06-12",
                "1997-06-19",
                "1997-06-26",
                "1997-07-03",
                "1997-07-10",
                "1997-07-17",
                "1997-07-24",
                "1997-07-31",
                "1997-08-07",
                "1997-08-14",
                "1997-08-21",
                "1997-08-28",
                "1998-06-04",
                "1998-06-11",
                "1998-06-18",
                "1998-06-25",
                "1998-07-02",
                "1998-07-09",
                "1998-07-16",
                "1998-07-23",
                "1998-07-30",
                "1998-08-06",
                "1998-08-13",
                "1998-08-20",
                "1998-08-27",
                "1999-06-03",
                "1999-06-10",
                "1999-06-17",
                "1999-06-24",
                "1999-07-01",
                "1999-07-08",
                "1999-07-15",
                "1999-07-22",
                "1999-07-29",
                "1999-08-05",
                "1999-08-12",
                "1999-08-19",
                "1999-08-26"
            )
        ),
        // Every Friday the 13th, forever.
        // The RFC removes the start date with EXDATE.
        // The rule doesn't match the start date, so the sequence doesn't contain it.
        .init(
            "FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13",
            from: "1997-09-02T09:00",
            at9("1998-02-13", "1998-03-13", "1998-11-13", "1999-08-13", "2000-10-13")
        ),
        // The first Saturday that follows the first Sunday of the month, forever
        .init(
            "FREQ=MONTHLY;BYDAY=SA;BYMONTHDAY=7,8,9,10,11,12,13",
            from: "1997-09-13T09:00",
            at9(
                "1997-09-13",
                "1997-10-11",
                "1997-11-08",
                "1997-12-13",
                "1998-01-10",
                "1998-02-07",
                "1998-03-07",
                "1998-04-11",
                "1998-05-09",
                "1998-06-13"
            )
        ),
        // Every 4 years, the first Tuesday after a Monday in November, forever
        // (U.S. Presidential Election day)
        .init(
            "FREQ=YEARLY;INTERVAL=4;BYMONTH=11;BYDAY=TU;BYMONTHDAY=2,3,4,5,6,7,8",
            from: "1996-11-05T09:00",
            at9("1996-11-05", "2000-11-07", "2004-11-02")
        ),
        // The third instance into the month of one of Tuesday, Wednesday, or Thursday,
        // for the next 3 months
        .init(
            "FREQ=MONTHLY;COUNT=3;BYDAY=TU,WE,TH;BYSETPOS=3",
            from: "1997-09-04T09:00",
            at9("1997-09-04", "1997-10-07", "1997-11-06")
        ),
        // The second-to-last weekday of the month
        .init(
            "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-2",
            from: "1997-09-29T09:00",
            at9("1997-09-29", "1997-10-30", "1997-11-27", "1997-12-30", "1998-01-29", "1998-02-26", "1998-03-30")
        ),
        // Every 3 hours from 9:00 AM to 5:00 PM on a specific day,
        // with the UNTIL value of verified erratum 3883.
        .init(
            "FREQ=HOURLY;INTERVAL=3;UNTIL=19970902T210000Z",
            from: "1997-09-02T09:00",
            on("1997-09-02", "09:00", "12:00", "15:00")
        ),
        // Every 15 minutes for 6 occurrences
        .init(
            "FREQ=MINUTELY;INTERVAL=15;COUNT=6",
            from: "1997-09-02T09:00",
            on("1997-09-02", "09:00", "09:15", "09:30", "09:45", "10:00", "10:15")
        ),
        // Every hour and a half for 4 occurrences
        .init(
            "FREQ=MINUTELY;INTERVAL=90;COUNT=4",
            from: "1997-09-02T09:00",
            on("1997-09-02", "09:00", "10:30", "12:00", "13:30")
        ),
        // Every 20 minutes from 9:00 AM to 4:40 PM every day
        .init(
            "FREQ=DAILY;BYHOUR=9,10,11,12,13,14,15,16;BYMINUTE=0,20,40",
            from: "1997-09-02T09:00",
            everyTwentyMinutes(on: "1997-09-02") + everyTwentyMinutes(on: "1997-09-03")
        ),
        .init(
            "FREQ=MINUTELY;INTERVAL=20;BYHOUR=9,10,11,12,13,14,15,16",
            from: "1997-09-02T09:00",
            everyTwentyMinutes(on: "1997-09-02") + everyTwentyMinutes(on: "1997-09-03")
        ),
        // An example where the days generated makes a difference because of WKST
        .init(
            "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=MO",
            from: "1997-08-05T09:00",
            at9("1997-08-05", "1997-08-10", "1997-08-19", "1997-08-24")
        ),
        // Changing only WKST from MO to SU, yields different results
        .init(
            "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=SU",
            from: "1997-08-05T09:00",
            at9("1997-08-05", "1997-08-17", "1997-08-19", "1997-08-31")
        ),
        // An example where an invalid date (i.e., February 30) is ignored
        .init(
            "FREQ=MONTHLY;BYMONTHDAY=15,30;COUNT=5",
            from: "2007-01-15T09:00",
            at9("2007-01-15", "2007-01-30", "2007-02-15", "2007-03-15", "2007-03-30")
        ),
    ]

    private static func everyTwentyMinutes(on date: String) -> [String] {
        (9 ... 16).flatMap { hour in
            [0, 20, 40].map { minute in "\(date)T\(String(format: "%02d:%02d", hour, minute))" }
        }
    }

    @Test("Expansion matches RFC 5545", arguments: examples)
    func expansion(_ example: RFCExample) throws {
        #expect(try Self.expand(example.rule, from: example.start, limit: example.expected.count) == example.expected)
    }

    /// The RFC's example "Every 3 hours from 9:00 AM to 5:00 PM on a specific day"
    /// gives `UNTIL=19970902T170000Z`, which is 1:00 PM in New York.
    /// Verified erratum 3883 changes the value to `19970902T210000Z`.
    /// `UNTIL` bounds the rule "in an inclusive manner" (section 3.3.10),
    /// so the original value gives only 9:00 AM and 12:00 PM.
    @Test("The original UNTIL of the every-3-hours example ends at 1:00 PM")
    func everyThreeHoursOriginalUntil() throws {
        let dates = try Self.expand("FREQ=HOURLY;INTERVAL=3;UNTIL=19970902T170000Z", from: "1997-09-02T09:00", limit: 3)
        #expect(dates == on("1997-09-02", "09:00", "12:00"))
    }

    /// Expands a rule from a local start time in New York,
    /// and returns up to one more date than `limit` for a rule with an end,
    /// so that an extra date fails the comparison.
    static func expand(_ rule: String, from start: String, limit: Int) throws -> [String] {
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let parsed = try RecurrenceRule.parse(rule)
        let startDate = try #require(formatter.date(from: start))
        let hasEnd = parsed.count != nil || parsed.until != nil
        let dates = parsed.recurrences(of: startDate, calendar: calendar).prefix(hasEnd ? limit + 1 : limit)
        return dates.map(formatter.string(from:))
    }
}
