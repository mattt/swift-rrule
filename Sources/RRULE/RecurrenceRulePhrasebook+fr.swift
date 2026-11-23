import Foundation

extension RecurrenceRulePhrasebook {
    /// French (`fr`) sentence templates.
    static let french = Self(
        locale: matchingLocale(language: "fr", representative: Locale(identifier: "fr_FR")),
        frequency: frequencyPhrase,
        monthsClause: { months, context in
            "en \(context.list(months.sorted().map(context.monthName)))"
        },
        weeksOfYearClause: { weeks, context in
            let items = sortedSigned(weeks).map { week in
                week > 0 ? "la \(context.ordinalNumber(week)) semaine" : "la \(feminineFromEnd(week, context: context)) semaine"
            }
            return "\(context.list(items)) de l'année"
        },
        yearDaysClause: { days, context in
            let items = sortedSigned(days).map { day in
                day > 0 ? "le \(context.ordinalNumber(day)) jour" : "le \(masculineFromEnd(day, context: context)) jour"
            }
            return "\(context.list(items)) de l'année"
        },
        monthDaysClause: { days, context in
            let items = sortedSigned(days).map { day in
                if day == 1 { return "le 1er" }
                if day > 0 { return "le \(context.cardinal(day))" }
                return "le \(masculineFromEnd(day, context: context)) jour du mois"
            }
            return context.list(items)
        },
        weekdaysClause: { days, context in
            context.list(days.map { "le \(context.weekdayName($0))" })
        },
        ordinalWeekdaysClause: { rules, context in
            let items = rules.map { rule in
                let name = context.weekdayName(rule.weekday)
                guard let occurrence = rule.occurrence else { return "le \(name)" }
                return "le \(masculineOrdinal(occurrence, context: context)) \(name)"
            }
            return context.list(items)
        },
        weekdaysSetPhrase: { _ in "en semaine" },
        weekendsSetPhrase: { _ in "le week-end" },
        everyDayPhrase: { _ in "tous les jours" },
        monthDayDateClause: { date, context in
            "le \(context.monthDayText(date))"
        },
        setPositionsClause: { positions, context in
            let items = sortedSigned(positions).map { "la \(feminineOrdinal($0, context: context)) occurrence" }
            return "limité à \(context.list(items))"
        },
        hoursClause: { hours, minutes, seconds, context in
            "à \(context.list(context.clockTimes(hours: hours, minutes: minutes, seconds: seconds)))"
        },
        minutesClause: { minutes, context in
            let list = context.list(minutes.sorted().map(context.cardinal))
            return minutes.count == 1 ? "à la minute \(list)" : "aux minutes \(list)"
        },
        secondsClause: { seconds, context in
            let list = context.list(seconds.sorted().map(context.cardinal))
            return seconds.count == 1 ? "à la seconde \(list)" : "aux secondes \(list)"
        },
        countClause: { count, context in
            count == 1 ? "une fois" : "\(context.cardinal(count)) fois"
        },
        untilClause: { date, context in
            "jusqu'au \(context.dateText(date))"
        }
    )
}

// MARK: - Helpers

private func frequencyPhrase(
    _ frequency: RecurrenceRule.Frequency,
    interval: Int,
    context: RecurrenceFormattingContext
) -> String {
    let n = context.cardinal(interval)
    switch frequency {
    case .secondly: return interval == 1 ? "Chaque seconde" : "Toutes les \(n) secondes"
    case .minutely: return interval == 1 ? "Chaque minute" : "Toutes les \(n) minutes"
    case .hourly: return interval == 1 ? "Toutes les heures" : "Toutes les \(n) heures"
    case .daily: return interval == 1 ? "Tous les jours" : "Tous les \(n) jours"
    case .weekly: return interval == 1 ? "Toutes les semaines" : "Toutes les \(n) semaines"
    case .monthly: return interval == 1 ? "Tous les mois" : "Tous les \(n) mois"
    case .yearly: return interval == 1 ? "Tous les ans" : "Tous les \(n) ans"
    }
}

private func masculineOrdinal(_ value: Int, context: RecurrenceFormattingContext) -> String {
    if value < 0 { return masculineFromEnd(value, context: context) }
    switch value {
    case 1: return "premier"
    case 2: return "deuxième"
    case 3: return "troisième"
    case 4: return "quatrième"
    case 5: return "cinquième"
    default: return context.ordinalNumber(value)
    }
}

private func feminineOrdinal(_ value: Int, context: RecurrenceFormattingContext) -> String {
    if value < 0 { return feminineFromEnd(value, context: context) }
    switch value {
    case 1: return "première"
    case 2: return "deuxième"
    case 3: return "troisième"
    case 4: return "quatrième"
    case 5: return "cinquième"
    default: return context.ordinalNumber(value)
    }
}

private func masculineFromEnd(_ value: Int, context: RecurrenceFormattingContext) -> String {
    switch value {
    case -1: return "dernier"
    case -2: return "avant-dernier"
    default: return "\(context.ordinalNumber(abs(value))) avant la fin"
    }
}

private func feminineFromEnd(_ value: Int, context: RecurrenceFormattingContext) -> String {
    switch value {
    case -1: return "dernière"
    case -2: return "avant-dernière"
    default: return "\(context.ordinalNumber(abs(value))) avant la fin"
    }
}
