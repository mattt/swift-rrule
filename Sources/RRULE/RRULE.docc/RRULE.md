# ``RRULE``

Parse iCalendar recurrence rules (RFC 5545), list their dates,
and describe them in natural language.

## Overview

```swift
import RRULE

let rule = try RecurrenceRule.parse("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR")
print(rule.localizedDescription(in: Locale(identifier: "en_US")))
// Every other week on Monday, Wednesday, and Friday
```

The parser rejects unknown, repeated, or malformed parts and out-of-range values.
Every value of a rule except the week start (`WKST`) contributes to its description.

The locale selects English, German, Spanish, or French sentence templates.
Other languages fall back to English throughout.
The names of weekdays and months, lists, numbers, dates, and times
come from the CLDR data in Foundation.

Some rules take their day from the event's start date (`DTSTART`).
Pass it to ``RecurrenceRule/localizedDescription(in:startingAt:)``
to name the day, as in "Monthly on the 15th".

Pass the first event's start date to ``RecurrenceRule/recurrences(of:in:calendar:)``
for a lazy sequence of RFC 5545 dates.

```swift
let rule = try RecurrenceRule.parse("FREQ=YEARLY;BYMONTH=11;BYDAY=4TH")
for date in rule.recurrences(of: start, calendar: calendar).prefix(3) {
    print(date.formatted(date: .long, time: .omitted))
}
```

For Foundation APIs, convert to `Calendar.RecurrenceRule`
with `Calendar.RecurrenceRule.init(_:calendar:)`.
``RecurrenceRule/init(_:)`` converts Foundation rules to ``RecurrenceRule``
so you can describe them.

As of the macOS 27 SDK, Foundation's dates differ from RFC 5545
for some rules, including monthly rules with an unnumbered weekday.
Use ``RecurrenceRule/recurrences(of:in:calendar:)`` to list dates.

## Topics

### Recurrence rules

- ``RecurrenceRule``
- ``RecurrenceRule/ParseError``

### Dates

- ``RecurrenceRule/recurrences(of:in:calendar:)``

### Descriptions

- ``RecurrenceRule/FormatStyle``
