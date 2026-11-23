import Foundation

extension RecurrenceRulePhrasebook {
    /// German (`de`) sentence templates.
    static let german = Self(
        locale: matchingLocale(language: "de", representative: Locale(identifier: "de_DE")),
        frequency: frequencyPhrase,
        monthsClause: { months, context in
            "im \(context.list(months.sorted().map(context.monthName)))"
        },
        weeksOfYearClause: { weeks, context in
            let items = sortedSigned(weeks).map { week in
                week > 0 ? "Woche \(context.cardinal(week))" : "der \(fromEndGenitive(week, context: context)) Woche"
            }
            return "in \(context.list(items)) des Jahres"
        },
        yearDaysClause: { days, context in
            let items = sortedSigned(days).map { day in
                day > 0 ? "Tag \(context.cardinal(day))" : "\(fromEndDative(day, context: context)) Tag"
            }
            return "am \(context.list(items)) des Jahres"
        },
        monthDaysClause: { days, context in
            let items = sortedSigned(days).map { day in
                day > 0 ? context.ordinalNumber(day) : "\(fromEndDative(day, context: context)) Tag des Monats"
            }
            return "am \(context.list(items))"
        },
        weekdaysClause: { days, context in
            "am \(context.list(days.map(context.weekdayName)))"
        },
        ordinalWeekdaysClause: { rules, context in
            let items = rules.map { rule in
                let name = context.weekdayName(rule.weekday)
                guard let occurrence = rule.occurrence else { return name }
                return "\(dativeOrdinal(occurrence, context: context)) \(name)"
            }
            return "am \(context.list(items))"
        },
        weekdaysSetPhrase: { _ in "an Wochentagen" },
        weekendsSetPhrase: { _ in "am Wochenende" },
        everyDayPhrase: { _ in "jeden Tag" },
        monthDayDateClause: { date, context in
            "am \(context.monthDayText(date))"
        },
        setPositionsClause: { positions, context in
            let items = sortedSigned(positions).map { "das \(nominativeOrdinal($0, context: context)) Vorkommen" }
            return "beschränkt auf \(context.list(items))"
        },
        hoursClause: hoursPhrase,
        minutesClause: { minutes, context in
            let list = context.list(minutes.sorted().map(context.cardinal))
            return minutes.count == 1 ? "in der Minute \(list)" : "in den Minuten \(list)"
        },
        secondsClause: { seconds, context in
            let list = context.list(seconds.sorted().map(context.cardinal))
            return seconds.count == 1 ? "in der Sekunde \(list)" : "in den Sekunden \(list)"
        },
        countClause: { count, context in
            count == 1 ? "einmal" : "\(context.cardinal(count))-mal"
        },
        untilClause: { date, context in
            "bis zum \(context.dateText(date))"
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
    case .secondly: return interval == 1 ? "Jede Sekunde" : "Alle \(n) Sekunden"
    case .minutely: return interval == 1 ? "Jede Minute" : "Alle \(n) Minuten"
    case .hourly: return interval == 1 ? "Stündlich" : "Alle \(n) Stunden"
    case .daily: return interval == 1 ? "Täglich" : "Alle \(n) Tage"
    case .weekly: return interval == 1 ? "Wöchentlich" : "Alle \(n) Wochen"
    case .monthly: return interval == 1 ? "Monatlich" : "Alle \(n) Monate"
    case .yearly: return interval == 1 ? "Jährlich" : "Alle \(n) Jahre"
    }
}

private func hoursPhrase(
    hours: [Int],
    minutes: [Int],
    seconds: [Int],
    context: RecurrenceFormattingContext
) -> String {
    let items = context.clockTimes(hours: hours, minutes: minutes, seconds: seconds)
    // The CLDR hour pattern already ends in "Uhr" for whole hours.
    if items.allSatisfy({ $0.hasSuffix("Uhr") }) {
        return "um \(context.list(items))"
    }
    return "um \(context.list(items)) Uhr"
}

private func dativeOrdinal(_ value: Int, context: RecurrenceFormattingContext) -> String {
    if value < 0 { return fromEndDative(value, context: context) }
    switch value {
    case 1: return "ersten"
    case 2: return "zweiten"
    case 3: return "dritten"
    case 4: return "vierten"
    case 5: return "fünften"
    default: return context.ordinalNumber(value)
    }
}

private func nominativeOrdinal(_ value: Int, context: RecurrenceFormattingContext) -> String {
    switch value {
    case -1: return "letzte"
    case -2: return "zweitletzte"
    case -3: return "drittletzte"
    case -4: return "viertletzte"
    case -5: return "fünftletzte"
    case 1: return "erste"
    case 2: return "zweite"
    case 3: return "dritte"
    case 4: return "vierte"
    case 5: return "fünfte"
    default: return context.ordinalNumber(abs(value))
    }
}

private func fromEndDative(_ value: Int, context: RecurrenceFormattingContext) -> String {
    switch value {
    case -1: return "letzten"
    case -2: return "zweitletzten"
    case -3: return "drittletzten"
    case -4: return "viertletzten"
    case -5: return "fünftletzten"
    default: return context.ordinalNumber(abs(value))
    }
}

private func fromEndGenitive(_ value: Int, context: RecurrenceFormattingContext) -> String {
    // After "der" the dative and genitive feminine forms coincide here.
    fromEndDative(value, context: context)
}
