import Foundation
import Testing

@testable import RRULE

/// Replaces the no-break and narrow no-break spaces
/// that CLDR patterns put around AM and PM and unit markers,
/// so expectations can use plain spaces.
func normalized(_ string: String) -> String {
    string
        .replacingOccurrences(of: "\u{202F}", with: " ")
        .replacingOccurrences(of: "\u{00A0}", with: " ")
}

/// Parses a rule and describes it in US English.
func english(_ string: String) throws -> String {
    let rule = try #require(RecurrenceRule(parsing: string))
    return normalized(rule.localizedDescription(in: Locale(identifier: "en_US")))
}

/// Parses a rule and describes it in the locale with the given identifier.
func localized(_ string: String, _ localeIdentifier: String) throws -> String {
    let rule = try #require(RecurrenceRule(parsing: string))
    return normalized(rule.localizedDescription(in: Locale(identifier: localeIdentifier)))
}
