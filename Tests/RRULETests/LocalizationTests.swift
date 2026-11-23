import Foundation
import Testing

@testable import RRULE

@Suite("Localization")
struct LocalizationTests {
    @Test("German descriptions")
    func german() throws {
        #expect(try localized("FREQ=HOURLY;INTERVAL=3", "de_DE") == "Alle 3 Stunden")
        #expect(try localized("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE", "de_DE") == "Alle 2 Wochen am Montag und Mittwoch")
        #expect(try localized("FREQ=MONTHLY;BYDAY=1SU", "de_DE") == "Monatlich am ersten Sonntag")
        #expect(try localized("FREQ=MONTHLY;BYMONTHDAY=15", "de_DE") == "Monatlich am 15.")
        #expect(try localized("FREQ=YEARLY;BYMONTH=7", "de_DE") == "Jährlich im Juli")
        #expect(try localized("FREQ=DAILY;COUNT=5", "de_DE") == "Täglich, 5-mal")
        #expect(try localized("FREQ=DAILY;BYHOUR=9,17", "de_DE") == "Täglich um 09 Uhr und 17 Uhr")
    }

    @Test("Spanish descriptions")
    func spanish() throws {
        #expect(try localized("FREQ=HOURLY;INTERVAL=3", "es_ES") == "Cada 3 horas")
        #expect(try localized("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE", "es_ES") == "Cada 2 semanas el lunes y el miércoles")
        #expect(try localized("FREQ=MONTHLY;BYDAY=1SU", "es_ES") == "Mensualmente el primer domingo")
        #expect(try localized("FREQ=YEARLY;BYMONTH=7", "es_ES") == "Anualmente en julio")
        #expect(try localized("FREQ=DAILY;COUNT=5", "es_ES") == "Diariamente, 5 veces")
    }

    @Test("French descriptions")
    func french() throws {
        #expect(try localized("FREQ=HOURLY;INTERVAL=3", "fr_FR") == "Toutes les 3 heures")
        #expect(try localized("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE", "fr_FR") == "Toutes les 2 semaines le lundi et le mercredi")
        #expect(try localized("FREQ=MONTHLY;BYDAY=1SU", "fr_FR") == "Tous les mois le premier dimanche")
        #expect(try localized("FREQ=YEARLY;BYMONTH=7", "fr_FR") == "Tous les ans en juillet")
        #expect(try localized("FREQ=DAILY;COUNT=5", "fr_FR") == "Tous les jours, 5 fois")
    }

    @Test("Unsupported languages fall back to whole English descriptions")
    func fallback() throws {
        #expect(try localized("FREQ=YEARLY;BYMONTH=7;BYDAY=1SU", "pt_BR") == "Annually in July on the first Sunday")
    }

    @Test("Regional locales select their language localizer")
    func regionalSelection() throws {
        #expect(try localized("FREQ=DAILY", "de_AT") == "Täglich")
        #expect(try localized("FREQ=DAILY", "es_MX") == "Diariamente")
        #expect(try localized("FREQ=DAILY", "fr_CA") == "Tous les jours")
        #expect(try localized("FREQ=DAILY", "en_GB") == "Daily")
    }

    @Test("Built-in phrasebooks used directly")
    func builtinPhrasebooks() throws {
        let rule = try #require(RecurrenceRule(parsing: "FREQ=DAILY"))
        #expect(RecurrenceRulePhrasebook.english.format(rule, locale: Locale(identifier: "en_US"), startDate: nil) == "Daily")
        #expect(RecurrenceRulePhrasebook.german.format(rule, locale: Locale(identifier: "de_DE"), startDate: nil) == "Täglich")
    }
}
