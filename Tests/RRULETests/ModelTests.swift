import Foundation
import Testing

@testable import RRULE

@Suite("Model Invariants")
struct ModelInvariantTests {
    @Test("Codable round-trip preserves the rule")
    func codableRoundTrip() throws {
        let rule = try #require(RecurrenceRule(parsing: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=4"))
        let data = try JSONEncoder().encode(rule)
        #expect(try JSONDecoder().decode(RecurrenceRule.self, from: data) == rule)
    }

    @Test("Decoding rejects out-of-range values")
    func decodingRejectsInvalid() {
        let json =
            #"{"frequency":"DAILY","interval":-3,"bySeconds":[],"byMinutes":[],"byHours":[],"byWeekdays":[],"byMonthDays":[],"byYearDays":[],"byWeeks":[],"byMonths":[],"bySetPositions":[],"weekStart":"MO"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RecurrenceRule.self, from: Data(json.utf8))
        }
    }

    @Test("FormatStyle equality and coding reflect all stored state")
    func formatStyleState() throws {
        let first = RecurrenceRule.FormatStyle(locale: Locale(identifier: "de_DE"), startDate: Date(timeIntervalSince1970: 0))
        let second = RecurrenceRule.FormatStyle(locale: Locale(identifier: "de_DE"), startDate: Date(timeIntervalSince1970: 0))
        let different = first.locale(Locale(identifier: "fr_FR"))
        #expect(first == second)
        #expect(first != different)
        let data = try JSONEncoder().encode(first)
        #expect(try JSONDecoder().decode(RecurrenceRule.FormatStyle.self, from: data) == first)
    }
}
