# ``RRULE``

Parse iCalendar recurrence rules, list their dates, and describe them in natural language.

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
call ``RecurrenceRule/recurrences(of:in:calendar:)``
with the start date of the first event.
The method gives the dates that RFC 5545 defines,
in a lazy sequence:

```swift
let rule = try RecurrenceRule.parse("FREQ=YEARLY;BYMONTH=11;BYDAY=4TH")
for date in rule.recurrences(of: start, calendar: calendar).prefix(3) {
    print(date.formatted(date: .long, time: .omitted))
}
```

To use a rule with the Foundation APIs that take a `Calendar.RecurrenceRule`,
convert it with `Calendar.RecurrenceRule.init(_:calendar:)`.
As of the macOS 27 SDK, Foundation's own expansion differs from RFC 5545
for some rules, such as a weekday without an occurrence in a monthly rule,
so list dates with ``RecurrenceRule/recurrences(of:in:calendar:)``.

RRULE also converts a `Calendar.RecurrenceRule` to a ``RecurrenceRule``
with ``RecurrenceRule/init(_:)``, and describes it.

## Topics

### Recurrence rules

- ``RecurrenceRule``
- ``RecurrenceRule/ParseError``

### Dates

- ``RecurrenceRule/recurrences(of:in:calendar:)``

### Descriptions

- ``RecurrenceRule/FormatStyle``
