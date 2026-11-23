import Foundation

extension RecurrenceRule {
    /// A format style that describes a recurrence rule in natural language.
    ///
    /// The language of ``locale`` selects a built-in localizer:
    /// English, German, Spanish, or French,
    /// with English for any other language.
    public struct FormatStyle: Foundation.FormatStyle, Sendable {
        public typealias FormatInput = RecurrenceRule
        public typealias FormatOutput = String

        /// The locale for the language
        /// and for the names, lists, numbers, and dates in the description.
        public var locale: Locale

        /// The start date of the first event, if you know it.
        ///
        /// For a weekly, monthly, or yearly rule that selects no day,
        /// the description names the day that the start date implies.
        public var startDate: Date?

        /// Creates a format style.
        ///
        /// - Parameters:
        ///   - locale: The locale for the language
        ///     and for the names, lists, numbers, and dates in the description.
        ///   - startDate: The start date of the first event, if you know it.
        public init(locale: Locale = .current, startDate: Date? = nil) {
            self.locale = locale
            self.startDate = startDate
        }

        /// Returns a copy of the style with the given locale.
        ///
        /// - Parameter locale: The locale for the language
        ///   and for the names, lists, numbers, and dates in the description.
        /// - Returns: A copy of the style that uses the given locale.
        public func locale(_ locale: Locale) -> Self {
            var copy = self
            copy.locale = locale
            return copy
        }

        /// Returns a copy of the style with the given start date.
        ///
        /// - Parameter startDate: The start date of the first event, if you know it.
        /// - Returns: A copy of the style that uses the given start date.
        public func startDate(_ startDate: Date?) -> Self {
            var copy = self
            copy.startDate = startDate
            return copy
        }

        public func format(_ value: RecurrenceRule) -> String {
            RecurrenceRulePhrasebook.builtIn(for: locale).format(value, locale: locale, startDate: startDate)
        }
    }
}

extension RecurrenceRule.FormatStyle: Equatable, Hashable, Codable {}

// MARK: - FormatStyle Static Factory Extensions

extension FormatStyle where Self == RecurrenceRule.FormatStyle {
    /// A format style that describes a recurrence rule in natural language
    /// for the current locale.
    public static var recurrence: RecurrenceRule.FormatStyle {
        RecurrenceRule.FormatStyle()
    }

    /// Returns a format style that describes a recurrence rule in the given locale.
    ///
    /// - Parameter locale: The locale for the language
    ///   and for the names, lists, numbers, and dates in the description.
    /// - Returns: A format style that uses the given locale.
    public static func recurrence(locale: Locale) -> RecurrenceRule.FormatStyle {
        RecurrenceRule.FormatStyle(locale: locale)
    }
}
