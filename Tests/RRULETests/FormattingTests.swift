import Foundation
import Testing

@testable import RRULE

@Suite("English Formatting")
struct EnglishFormattingTests {
    @Test("Hourly recurrence with interval")
    func hourlyWithInterval() throws {
        #expect(try english("FREQ=HOURLY;INTERVAL=3") == "Every 3 hours")
        #expect(try english("FREQ=HOURLY") == "Hourly")
    }

    @Test("Daily recurrence variations")
    func dailyRecurrence() throws {
        #expect(try english("FREQ=DAILY") == "Daily")
        #expect(try english("FREQ=DAILY;INTERVAL=2") == "Every other day")
        #expect(try english("FREQ=DAILY;INTERVAL=3") == "Every 3 days")
    }

    @Test("Weekly recurrence with days of the week")
    func weeklyWithDays() throws {
        #expect(try english("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR") == "Every other week on Monday, Wednesday, and Friday")
        #expect(try english("FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR") == "Weekly on weekdays")
        #expect(try english("FREQ=WEEKLY;BYDAY=SA,SU") == "Weekly on weekends")
    }

    @Test("Weekday order follows the locale first weekday")
    func weekdayOrder() throws {
        #expect(try localized("FREQ=WEEKLY;BYDAY=MO,SU", "en_US") == "Weekly on Sunday and Monday")
        #expect(try localized("FREQ=WEEKLY;BYDAY=MO,SU", "de_DE") == "Wöchentlich am Montag und Sonntag")
    }

    @Test("Monthly recurrence with positional days and month days")
    func monthlyRecurrence() throws {
        #expect(try english("FREQ=MONTHLY;BYDAY=1SU") == "Monthly on the first Sunday")
        #expect(try english("FREQ=MONTHLY;BYDAY=-1FR") == "Monthly on the last Friday")
        #expect(try english("FREQ=MONTHLY;BYMONTHDAY=15") == "Monthly on the 15th")
        #expect(try english("FREQ=MONTHLY;BYMONTHDAY=1,15") == "Monthly on the 1st and 15th")
        #expect(try english("FREQ=MONTHLY;BYMONTHDAY=-1") == "Monthly on the last day of the month")
        #expect(try english("FREQ=MONTHLY;BYMONTHDAY=-2") == "Monthly on the second to last day of the month")
    }

    @Test("Yearly recurrence")
    func yearlyRecurrence() throws {
        #expect(try english("FREQ=YEARLY") == "Annually")
        #expect(try english("FREQ=YEARLY;INTERVAL=4") == "Every 4 years")
        #expect(try english("FREQ=YEARLY;BYMONTH=7") == "Annually in July")
    }

    @Test("Time-of-day parts produce clauses")
    func timeOfDayParts() throws {
        #expect(try english("FREQ=DAILY;BYHOUR=9,17") == "Daily at 9 AM and 5 PM")
        #expect(try english("FREQ=DAILY;BYHOUR=9;BYMINUTE=30") == "Daily at 9:30 AM")
        #expect(try english("FREQ=HOURLY;BYMINUTE=0,30") == "Hourly at minutes 0 and 30")
        #expect(try english("FREQ=MINUTELY;BYSECOND=15") == "Every minute at second 15")
    }

    @Test("Year parts produce clauses")
    func yearParts() throws {
        #expect(try english("FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO") == "Annually in week 20 of the year on Monday")
        #expect(try english("FREQ=YEARLY;BYYEARDAY=100") == "Annually on day 100 of the year")
        #expect(try english("FREQ=YEARLY;BYYEARDAY=-1") == "Annually on the last day of the year")
    }

    @Test("Set positions produce a clause even with ordinal weekdays")
    func setPositions() throws {
        #expect(try english("FREQ=MONTHLY;BYDAY=1SU;BYSETPOS=1") == "Monthly on the first Sunday limited to the first occurrence")
    }

    @Test("End conditions: count and until")
    func endConditions() throws {
        #expect(try english("FREQ=DAILY;COUNT=5") == "Daily, 5 times")
        #expect(try english("FREQ=DAILY;COUNT=1") == "Daily, once")
        #expect(try english("FREQ=DAILY;UNTIL=20261231") == "Daily, until December 31, 2026")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let until = try #require(
            calendar.date(
                from: DateComponents(
                    calendar: calendar,
                    year: 2026,
                    month: 12,
                    day: 31,
                    hour: 15,
                    minute: 30
                )
            )
        )
        let rule = RecurrenceRule(frequency: .daily, until: until)
        #expect(normalized(rule.localizedDescription(in: Locale(identifier: "en_US"))) == "Daily, until December 31, 2026 at 3:30 PM")
    }

    @Test("Duplicate list entries are normalized away")
    func duplicateEntries() throws {
        let rule = try #require(RecurrenceRule(parsing: "FREQ=WEEKLY;BYDAY=MO,MO"))
        #expect(rule.byWeekdays.count == 1)
        #expect(try english("FREQ=WEEKLY;BYDAY=MO,MO") == "Weekly on Monday")
    }

    @Test("Start date names the implied day")
    func startDateImpliedDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        // January 15, 2026 is a Thursday.
        let start = try #require(
            calendar.date(
                from: DateComponents(
                    calendar: calendar,
                    year: 2026,
                    month: 1,
                    day: 15
                )
            )
        )
        let locale = Locale(identifier: "en_US")
        let weekly = try #require(RecurrenceRule(parsing: "FREQ=WEEKLY"))
        #expect(weekly.localizedDescription(in: locale, startingAt: start) == "Weekly on Thursday")
        let monthly = try #require(RecurrenceRule(parsing: "FREQ=MONTHLY"))
        #expect(monthly.localizedDescription(in: locale, startingAt: start) == "Monthly on the 15th")
        let yearly = try #require(RecurrenceRule(parsing: "FREQ=YEARLY"))
        #expect(yearly.localizedDescription(in: locale, startingAt: start) == "Annually on January 15")
    }
}
