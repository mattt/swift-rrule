import Foundation
import Testing

import RRULE

/// Runs the examples in the README.
///
/// Keep these tests and the README in sync.
@Suite("Usage")
struct UsageTests {
    @Test("Usage")
    func usage() throws {
        let rule = try RecurrenceRule.parse("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR")
        #expect(rule.localizedDescription(in: Locale(identifier: "en_US")) == "Every other week on Monday, Wednesday, and Friday")
        #expect(rule.formatted(.recurrence(locale: Locale(identifier: "de_DE"))) == "Alle 2 Wochen am Montag, Mittwoch und Freitag")
        #expect("\(rule)" == "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR")

        #expect(throws: RecurrenceRule.ParseError.unknownRulePart("BYDA")) {
            try RecurrenceRule.parse("FREQ=DAILY;BYDA=MO")
        }
        #expect(RecurrenceRule(parsing: "FREQ=DAILY;BYDA=MO") == nil)
    }

    @Test("Start dates")
    func startDates() throws {
        let monthly = try RecurrenceRule.parse("FREQ=MONTHLY")
        let english = Locale(identifier: "en_US")
        let start = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 15)))
        #expect(monthly.localizedDescription(in: english) == "Monthly")
        #expect(monthly.localizedDescription(in: english, startingAt: start) == "Monthly on the 15th")
    }

    @Test("Dates")
    func dates() throws {
        guard #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))

        let rule = try RecurrenceRule.parse("FREQ=YEARLY;BYMONTH=11;BYDAY=4TH")
        // The README calls `formatted()`, which uses the current locale.
        #expect(rule.formatted(.recurrence(locale: Locale(identifier: "en_US"))) == "Annually in November on the fourth Thursday")

        let thanksgiving = try #require(Calendar.RecurrenceRule(rule, calendar: calendar))
        let style = Date.FormatStyle(date: .long, locale: Locale(identifier: "en_US"), timeZone: calendar.timeZone)
        #expect(
            thanksgiving.recurrences(of: start).prefix(3).map { $0.formatted(style) }
                == ["November 26, 2026", "November 25, 2027", "November 23, 2028"]
        )
    }

    @Test("Foundation recurrence rules")
    func foundationRecurrenceRules() throws {
        guard #available(macOS 15.2, iOS 18.2, tvOS 18.2, watchOS 11.2, visionOS 2.2, *) else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1  // Sunday

        let foundationRule = Calendar.RecurrenceRule.weekly(
            calendar: calendar,
            interval: 2,
            weekdays: [.every(.monday), .every(.wednesday)]
        )
        #expect(foundationRule.localizedDescription(in: Locale(identifier: "fr_FR")) == "Toutes les 2 semaines le lundi et le mercredi")
        let rule = try #require(RecurrenceRule(foundationRule))
        #expect("\(rule)" == "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;WKST=SU")
    }

    @Test("Languages")
    func languages() throws {
        let hours = try RecurrenceRule.parse("FREQ=DAILY;BYHOUR=9")
        #expect(normalized(hours.localizedDescription(in: Locale(identifier: "en_US"))) == "Daily at 9 AM")
        #expect(hours.localizedDescription(in: Locale(identifier: "de_DE")) == "Täglich um 09 Uhr")
    }
}
