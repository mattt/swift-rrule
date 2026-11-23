import Foundation

extension RecurrenceRulePhrasebook {
    /// Spanish (`es`) sentence templates.
    static let spanish = Self(
        locale: matchingLocale(language: "es", representative: Locale(identifier: "es_ES")),
        frequency: frequencyPhrase,
        monthsClause: { months, context in
            "en \(context.list(months.sorted().map(context.monthName)))"
        },
        weeksOfYearClause: { weeks, context in
            let items = sortedSigned(weeks).map { week in
                week > 0 ? "la semana \(context.cardinal(week))" : "la \(feminineFromEnd(week, context: context)) semana"
            }
            return "en \(context.list(items)) del año"
        },
        yearDaysClause: { days, context in
            let items = sortedSigned(days).map { day in
                day > 0 ? "el día \(context.cardinal(day))" : "el \(masculineFromEnd(day, context: context)) día"
            }
            return "\(context.list(items)) del año"
        },
        monthDaysClause: { days, context in
            let items = sortedSigned(days).map { day in
                day > 0 ? "el día \(context.cardinal(day))" : "el \(masculineFromEnd(day, context: context)) día del mes"
            }
            return context.list(items)
        },
        weekdaysClause: { days, context in
            context.list(days.map { "el \(context.weekdayName($0))" })
        },
        ordinalWeekdaysClause: { rules, context in
            let items = rules.map { rule in
                let name = context.weekdayName(rule.weekday)
                guard let occurrence = rule.occurrence else { return "el \(name)" }
                return "el \(masculineOrdinal(occurrence, context: context)) \(name)"
            }
            return context.list(items)
        },
        weekdaysSetPhrase: { _ in "los días laborables" },
        weekendsSetPhrase: { _ in "los fines de semana" },
        everyDayPhrase: { _ in "todos los días" },
        monthDayDateClause: { date, context in
            "el \(context.monthDayText(date))"
        },
        setPositionsClause: { positions, context in
            let items = sortedSigned(positions).map { "la \(feminineOrdinal($0, context: context)) ocurrencia" }
            return "limitado a \(context.list(items))"
        },
        hoursClause: { hours, minutes, seconds, context in
            let items = context.clockTimes(hours: hours, minutes: minutes, seconds: seconds)
            // "La una" is singular; every other hour is plural.
            if hours == [1] && items.count == 1 {
                return "a la \(items[0])"
            }
            return "a las \(context.list(items))"
        },
        minutesClause: { minutes, context in
            let list = context.list(minutes.sorted().map(context.cardinal))
            return minutes.count == 1 ? "en el minuto \(list)" : "en los minutos \(list)"
        },
        secondsClause: { seconds, context in
            let list = context.list(seconds.sorted().map(context.cardinal))
            return seconds.count == 1 ? "en el segundo \(list)" : "en los segundos \(list)"
        },
        countClause: { count, context in
            count == 1 ? "una vez" : "\(context.cardinal(count)) veces"
        },
        untilClause: { date, context in
            "hasta el \(context.dateText(date))"
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
    case .secondly: return interval == 1 ? "Cada segundo" : "Cada \(n) segundos"
    case .minutely: return interval == 1 ? "Cada minuto" : "Cada \(n) minutos"
    case .hourly: return interval == 1 ? "Cada hora" : "Cada \(n) horas"
    case .daily: return interval == 1 ? "Diariamente" : "Cada \(n) días"
    case .weekly: return interval == 1 ? "Semanalmente" : "Cada \(n) semanas"
    case .monthly: return interval == 1 ? "Mensualmente" : "Cada \(n) meses"
    case .yearly: return interval == 1 ? "Anualmente" : "Cada \(n) años"
    }
}

private func masculineOrdinal(_ value: Int, context: RecurrenceFormattingContext) -> String {
    if value < 0 { return masculineFromEnd(value, context: context) }
    switch value {
    case 1: return "primer"
    case 2: return "segundo"
    case 3: return "tercer"
    case 4: return "cuarto"
    case 5: return "quinto"
    default: return context.ordinalNumber(value)
    }
}

private func feminineOrdinal(_ value: Int, context: RecurrenceFormattingContext) -> String {
    if value < 0 { return feminineFromEnd(value, context: context) }
    switch value {
    case 1: return "primera"
    case 2: return "segunda"
    case 3: return "tercera"
    case 4: return "cuarta"
    case 5: return "quinta"
    default: return context.ordinalNumber(value)
    }
}

private func masculineFromEnd(_ value: Int, context: RecurrenceFormattingContext) -> String {
    switch value {
    case -1: return "último"
    case -2: return "penúltimo"
    case -3: return "antepenúltimo"
    default: return "\(context.ordinalNumber(abs(value))) desde el final"
    }
}

private func feminineFromEnd(_ value: Int, context: RecurrenceFormattingContext) -> String {
    switch value {
    case -1: return "última"
    case -2: return "penúltima"
    case -3: return "antepenúltima"
    default: return "\(context.ordinalNumber(abs(value))) desde el final"
    }
}
