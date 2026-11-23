import Foundation

extension RecurrenceRule.Weekday {
    /// Creates a weekday from a Foundation locale weekday.
    init?(localeWeekday: Locale.Weekday) {
        switch localeWeekday {
        case .sunday: self = .sunday
        case .monday: self = .monday
        case .tuesday: self = .tuesday
        case .wednesday: self = .wednesday
        case .thursday: self = .thursday
        case .friday: self = .friday
        case .saturday: self = .saturday
        @unknown default: return nil
        }
    }

    /// The Foundation locale weekday for the weekday.
    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }
}

extension RecurrenceRule {
    /// The calendars whose months and days match the Gregorian calendar's,
    /// which RFC 5545 uses.
    static let gregorianCalendars: Set<Calendar.Identifier> = [
        .gregorian, .iso8601, .buddhist, .japanese, .republicOfChina,
    ]
}

@available(macOS 15.2, iOS 18.2, tvOS 18.2, watchOS 11.2, visionOS 2.2, *)
extension RecurrenceRule {
    /// Creates a recurrence rule from a Foundation recurrence rule.
    ///
    /// The conversion carries the frequency, the interval, the end,
    /// every list of months, days, weeks, times, and set positions,
    /// and the first weekday of the rule's calendar as the week start.
    /// The matching and repeated-time policies
    /// have no RFC 5545 counterpart, so they don't carry over.
    ///
    /// A partial conversion would describe a different rule,
    /// so the initializer fails if the rule has a value
    /// that RFC 5545 can't represent.
    /// That includes a leap month,
    /// a calendar whose months and days differ from the Gregorian calendar's,
    /// and a frequency from a later release of Foundation.
    ///
    /// - Parameter foundationRule: The Foundation recurrence rule to convert.
    public init?(_ foundationRule: Calendar.RecurrenceRule) {
        guard Self.gregorianCalendars.contains(foundationRule.calendar.identifier),
            foundationRule.months.allSatisfy({ !$0.isLeap })
        else {
            return nil
        }

        let frequency: Frequency
        switch foundationRule.frequency {
        case .minutely: frequency = .minutely
        case .hourly: frequency = .hourly
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: return nil
        }

        var mappedWeekdays: [WeekdayRule] = []
        for weekday in foundationRule.weekdays {
            switch weekday {
            case .every(let day):
                guard let mapped = Weekday(localeWeekday: day) else { return nil }
                mappedWeekdays.append(WeekdayRule(weekday: mapped))
            case .nth(let n, let day):
                guard let mapped = Weekday(localeWeekday: day),
                    RecurrenceRule.isValidSignedOrdinal(n, limit: 53)
                else { return nil }
                mappedWeekdays.append(WeekdayRule(weekday: mapped, occurrence: n))
            @unknown default:
                return nil
            }
        }

        guard let weekStart = Weekday(calendarWeekday: foundationRule.calendar.firstWeekday) else {
            return nil
        }

        guard
            let validated = RecurrenceRule.validated(
                frequency: frequency,
                interval: foundationRule.interval,
                count: foundationRule.end.occurrences,
                until: foundationRule.end.date,
                bySeconds: foundationRule.seconds,
                byMinutes: foundationRule.minutes,
                byHours: foundationRule.hours,
                byWeekdays: mappedWeekdays,
                byMonthDays: foundationRule.daysOfTheMonth,
                byYearDays: foundationRule.daysOfTheYear,
                byWeeks: foundationRule.weeks,
                byMonths: foundationRule.months.map(\.index),
                bySetPositions: foundationRule.setPositions,
                weekStart: weekStart
            )
        else {
            return nil
        }
        self = validated
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
extension Calendar.RecurrenceRule {
    /// Creates a Foundation recurrence rule from a recurrence rule,
    /// for the Foundation APIs that take a `Calendar.RecurrenceRule`.
    ///
    /// To list the dates of a rule, call ``RRULE/RecurrenceRule/recurrences(of:in:calendar:)``.
    /// As of the macOS 27 SDK, the dates of Foundation's `recurrences(of:in:)`
    /// differ from RFC 5545 for some rules,
    /// such as a weekday without an occurrence in a monthly rule.
    ///
    /// The conversion carries the frequency, the interval,
    /// the count or the date that ends the rule,
    /// and every list of months, days, weeks, times, and set positions,
    /// including weekdays with an occurrence, such as `1SU` and `-1MO`.
    ///
    /// RFC 5545 starts each week on the day that `WKST` names,
    /// and counts as week 1 the first week with at least four days in the year.
    /// The result's calendar is a copy of `calendar`
    /// with its `firstWeekday` set to the rule's week start
    /// and its `minimumDaysInFirstWeek` set to 4,
    /// so these two properties can differ from the argument's.
    /// The calendar keeps the argument's time zone and locale.
    ///
    /// The result uses Foundation's default matching and repeated-time policies,
    /// `nextTimePreservingSmallerComponents` and `first`.
    ///
    /// A partial conversion would expand a different rule,
    /// so the initializer fails if Foundation can't represent the rule.
    /// That includes a rule that repeats every second (`FREQ=SECONDLY`),
    /// a leap second (`BYSECOND=60`),
    /// and a calendar whose months and days differ from the Gregorian calendar's,
    /// such as the Hebrew calendar.
    ///
    /// - Parameters:
    ///   - rule: The recurrence rule to convert.
    ///   - calendar: The calendar that supplies the time zone and locale
    ///     for the expansion.
    public init?(_ rule: RecurrenceRule, calendar: Calendar = .current) {
        guard RecurrenceRule.gregorianCalendars.contains(calendar.identifier),
            !rule.bySeconds.contains(60)
        else {
            return nil
        }

        let frequency: Frequency
        switch rule.frequency {
        case .secondly: return nil
        case .minutely: frequency = .minutely
        case .hourly: frequency = .hourly
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }

        let end: End
        if let count = rule.count {
            end = .afterOccurrences(count)
        } else if let until = rule.until {
            end = .afterDate(until)
        } else {
            end = .never
        }

        var calendar = calendar
        calendar.firstWeekday = rule.weekStart.calendarWeekday
        calendar.minimumDaysInFirstWeek = 4

        self.init(
            calendar: calendar,
            frequency: frequency,
            interval: rule.interval,
            end: end,
            months: rule.byMonths.map { Month($0) },
            daysOfTheYear: rule.byYearDays,
            daysOfTheMonth: rule.byMonthDays,
            weeks: rule.byWeeks,
            weekdays: rule.byWeekdays.map { weekdayRule in
                if let occurrence = weekdayRule.occurrence {
                    .nth(occurrence, weekdayRule.weekday.localeWeekday)
                } else {
                    .every(weekdayRule.weekday.localeWeekday)
                }
            },
            hours: rule.byHours,
            minutes: rule.byMinutes,
            seconds: rule.bySeconds,
            setPositions: rule.bySetPositions
        )
    }
}

@available(macOS 15.2, iOS 18.2, tvOS 18.2, watchOS 11.2, visionOS 2.2, *)
extension Calendar.RecurrenceRule {
    /// Describes the rule in natural language for the current locale.
    ///
    /// If ``RRULE/RecurrenceRule/init(_:)`` can't convert the rule,
    /// this method returns the rule's debug description
    /// in place of a description of part of the rule.
    /// To detect that case, convert the rule yourself.
    ///
    /// - Returns: A description of the rule, such as "Every 3 hours".
    public func formatted() -> String {
        RecurrenceRule(self)?.formatted() ?? String(describing: self)
    }

    /// Describes the rule in natural language for a locale.
    ///
    /// If ``RRULE/RecurrenceRule/init(_:)`` can't convert the rule,
    /// this method returns the rule's debug description
    /// in place of a description of part of the rule.
    /// To detect that case, convert the rule yourself.
    ///
    /// - Parameters:
    ///   - locale: The locale for the language
    ///     and for the names, lists, numbers, and dates in the description.
    ///   - startDate: The start date of the first event, if you know it.
    ///     For a weekly, monthly, or yearly rule that selects no day,
    ///     the description names the day that the start date implies.
    /// - Returns: A description of the rule, such as "Monthly on the 15th".
    public func localizedDescription(in locale: Locale = .current, startingAt startDate: Date? = nil) -> String {
        RecurrenceRule(self)?.localizedDescription(in: locale, startingAt: startDate) ?? String(describing: self)
    }
}
