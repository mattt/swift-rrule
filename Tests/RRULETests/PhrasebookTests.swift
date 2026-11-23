import Foundation
import Testing

@testable import RRULE

@Suite("Phrasebooks")
struct PhrasebookTests {
    /// A rule whose description has a frequency, a month, an ordinal weekday, and a count,
    /// so the descriptions of the built-in languages all differ.
    let rule = RecurrenceRule(parsing: "FREQ=YEARLY;BYMONTH=7;BYDAY=1SU;COUNT=3")!

    @Test(
        "Each language gets its built-in phrasebook",
        arguments: [
            ("en_US", "Annually in July on the first Sunday, 3 times"),
            ("de_DE", "Jährlich im Juli am ersten Sonntag, 3-mal"),
            ("es_ES", "Anualmente en julio el primer domingo, 3 veces"),
            ("fr_FR", "Tous les ans en juillet le premier dimanche, 3 fois"),
        ]
    )
    func builtInSelection(localeIdentifier: String, expected: String) {
        let locale = Locale(identifier: localeIdentifier)
        let phrasebook = RecurrenceRulePhrasebook.builtIn(for: locale)
        #expect(phrasebook.format(rule, locale: locale, startDate: nil) == expected)
    }

    @Test("The built-in values are the phrasebooks of their languages")
    func builtInValues() {
        let phrasebooks: [(RecurrenceRulePhrasebook, String)] = [
            (.english, "Annually in July on the first Sunday, 3 times"),
            (.german, "Jährlich im Juli am ersten Sonntag, 3-mal"),
            (.spanish, "Anualmente en julio el primer domingo, 3 veces"),
            (.french, "Tous les ans en juillet le premier dimanche, 3 fois"),
        ]
        for (phrasebook, expected) in phrasebooks {
            // The phrasebook replaces a locale in another language with one in its own.
            #expect(phrasebook.format(rule, locale: Locale(identifier: "ja_JP"), startDate: nil) == expected)
        }
    }

    @Test("Other languages get the English phrasebook", arguments: ["pt_BR", "ja_JP", "it_IT"])
    func englishFallback(localeIdentifier: String) {
        let locale = Locale(identifier: localeIdentifier)
        let phrasebook = RecurrenceRulePhrasebook.builtIn(for: locale)
        #expect(phrasebook.format(rule, locale: locale, startDate: nil) == "Annually in July on the first Sunday, 3 times")
    }

    @Test("A copy with one replaced closure changes only that part")
    func replacedClosure() {
        var phrasebook = RecurrenceRulePhrasebook.english
        phrasebook.frequency = { frequency, interval, context in
            if frequency == .yearly && interval == 1 { return "Every year" }
            return RecurrenceRulePhrasebook.english.frequency(frequency, interval, context)
        }
        let locale = Locale(identifier: "en_US")

        #expect(phrasebook.format(rule, locale: locale, startDate: nil) == "Every year in July on the first Sunday, 3 times")
        #expect(
            RecurrenceRulePhrasebook.english.format(rule, locale: locale, startDate: nil)
                == "Annually in July on the first Sunday, 3 times"
        )

        let monthly = RecurrenceRule(parsing: "FREQ=MONTHLY;BYMONTH=7;BYDAY=1SU;COUNT=3")!
        #expect(phrasebook.format(monthly, locale: locale, startDate: nil) == "Monthly in July on the first Sunday, 3 times")
    }
}
