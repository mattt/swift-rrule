import Foundation
import Testing

import RRULE

/// A rule and the dates that python-dateutil gives for it,
/// from `Tests/generate_dateutil_fixture.py`.
struct DateutilEntry: Decodable, CustomTestStringConvertible, Sendable {
    let rule: String
    let start: String
    let startUTC: String
    let timeZone: String
    let end: String
    let dates: [String]

    var testDescription: String { "\(rule) from \(start) in \(timeZone)" }

    var key: String { "\(rule) \(start) \(timeZone)" }
}

/// Compares the package's expansion with python-dateutil,
/// an independent implementation.
@Suite("Differential Expansion")
struct DifferentialTests {
    static let entries: [DateutilEntry] = {
        guard let url = Bundle.module.url(forResource: "dateutil-fixture", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([DateutilEntry].self, from: data)
        else {
            return []
        }
        return entries
    }()

    /// The rules for which dateutil differs from RFC 5545,
    /// with the dates that the RFC gives and the text that decides them.
    static let rfcDates: [String: (dates: [String], reason: String)] = [
        "FREQ=YEARLY;BYWEEKNO=20;COUNT=4 1997-05-12T09:00:00 America/New_York": (
            ["1997-05-12T13:00:00Z", "1998-05-11T13:00:00Z", "1999-05-17T13:00:00Z", "2000-05-15T13:00:00Z"],
            """
            dateutil gives every day of week 20. RFC 5545, section 3.3.10: "Information, not contained in the rule, \
            necessary to determine the various recurrence instance start time and dates are derived from \
            the Start Time ("DTSTART") component attribute." BYWEEKNO selects the week, \
            so DTSTART supplies the day of the week, Monday.
            """
        ),
        "FREQ=HOURLY;COUNT=6 2025-03-08T23:00:00 America/New_York": (
            [
                "2025-03-09T04:00:00Z", "2025-03-09T05:00:00Z", "2025-03-09T06:00:00Z",
                "2025-03-09T07:00:00Z", "2025-03-09T08:00:00Z", "2025-03-09T09:00:00Z",
            ],
            """
            dateutil gives 07:00Z twice: once for 2:00 AM, which doesn't exist and becomes 3:00 AM EDT \
            (section 3.3.5 and verified erratum 4271), and once for 3:00 AM EDT. \
            RFC 5545, section 3.8.5.3: "Duplicate instances are ignored." \
            The duplicate doesn't count toward COUNT.
            """
        ),
        "FREQ=MONTHLY;BYDAY=1FR,MO;COUNT=6 2026-01-01T09:00:00 UTC": (
            [
                "2026-01-02T09:00:00Z", "2026-01-05T09:00:00Z", "2026-01-12T09:00:00Z",
                "2026-01-19T09:00:00Z", "2026-01-26T09:00:00Z", "2026-02-02T09:00:00Z",
            ],
            """
            dateutil gives no dates, because it requires a day to be both the first Friday and a Monday. \
            RFC 5545, section 3.3.10: "The BYDAY rule part specifies a COMMA-separated list of days of the week" \
            and "If an integer modifier is not present, it means all days of this type within the specified \
            frequency." The rule gives the first Friday and every Monday of each month.
            """
        ),
        "FREQ=WEEKLY;BYDAY=MO,WE,FR;BYSETPOS=1;COUNT=3 2026-01-01T09:00:00 UTC": (
            ["2026-01-05T09:00:00Z", "2026-01-12T09:00:00Z", "2026-01-19T09:00:00Z"],
            """
            dateutil starts the first week's set on the start date, Thursday, January 1, \
            and gives Friday, January 2 as its first instance. \
            RFC 5545, section 3.3.10: "A set of recurrence instances starts at the beginning of the interval \
            defined by the FREQ rule part." The first instance of that week is Monday, December 29, \
            before the start date, so the first date is Monday, January 5.
            """
        ),
        "FREQ=MINUTELY;INTERVAL=30;COUNT=8 2025-03-09T00:30:00 America/New_York": (
            [
                "2025-03-09T05:30:00Z", "2025-03-09T06:00:00Z", "2025-03-09T06:30:00Z", "2025-03-09T07:00:00Z",
                "2025-03-09T07:30:00Z", "2025-03-09T08:00:00Z", "2025-03-09T08:30:00Z", "2025-03-09T09:00:00Z",
            ],
            """
            dateutil gives 07:00Z and 07:30Z twice, for 2:00 and 2:30 AM, which don't exist \
            and become 3:00 and 3:30 AM EDT (section 3.3.5 and verified erratum 4271), \
            and again for 3:00 and 3:30 AM EDT. \
            RFC 5545, section 3.8.5.3: "Duplicate instances are ignored."
            """
        ),
    ]

    @Test("The fixture loads")
    func fixtureLoads() {
        #expect(Self.entries.count > 300)
        for key in Self.rfcDates.keys {
            #expect(Self.entries.contains { $0.key == key }, "No fixture entry for \(key)")
        }
    }

    @Test("Expansion matches dateutil, or RFC 5545 where they differ", arguments: entries)
    func expansion(_ entry: DateutilEntry) throws {
        let formatter = ISO8601DateFormatter()
        let rule = try RecurrenceRule.parse(entry.rule)
        let start = try #require(formatter.date(from: entry.startUTC))
        let end = try #require(formatter.date(from: entry.end))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: entry.timeZone))

        let dates = rule.recurrences(of: start, in: start ..< end.addingTimeInterval(1), calendar: calendar)
            .prefix(25)
            .map(formatter.string(from:))
        if let rfc = Self.rfcDates[entry.key] {
            #expect(dates == rfc.dates, Comment(rawValue: rfc.reason))
            #expect(dates != entry.dates, "dateutil now agrees with RFC 5545; remove the exception.")
        } else {
            #expect(dates == entry.dates)
        }
    }
}
