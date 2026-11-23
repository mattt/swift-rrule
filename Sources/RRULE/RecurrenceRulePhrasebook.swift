import Foundation

/// Formatting helpers for a locale,
/// which take names, lists, ordinals, numbers, dates, and times
/// from the CLDR data in Foundation.
///
/// A phrasebook supplies only the sentence templates of one language.
/// Every part of a description that CLDR covers,
/// such as weekday and month names, list conjunctions,
/// ordinal suffixes, and clock times,
/// comes from these helpers, not from data in the package.
struct RecurrenceFormattingContext {
    let locale: Locale
    let calendar: Calendar

    init(locale: Locale) {
        self.locale = locale
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = .current
        self.calendar = calendar
    }

    /// Joins items with the CLDR list pattern of the locale.
    func list(_ items: [String]) -> String {
        items.formatted(.list(type: .and).locale(locale))
    }

    /// Formats an integer with the locale digits and grouping.
    func cardinal(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    /// Formats an ordinal number, such as "15th", "15.", or "15e".
    func ordinalNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        formatter.locale = locale
        return formatter.string(for: value) ?? cardinal(value)
    }

    /// The standalone CLDR weekday name, in sentence case for the locale.
    func weekdayName(_ weekday: RecurrenceRule.Weekday) -> String {
        calendar.standaloneWeekdaySymbols[weekday.calendarWeekday - 1]
    }

    /// The standalone CLDR month name for a month in 1...12.
    func monthName(_ month: Int) -> String {
        calendar.standaloneMonthSymbols[month - 1]
    }

    /// A clock time such as "9:30 AM" or "9:30", following CLDR patterns.
    func timeText(hour: Int, minute: Int, second: Int? = nil) -> String {
        var components = DateComponents()
        components.calendar = calendar
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        components.second = second ?? 0
        guard let date = components.date else { return "\(hour):\(minute)" }
        if second != nil {
            return date.formatted(Date.FormatStyle(date: .omitted, time: .standard, locale: locale))
        }
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
    }

    /// An hour without minutes, such as "9 AM", following CLDR patterns.
    func hourText(hour: Int) -> String {
        var components = DateComponents()
        components.calendar = calendar
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = 0
        guard let date = components.date else { return cardinal(hour) }
        return date.formatted(.dateTime.hour().locale(locale))
    }

    /// A full date, including the time when the date is not at local midnight.
    func dateText(_ date: Date) -> String {
        let time = calendar.dateComponents([.hour, .minute, .second], from: date)
        let isMidnight = (time.hour ?? 0) == 0 && (time.minute ?? 0) == 0 && (time.second ?? 0) == 0
        if isMidnight {
            return date.formatted(Date.FormatStyle(date: .long, locale: locale))
        }
        return date.formatted(Date.FormatStyle(date: .long, time: .shortened, locale: locale))
    }

    /// A month and day without a year, such as "July 15".
    func monthDayText(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day().locale(locale))
    }

    /// Returns whether an hours clause names each time with its minute,
    /// and with its second if the rule has seconds.
    ///
    /// This is true when the rule has minutes
    /// and the combinations of hours, minutes, and seconds are few.
    /// Otherwise, each time names only the hour,
    /// so the description doesn't invent a minute
    /// that the rule takes from the start date.
    func clockTimesIncludeMinutes(hours: [Int], minutes: [Int], seconds: [Int]) -> Bool {
        guard !minutes.isEmpty else { return false }
        return hours.count * minutes.count * max(seconds.count, 1) <= 8
    }

    /// Returns the clock times for an hours clause, such as "9:30 AM" or "9 AM".
    func clockTimes(hours: [Int], minutes: [Int], seconds: [Int]) -> [String] {
        let sortedHours = hours.sorted()
        guard clockTimesIncludeMinutes(hours: hours, minutes: minutes, seconds: seconds) else {
            return sortedHours.map { hourText(hour: $0) }
        }
        let sortedSeconds = seconds.isEmpty ? [Int?.none] : seconds.sorted().map { Int?.some($0) }
        var items: [String] = []
        for hour in sortedHours {
            for minute in minutes.sorted() {
                for second in sortedSeconds {
                    items.append(timeText(hour: hour, minute: minute, second: second))
                }
            }
        }
        return items
    }
}

/// Returns the positive values in ascending order,
/// followed by the negative values from the end, starting at -1.
///
/// For example, `[-1, 15, -2, 1]` becomes `[1, 15, -1, -2]`.
func sortedSigned(_ values: [Int]) -> [Int] {
    values.filter { $0 > 0 }.sorted() + values.filter { $0 < 0 }.sorted(by: >)
}

/// The sentence templates of one language.
///
/// Foundation provides CLDR names, lists, ordinals, and dates,
/// but it has no public API for CLDR plural categories,
/// and CLDR has no recurrence phrases.
/// So each language supplies its templates in code,
/// and every part that CLDR covers comes from `RecurrenceFormattingContext`.
///
/// A phrasebook is a value whose properties are closures.
/// The built-in languages are ``english``, ``german``, ``spanish``, and ``french``.
/// To change one template,
/// copy a built-in phrasebook and replace that closure:
///
/// ```swift
/// var phrasebook = RecurrenceRulePhrasebook.english
/// phrasebook.frequency = { frequency, interval, context in
///     frequency == .yearly && interval == 1
///         ? "Every year"
///         : RecurrenceRulePhrasebook.english.frequency(frequency, interval, context)
/// }
/// ```
///
/// Each clause closure receives values that the rule has;
/// a description leaves out the clause for a rule part that is empty.
struct RecurrenceRulePhrasebook: Sendable {
    /// Returns the locale for the CLDR data in a description,
    /// given the locale that the caller asks for.
    ///
    /// A built-in phrasebook returns the requested locale
    /// if it has the phrasebook's language,
    /// and a representative locale of that language otherwise,
    /// so a description never mixes the templates of one language
    /// with the names of another.
    /// For example, English returns `en_GB` for `en_GB`, and `en_US` for `pt_BR`.
    var locale: @Sendable (_ requested: Locale) -> Locale

    /// Returns the phrase for the frequency and interval,
    /// which starts the description,
    /// such as "Annually" or "Every 3 hours".
    var frequency: @Sendable (_ frequency: RecurrenceRule.Frequency, _ interval: Int, _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `BYMONTH` months in 1...12, such as "in January and July".
    var monthsClause: @Sendable (_ months: [Int], _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `BYWEEKNO` weeks of the year,
    /// where a negative number counts from the end,
    /// such as "in week 1 and the last week of the year".
    var weeksOfYearClause: @Sendable (_ weeks: [Int], _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `BYYEARDAY` days of the year,
    /// where a negative number counts from the end,
    /// such as "on day 100 and the last day of the year".
    var yearDaysClause: @Sendable (_ days: [Int], _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `BYMONTHDAY` days of the month,
    /// where a negative number counts from the end,
    /// such as "on the 1st and last day of the month".
    var monthDaysClause: @Sendable (_ days: [Int], _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for weekdays without occurrences,
    /// in the order of the locale's week,
    /// such as "on Monday and Wednesday".
    var weekdaysClause: @Sendable (_ days: [RecurrenceRule.Weekday], _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for `BYDAY` entries when at least one has an occurrence,
    /// in the order of the locale's week,
    /// such as "on the first Sunday and the last Friday".
    var ordinalWeekdaysClause: @Sendable (_ rules: [RecurrenceRule.WeekdayRule], _ context: RecurrenceFormattingContext) -> String

    /// Returns the phrase for Monday through Friday, such as "on weekdays".
    var weekdaysSetPhrase: @Sendable (_ context: RecurrenceFormattingContext) -> String

    /// Returns the phrase for Saturday and Sunday, such as "on weekends".
    var weekendsSetPhrase: @Sendable (_ context: RecurrenceFormattingContext) -> String

    /// Returns the phrase for all seven weekdays, such as "every day".
    var everyDayPhrase: @Sendable (_ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the month and day of a start date,
    /// which a yearly rule that selects no day implies,
    /// such as "on July 15".
    var monthDayDateClause: @Sendable (_ date: Date, _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `BYSETPOS` positions,
    /// where a negative number counts from the end,
    /// such as "limited to the first and last occurrence".
    var setPositionsClause: @Sendable (_ positions: [Int], _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `BYHOUR` hours,
    /// which also names the minutes and seconds
    /// if ``RecurrenceFormattingContext/clockTimesIncludeMinutes(hours:minutes:seconds:)`` is true,
    /// such as "at 9 AM and 5 PM" or "at 9:30 AM".
    var hoursClause: @Sendable (_ hours: [Int], _ minutes: [Int], _ seconds: [Int], _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `BYMINUTE` minutes
    /// when the hours clause doesn't name them,
    /// such as "at minutes 0 and 30".
    var minutesClause: @Sendable (_ minutes: [Int], _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `BYSECOND` seconds
    /// when the hours clause doesn't name them,
    /// such as "at second 15".
    var secondsClause: @Sendable (_ seconds: [Int], _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `COUNT` of occurrences,
    /// which follows a comma,
    /// such as "once" or "5 times".
    var countClause: @Sendable (_ count: Int, _ context: RecurrenceFormattingContext) -> String

    /// Returns the clause for the `UNTIL` date,
    /// which follows a comma,
    /// such as "until December 31, 2026".
    var untilClause: @Sendable (_ date: Date, _ context: RecurrenceFormattingContext) -> String
}

extension RecurrenceRulePhrasebook {
    /// Returns the built-in phrasebook for the language of a locale.
    ///
    /// A language without a built-in phrasebook gets ``english``,
    /// which also uses English names, so a description never mixes languages.
    static func builtIn(for locale: Locale) -> Self {
        switch locale.language.languageCode?.identifier {
        case "de": return .german
        case "es": return .spanish
        case "fr": return .french
        default: return .english
        }
    }

    /// Returns a closure for ``locale``
    /// that keeps a requested locale in the given language
    /// and replaces a locale in another language with a representative one.
    static func matchingLocale(
        language: String,
        representative: Locale
    ) -> @Sendable (_ requested: Locale) -> Locale {
        { requested in
            requested.language.languageCode?.identifier == language ? requested : representative
        }
    }
}
