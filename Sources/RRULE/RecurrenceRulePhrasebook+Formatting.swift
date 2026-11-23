import Foundation

extension RecurrenceRulePhrasebook {
    /// Describes a rule with the phrasebook's sentence templates.
    ///
    /// Every stored value of a rule contributes to a clause,
    /// so a description never leaves out part of the rule.
    ///
    /// - Parameters:
    ///   - rule: The rule to describe.
    ///   - requestedLocale: The locale for the names, lists, numbers, and dates in the description,
    ///     which ``locale`` can replace.
    ///   - startDate: The start date of the first event, if you know it.
    ///     For a weekly, monthly, or yearly rule that selects no day,
    ///     the description names the day that the start date implies.
    /// - Returns: A description of the rule.
    func format(_ rule: RecurrenceRule, locale requestedLocale: Locale, startDate: Date?) -> String {
        let locale = self.locale(requestedLocale)
        let context = RecurrenceFormattingContext(locale: locale)
        var clauses: [String] = []

        clauses.append(frequency(rule.frequency, rule.interval, context))

        if !rule.byMonths.isEmpty {
            clauses.append(monthsClause(rule.byMonths, context))
        }
        if !rule.byWeeks.isEmpty {
            clauses.append(weeksOfYearClause(rule.byWeeks, context))
        }
        if !rule.byYearDays.isEmpty {
            clauses.append(yearDaysClause(rule.byYearDays, context))
        }
        if !rule.byMonthDays.isEmpty {
            clauses.append(monthDaysClause(rule.byMonthDays, context))
        }

        if !rule.byWeekdays.isEmpty {
            clauses.append(byDayClause(rule.byWeekdays, context: context))
        } else if let startDate, let implied = impliedClause(rule: rule, startDate: startDate, context: context) {
            clauses.append(implied)
        }

        if !rule.bySetPositions.isEmpty {
            clauses.append(setPositionsClause(rule.bySetPositions, context))
        }

        clauses.append(contentsOf: timeClauses(rule: rule, context: context))

        var result = clauses.joined(separator: " ")
        if let count = rule.count {
            result += ", \(countClause(count, context))"
        } else if let until = rule.until {
            result += ", \(untilClause(until, context))"
        }

        guard let first = result.first else { return result }
        return String(first).uppercased(with: locale) + result.dropFirst()
    }

    /// Returns the clause for the `BYDAY` entries,
    /// in the order of the locale's week.
    private func byDayClause(_ rules: [RecurrenceRule.WeekdayRule], context: RecurrenceFormattingContext) -> String {
        let firstWeekday = context.calendar.firstWeekday
        func order(_ weekday: RecurrenceRule.Weekday) -> Int {
            (weekday.calendarWeekday - firstWeekday + 7) % 7
        }

        if rules.allSatisfy({ $0.occurrence == nil }) {
            let days = rules.map(\.weekday)
            let uniqueDays = Set(days)
            if uniqueDays == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) {
                return weekdaysSetPhrase(context)
            }
            if uniqueDays == Set([.saturday, .sunday]) {
                return weekendsSetPhrase(context)
            }
            if uniqueDays.count == 7 {
                return everyDayPhrase(context)
            }
            return weekdaysClause(days.sorted { order($0) < order($1) }, context)
        }

        let sorted = rules.sorted {
            let left = order($0.weekday)
            let right = order($1.weekday)
            if left != right { return left < right }
            return ($0.occurrence ?? 0) < ($1.occurrence ?? 0)
        }
        return ordinalWeekdaysClause(sorted, context)
    }

    /// Returns the clause that a start date implies for a rule that selects no day.
    private func impliedClause(rule: RecurrenceRule, startDate: Date, context: RecurrenceFormattingContext) -> String? {
        let components = context.calendar.dateComponents([.weekday, .day], from: startDate)
        switch rule.frequency {
        case .weekly:
            guard let weekday = components.weekday.flatMap(RecurrenceRule.Weekday.init(calendarWeekday:)) else {
                return nil
            }
            return weekdaysClause([weekday], context)
        case .monthly:
            guard rule.byMonthDays.isEmpty, let day = components.day else { return nil }
            return monthDaysClause([day], context)
        case .yearly:
            guard rule.byMonths.isEmpty, rule.byMonthDays.isEmpty,
                rule.byYearDays.isEmpty, rule.byWeeks.isEmpty
            else { return nil }
            return monthDayDateClause(startDate, context)
        default:
            return nil
        }
    }

    /// Returns the clauses for the hours, minutes, and seconds of a rule.
    private func timeClauses(rule: RecurrenceRule, context: RecurrenceFormattingContext) -> [String] {
        var clauses: [String] = []
        var minutesCovered = false
        var secondsCovered = false

        if !rule.byHours.isEmpty {
            clauses.append(hoursClause(rule.byHours, rule.byMinutes, rule.bySeconds, context))
            if context.clockTimesIncludeMinutes(hours: rule.byHours, minutes: rule.byMinutes, seconds: rule.bySeconds) {
                minutesCovered = true
                secondsCovered = !rule.bySeconds.isEmpty
            }
        }
        if !rule.byMinutes.isEmpty && !minutesCovered {
            clauses.append(minutesClause(rule.byMinutes, context))
        }
        if !rule.bySeconds.isEmpty && !secondsCovered {
            clauses.append(secondsClause(rule.bySeconds, context))
        }
        return clauses
    }
}
