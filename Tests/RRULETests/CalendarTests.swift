import Foundation
import Testing

@testable import RRULE

@Suite("Calendar Bridge")
struct CalendarBridgeTests {
    let gregorian = Calendar(identifier: .gregorian)
    let english = Locale(identifier: "en_US")

    @Test("Calendar.RecurrenceRule integration")
    func calendarRecurrenceRuleIntegration() throws {
        guard #available(macOS 15.2, iOS 18.2, tvOS 18.2, watchOS 11.2, visionOS 2.2, *) else { return }
        let foundationRule = Calendar.RecurrenceRule(
            calendar: gregorian,
            frequency: .hourly,
            interval: 3
        )
        #expect(normalized(foundationRule.localizedDescription(in: english)) == "Every 3 hours")

        let weeklyRule = Calendar.RecurrenceRule.weekly(
            calendar: gregorian,
            interval: 2,
            weekdays: [.every(.monday), .every(.wednesday)]
        )
        #expect(normalized(weeklyRule.localizedDescription(in: english)) == "Every other week on Monday and Wednesday")

        let yearlyRule = Calendar.RecurrenceRule.yearly(
            calendar: gregorian,
            interval: 1,
            weeks: [20],
            weekdays: [.every(.monday)]
        )
        let converted = try #require(RecurrenceRule(yearlyRule))
        #expect(converted.byWeeks == [20])
        #expect(normalized(converted.localizedDescription(in: english)) == "Annually in week 20 of the year on Monday")
    }

    @Test("Conversion carries the end and the week start")
    func endAndWeekStart() throws {
        guard #available(macOS 15.2, iOS 18.2, tvOS 18.2, watchOS 11.2, visionOS 2.2, *) else { return }
        var calendar = gregorian
        calendar.firstWeekday = 1
        let counted = Calendar.RecurrenceRule(calendar: calendar, frequency: .daily, end: .afterOccurrences(5))
        let converted = try #require(RecurrenceRule(counted))
        #expect(converted.count == 5)
        #expect(converted.weekStart == .sunday)

        let until = Date(timeIntervalSince1970: 1_800_000_000)
        let dated = Calendar.RecurrenceRule(calendar: calendar, frequency: .daily, end: .afterDate(until))
        #expect(RecurrenceRule(dated)?.until == until)
    }

    @Test("Conversion fails for values that RFC 5545 can't represent")
    func unrepresentableRules() {
        guard #available(macOS 15.2, iOS 18.2, tvOS 18.2, watchOS 11.2, visionOS 2.2, *) else { return }
        let leapMonth = Calendar.RecurrenceRule.yearly(
            calendar: Calendar(identifier: .chinese),
            months: [.init(6, isLeap: true)]
        )
        #expect(RecurrenceRule(leapMonth) == nil)

        let hebrew = Calendar.RecurrenceRule.monthly(
            calendar: Calendar(identifier: .hebrew),
            daysOfTheMonth: [1]
        )
        #expect(RecurrenceRule(hebrew) == nil)
        #expect(hebrew.localizedDescription(in: english) == String(describing: hebrew))

        let buddhist = Calendar.RecurrenceRule.monthly(
            calendar: Calendar(identifier: .buddhist),
            daysOfTheMonth: [1]
        )
        #expect(RecurrenceRule(buddhist) != nil)
    }
}
