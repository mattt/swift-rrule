# RRULE

RRULE parses iCalendar recurrence rules and describes them in natural language.
It reads the `RRULE` strings that RFC 5545 defines,
such as `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR`,
and describes them in English, German, Spanish, or French,
such as "Every other week on Monday, Wednesday, and Friday".

Foundation can expand a recurrence with `Calendar.RecurrenceRule`,
but it can't parse an `RRULE` string or describe a rule to a person.
RRULE does both.
It also converts rules to and from `Calendar.RecurrenceRule`,
so that Foundation can list a parsed rule's dates
and RRULE can describe Foundation's rules.

## Requirements

- macOS 13+, iOS 16+, tvOS 16+, watchOS 9+, or visionOS 1+
- Swift 6.1+ (Xcode 16.3+)

Converting a `RecurrenceRule` to a `Calendar.RecurrenceRule` needs
macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, or visionOS 2+.
Converting a `Calendar.RecurrenceRule` to a `RecurrenceRule` needs
macOS 15.2+, iOS 18.2+, tvOS 18.2+, watchOS 11.2+, or visionOS 2.2+.

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/mattt/swift-rrule.git", from: "0.1.0")
```

Then add `.product(name: "RRULE", package: "swift-rrule")` to your target's dependencies.

## Usage

```swift
import RRULE

let rule = try RecurrenceRule.parse("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR")

print(rule.localizedDescription(in: Locale(identifier: "en_US")))
// Every other week on Monday, Wednesday, and Friday

print(rule.formatted(.recurrence(locale: Locale(identifier: "de_DE"))))
// Alle 2 Wochen am Montag, Mittwoch und Freitag

print(rule)
// FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR
```

`RecurrenceRule.parse(_:)` throws a `RecurrenceRule.ParseError`
that says what is wrong with a string,
such as `.unknownRulePart("BYDA")`.
`RecurrenceRule(parsing:)` returns `nil` instead.
Both accept an optional `RRULE:` prefix.
They reject unknown, repeated, and malformed rule parts,
and values outside the ranges that RFC 5545 permits,
so a description never leaves out part of a rule.

A rule's `description` is its RFC 5545 form.
For a description in natural language, use `formatted()`,
`formatted(_:)` with a `RecurrenceRule.FormatStyle`,
or `localizedDescription(in:startingAt:)`.

### Start dates

Some rules take their day from the start date (`DTSTART`) of the event.
For example, `FREQ=MONTHLY` repeats on the day of the month of the start date.
Pass the start date, if you know it, to name that day:

```swift
let monthly = try RecurrenceRule.parse("FREQ=MONTHLY")
let english = Locale(identifier: "en_US")
let start = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 15))!

print(monthly.localizedDescription(in: english))
// Monthly

print(monthly.localizedDescription(in: english, startingAt: start))
// Monthly on the 15th
```

### Dates

To list the dates of a rule,
convert it to a `Calendar.RecurrenceRule`
and call its `recurrences(of:in:)` method:

```swift
if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

    let rule = try RecurrenceRule.parse("FREQ=YEARLY;BYMONTH=11;BYDAY=4TH")
    print(rule.formatted())
    // Annually in November on the fourth Thursday

    if let thanksgiving = Calendar.RecurrenceRule(rule, calendar: calendar) {
        let style = Date.FormatStyle(date: .long, locale: Locale(identifier: "en_US"), timeZone: calendar.timeZone)
        for date in thanksgiving.recurrences(of: start).prefix(3) {
            print(date.formatted(style))
        }
        // November 26, 2026
        // November 25, 2027
        // November 23, 2028
    }
}
```

`Calendar.RecurrenceRule(_:calendar:)` carries every part of the rule.
RFC 5545 starts each week on the `WKST` day, Monday by default,
and counts as week 1 the first week with at least four days in the year,
so the result's calendar has these settings
in place of the `firstWeekday` and `minimumDaysInFirstWeek` of the argument.
It keeps the argument's time zone and locale.
The initializer returns `nil` for a rule that Foundation can't represent,
such as one that repeats every second,
and for a calendar whose months differ from the Gregorian calendar's.

### Foundation's dates

As of the macOS 27 SDK,
Foundation expands some rules differently from RFC 5545:

- A weekday without an occurrence in a monthly or yearly rule,
  such as `BYDAY=TU`, gives only the first such weekday in the month.
  `BYSETPOS` over such weekdays,
  such as `BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1` for the last weekday of the month,
  selects from those days only.
- `BYWEEKNO` with `BYDAY` keeps the day of the month of the start date,
  so `FREQ=YEARLY;BYWEEKNO=20;BYDAY=MO` gives only years
  in which that day is the Monday of week 20.
- For a yearly rule with an ordinal weekday and no `BYMONTH`,
  such as `FREQ=YEARLY;BYDAY=20MO`,
  Foundation searches for about a minute and then traps.

For example, RFC 5545 gives these dates for `FREQ=MONTHLY;INTERVAL=2;BYDAY=TU`
from September 2, 1997:
September 2, 9, 16, 23, and 30, then November 4, 11, 18, and 25.
Foundation gives September 2, 1997, November 4, 1997, and January 6, 1998.

RRULE converts the rule faithfully
and doesn't correct the dates that Foundation gives.

### Foundation recurrence rules

```swift
if #available(macOS 15.2, iOS 18.2, tvOS 18.2, watchOS 11.2, visionOS 2.2, *) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 1  // Sunday

    let foundationRule = Calendar.RecurrenceRule.weekly(
        calendar: calendar,
        interval: 2,
        weekdays: [.every(.monday), .every(.wednesday)]
    )

    print(foundationRule.localizedDescription(in: Locale(identifier: "fr_FR")))
    // Toutes les 2 semaines le lundi et le mercredi

    if let rule = RecurrenceRule(foundationRule) {
        print(rule)
        // FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;WKST=SU
    }
}
```

`RecurrenceRule(_:)` carries every part of the Foundation rule,
including the first weekday of its calendar as the week start.
It returns `nil` for a rule that RFC 5545 can't represent,
such as one with a leap month
or one in a calendar whose months differ from the Gregorian calendar's.
The matching and repeated-time policies have no RFC 5545 counterpart,
so they don't carry over.

### Languages

The language of the locale selects the sentence templates:
English, German, Spanish, or French.
A locale in any other language gets an English description.
The names of weekdays and months, lists, ordinals, numbers, dates, and times
come from the CLDR data in Foundation,
so they match the locale, such as "9 AM" in `en_US` and "09 Uhr" in `de_DE`.
A description never mixes the templates of one language with the names of another.

### Limits

- RRULE doesn't expand rules into dates itself;
  Foundation does, after the conversion in [Dates](#dates),
  with the differences in [Foundation's dates](#foundations-dates).
- Without a start date,
  a rule that takes its day from the start date gets a general description,
  such as "Monthly".
- An `UNTIL` value without a time zone resolves in the current time zone.

## Development

```sh
swift test
swift format lint --strict --recursive .
```

`UsageTests` runs the examples in this file; keep the two in sync.

## License

MIT. See [LICENSE.md](LICENSE.md).
