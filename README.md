# RRULE

RRULE parses iCalendar recurrence rules (RFC 5545), lists their dates,
and describes them in English, German, Spanish, or French.
Foundation's `Calendar.RecurrenceRule` lists dates
but can't parse `RRULE` strings or describe rules in words.

## Requirements

- macOS 13+, iOS 16+, tvOS 16+, watchOS 9+, or visionOS 1+
- Swift 6.1+ (Xcode 16.3+)

Conversion to `Calendar.RecurrenceRule` requires
macOS 15+, iOS 18+, tvOS 18+, watchOS 11+, or visionOS 2+.
Conversion to `RecurrenceRule` requires
macOS 15.2+, iOS 18.2+, tvOS 18.2+, watchOS 11.2+, or visionOS 2.2+.

## Installation

Add the package to your `Package.swift`.

```swift
.package(url: "https://github.com/mattt/swift-rrule.git", from: "0.1.0")
```

Add `.product(name: "RRULE", package: "swift-rrule")` to your target's dependencies.

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

`RecurrenceRule.parse(_:)` throws a `RecurrenceRule.ParseError`,
such as `.unknownRulePart("BYDA")`.
`RecurrenceRule(parsing:)` returns `nil` instead.
The `RRULE:` prefix is optional.
Both parsers reject unknown, repeated, or malformed parts and out-of-range values,
so a description covers every part of a rule except the week start (`WKST`).

`description` returns the RFC 5545 string.
For a localized description, use `formatted()`,
`formatted(_:)` with a `RecurrenceRule.FormatStyle`,
or `localizedDescription(in:startingAt:)`.

The locale selects the templates and names, with English as the fallback.
The names of weekdays and months, lists, numbers, dates, and times
come from the CLDR data in Foundation,
as in "9 AM" (`en_US`) and "09 Uhr" (`de_DE`).

### Start dates

Pass the event's start date (`DTSTART`) to name an implied day,
such as the day of the month for `FREQ=MONTHLY`.

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

Pass the first event's start date to `recurrences(of:in:calendar:)`.
The lazy sequence gives the dates that RFC 5545 defines,
including its examples in section 3.8.5.3.
For open-ended rules, take a prefix.

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

let rule = try RecurrenceRule.parse("FREQ=YEARLY;BYMONTH=11;BYDAY=4TH")
print(rule.formatted())
// Annually in November on the fourth Thursday

let style = Date.FormatStyle(date: .long, locale: Locale(identifier: "en_US"), timeZone: calendar.timeZone)
for date in rule.recurrences(of: start, calendar: calendar).prefix(3) {
    print(date.formatted(style))
}
// November 26, 2026
// November 25, 2027
// November 23, 2028
```

- `DTSTART` supplies missing parts, such as the time of day.
  The sequence begins with the first match on or after `DTSTART`.
- Dates use the calendar's time zone.
  Skipped times move forward by the gap.
  When clocks advance at 2 AM, 2:30 AM becomes 3:30 AM.
  Repeated times resolve to the first occurrence.
- The sequence skips nonexistent dates, such as February 30.
- A rule that can never match, such as `FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30`,
  ends its sequence after one full cycle of the Gregorian calendar,
  400 years for most rules.

### Foundation recurrence rules

`Calendar.RecurrenceRule(_:calendar:)` preserves every rule part
along with the calendar's time zone and locale.

```swift
if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) {
    let foundationRule = Calendar.RecurrenceRule(rule, calendar: calendar)
    print(foundationRule?.weekdays == [.nth(4, .thursday)])
    // true
}
```

The initializer sets `firstWeekday` to `WKST` (Monday by default)
and `minimumDaysInFirstWeek` to four.
Under RFC 5545, week 1 is the first with at least four days in the year.
Conversion returns `nil` for unsupported rules, including those that repeat every second.

`RecurrenceRule(_:)` carries every part of the Foundation rule,
including the first weekday of its calendar as the week start.
Matching and repeated-time policies don't carry over
because RFC 5545 has no equivalent.
You can also describe a Foundation rule directly.

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

`RecurrenceRule(_:)` returns `nil` for rules RFC 5545 can't represent,
such as those with leap months.
Both initializers return `nil` for calendars
whose months differ from the Gregorian calendar's.

## Limits

As of the macOS 27 SDK, Foundation's `recurrences(of:in:)`
returns different dates than RFC 5545 specifies for some common rules,
including monthly and yearly rules that specify a weekday without an ordinal.
For `FREQ=MONTHLY;INTERVAL=2;BYDAY=TU` from September 2, 1997,
Foundation gives only the first Tuesday of every other month
(September 2, November 4, and January 6).
Dates also differ for `BYSETPOS` over those weekdays and for `BYWEEKNO`.
For `FREQ=YEARLY;BYDAY=20MO`,
Foundation searches for 30 seconds or more and then traps.
Use RRULE's `recurrences(of:in:calendar:)` to list dates.

`UNTIL` uses the current time zone when none is specified.

## Development

```sh
swift test
swift format lint --strict --recursive .
```

`UsageTests` runs the README examples.

## License

MIT.
See [LICENSE.md](LICENSE.md).
