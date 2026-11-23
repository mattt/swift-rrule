# ``RRULE``

Parse iCalendar recurrence rules and describe them in natural language.

## Overview

RRULE reads the recurrence rule strings that RFC 5545 defines,
such as `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR`,
and describes them in English, German, Spanish, or French,
such as "Every other week on Monday, Wednesday, and Friday".

```swift
import RRULE

let rule = try RecurrenceRule.parse("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR")
print(rule.localizedDescription(in: Locale(identifier: "en_US")))
// Every other week on Monday, Wednesday, and Friday
```

The parser rejects unknown, repeated, and malformed rule parts,
and values outside the ranges that RFC 5545 permits,
so a description never leaves out part of a rule.
Every value of a rule contributes to its description.

The language of the locale selects the sentence templates.
The names of weekdays and months, lists, ordinals, numbers, dates, and times
come from the CLDR data in Foundation.
A locale in a language without templates gets an English description,
so a description never mixes languages.

Some rules take their day from the start date (`DTSTART`) of the event.
Pass the start date to ``RecurrenceRule/localizedDescription(in:startingAt:)``
to name that day, as in "Monthly on the 15th".

To list the dates of a rule,
convert it to Foundation's `Calendar.RecurrenceRule`
with `Calendar.RecurrenceRule.init(_:calendar:)`,
and call `recurrences(of:in:)`:

```swift
let rule = try RecurrenceRule.parse("FREQ=YEARLY;BYMONTH=11;BYDAY=4TH")
if let thanksgiving = Calendar.RecurrenceRule(rule, calendar: calendar) {
    for date in thanksgiving.recurrences(of: start).prefix(3) {
        print(date.formatted(date: .long, time: .omitted))
    }
}
```

As of the macOS 27 SDK, Foundation expands some rules differently from RFC 5545,
such as a weekday without an occurrence in a monthly rule,
for which it gives only the first such weekday in the month.
RRULE converts the rule faithfully and doesn't correct the dates.

RRULE also converts a `Calendar.RecurrenceRule` to a ``RecurrenceRule``
with ``RecurrenceRule/init(_:)``, and describes it.

## Topics

### Recurrence rules

- ``RecurrenceRule``
- ``RecurrenceRule/ParseError``

### Descriptions

- ``RecurrenceRule/FormatStyle``
