import Foundation
import Testing

@testable import RRULE

@Suite("Parser")
struct ParserTests {
    @Test(
        "Valid rules round-trip through their canonical serialization",
        arguments: [
            "FREQ=HOURLY;INTERVAL=3",
            "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;WKST=SU",
            "FREQ=MONTHLY;BYDAY=1SU;BYSETPOS=1",
            "FREQ=YEARLY;BYMONTH=7;BYWEEKNO=20;BYDAY=MO",
            "FREQ=DAILY;BYHOUR=9,17;BYMINUTE=0,30;COUNT=10",
            "FREQ=DAILY;UNTIL=20261231T000000Z",
        ]
    )
    func roundTrip(_ string: String) throws {
        let rule = try #require(RecurrenceRule(parsing: string))
        #expect(RecurrenceRule(parsing: rule.description) == rule)
    }

    @Test("Optional RRULE prefix is accepted")
    func rrulePrefix() {
        #expect(RecurrenceRule(parsing: "RRULE:FREQ=DAILY") != nil)
        #expect(RecurrenceRule(parsing: "rrule:freq=daily") != nil)
    }

    @Test(
        "Invalid rules are rejected",
        arguments: [
            "",
            "INVALID_STRING",
            "FREQ",
            "INTERVAL=2",
            "FREQ=FORTNIGHTLY",
            "FREQ=DAILY;",
            "FREQ=DAILY;BYFOO=BAR",
            "FREQ=DAILY;BYDA=MO",
            "FREQ=DAILY;FREQ=WEEKLY",
            "FREQ=DAILY;INTERVAL=0",
            "FREQ=DAILY;INTERVAL=two",
            "FREQ=DAILY;COUNT=0",
            "FREQ=DAILY;COUNT=5;UNTIL=20261231",
            "FREQ=DAILY;UNTIL=not-a-date",
            "FREQ=YEARLY;BYMONTH=13",
            "FREQ=DAILY;BYHOUR=24",
            "FREQ=DAILY;BYMINUTE=60",
            "FREQ=MONTHLY;BYMONTHDAY=0",
            "FREQ=MONTHLY;BYMONTHDAY=32",
            "FREQ=WEEKLY;BYDAY=XX",
            "FREQ=MONTHLY;BYDAY=0SU",
            "FREQ=MONTHLY;BYDAY=99SU",
            "FREQ=DAILY;BYSETPOS=1",
            "FREQ=DAILY;WKST=XX",
        ]
    )
    func invalidRules(_ string: String) {
        #expect(RecurrenceRule(parsing: string) == nil)
    }

    @Test("Throwing parse reports specific errors")
    func specificErrors() {
        #expect(throws: RecurrenceRule.ParseError.unknownRulePart("BYDA")) {
            try RecurrenceRule.parse("FREQ=DAILY;BYDA=MO")
        }
        #expect(throws: RecurrenceRule.ParseError.duplicateRulePart("FREQ")) {
            try RecurrenceRule.parse("FREQ=DAILY;FREQ=WEEKLY")
        }
        #expect(throws: RecurrenceRule.ParseError.missingFrequency) {
            try RecurrenceRule.parse("INTERVAL=2")
        }
        #expect(throws: RecurrenceRule.ParseError.invalidFrequency("FORTNIGHTLY")) {
            try RecurrenceRule.parse("FREQ=FORTNIGHTLY")
        }
    }
}
