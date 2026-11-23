import Foundation

extension RecurrenceRulePhrasebook {
    /// English (`en`) sentence templates.
    static let english = Self(
        locale: matchingLocale(language: "en", representative: Locale(identifier: "en_US")),
        frequency: frequencyPhrase,
        monthsClause: { months, context in
            "in \(context.list(months.sorted().map(context.monthName)))"
        },
        weeksOfYearClause: { weeks, context in
            let items = sortedSigned(weeks).map { week in
                week > 0 ? "week \(context.cardinal(week))" : "the \(fromEndWord(week, context: context)) week"
            }
            return "in \(context.list(items)) of the year"
        },
        yearDaysClause: { days, context in
            let items = sortedSigned(days).map { day in
                day > 0 ? "day \(context.cardinal(day))" : "the \(fromEndWord(day, context: context)) day"
            }
            return "on \(context.list(items)) of the year"
        },
        monthDaysClause: { days, context in
            let items = sortedSigned(days).map { day in
                day > 0 ? context.ordinalNumber(day) : "\(fromEndWord(day, context: context)) day of the month"
            }
            return "on the \(context.list(items))"
        },
        weekdaysClause: { days, context in
            "on \(context.list(days.map(context.weekdayName)))"
        },
        ordinalWeekdaysClause: { rules, context in
            let items = rules.map { rule in
                let name = context.weekdayName(rule.weekday)
                guard let occurrence = rule.occurrence else { return name }
                return "the \(ordinalWord(occurrence, context: context)) \(name)"
            }
            return "on \(context.list(items))"
        },
        weekdaysSetPhrase: { _ in "on weekdays" },
        weekendsSetPhrase: { _ in "on weekends" },
        everyDayPhrase: { _ in "every day" },
        monthDayDateClause: { date, context in
            "on \(context.monthDayText(date))"
        },
        setPositionsClause: { positions, context in
            let items = sortedSigned(positions).map { "the \(ordinalWord($0, context: context)) occurrence" }
            return "limited to \(context.list(items))"
        },
        hoursClause: { hours, minutes, seconds, context in
            "at \(context.list(context.clockTimes(hours: hours, minutes: minutes, seconds: seconds)))"
        },
        minutesClause: { minutes, context in
            let list = context.list(minutes.sorted().map(context.cardinal))
            return minutes.count == 1 ? "at minute \(list)" : "at minutes \(list)"
        },
        secondsClause: { seconds, context in
            let list = context.list(seconds.sorted().map(context.cardinal))
            return seconds.count == 1 ? "at second \(list)" : "at seconds \(list)"
        },
        countClause: { count, context in
            count == 1 ? "once" : "\(context.cardinal(count)) times"
        },
        untilClause: { date, context in
            "until \(context.dateText(date))"
        }
    )
}

// MARK: - Helpers

private func frequencyPhrase(
    _ frequency: RecurrenceRule.Frequency,
    interval: Int,
    context: RecurrenceFormattingContext
) -> String {
    switch frequency {
    case .secondly:
        return interval == 1 ? "Every second" : "Every \(context.cardinal(interval)) seconds"
    case .minutely:
        return interval == 1 ? "Every minute" : "Every \(context.cardinal(interval)) minutes"
    case .hourly:
        return interval == 1 ? "Hourly" : "Every \(context.cardinal(interval)) hours"
    case .daily:
        if interval == 1 { return "Daily" }
        if interval == 2 { return "Every other day" }
        return "Every \(context.cardinal(interval)) days"
    case .weekly:
        if interval == 1 { return "Weekly" }
        if interval == 2 { return "Every other week" }
        return "Every \(context.cardinal(interval)) weeks"
    case .monthly:
        if interval == 1 { return "Monthly" }
        if interval == 2 { return "Every other month" }
        return "Every \(context.cardinal(interval)) months"
    case .yearly:
        if interval == 1 { return "Annually" }
        if interval == 2 { return "Every other year" }
        return "Every \(context.cardinal(interval)) years"
    }
}

private func ordinalWord(_ value: Int, context: RecurrenceFormattingContext) -> String {
    switch value {
    case 1: return "first"
    case 2: return "second"
    case 3: return "third"
    case 4: return "fourth"
    case 5: return "fifth"
    case ...0: return fromEndWord(value, context: context)
    default: return context.ordinalNumber(value)
    }
}

private func fromEndWord(_ value: Int, context: RecurrenceFormattingContext) -> String {
    switch value {
    case -1: return "last"
    case -2: return "second to last"
    case -3: return "third to last"
    case -4: return "fourth to last"
    case -5: return "fifth to last"
    default: return "\(context.ordinalNumber(abs(value))) to last"
    }
}
