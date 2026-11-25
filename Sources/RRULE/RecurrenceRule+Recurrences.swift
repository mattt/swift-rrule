import Foundation

extension RecurrenceRule {
    /// Returns the dates of the rule, as RFC 5545 defines them.
    ///
    /// The sequence is lazy:
    /// it computes each date when you ask for it,
    /// and keeps in memory only the dates of one frequency period
    /// (one day, for an hourly, minutely, or secondly rule).
    /// The sequence of a rule without `COUNT` or `UNTIL` has no end,
    /// so take a prefix or pass a range.
    ///
    /// ```swift
    /// let rule = try RecurrenceRule.parse("FREQ=YEARLY;BYMONTH=11;BYDAY=4TH")
    /// for date in rule.recurrences(of: start).prefix(3) {
    ///     print(date.formatted(date: .long, time: .omitted))
    /// }
    /// ```
    ///
    /// The start date (`DTSTART`) supplies the parts of each date
    /// that the rule doesn't select,
    /// such as the time of day of a daily rule.
    /// The sequence contains the start date if the rule matches it,
    /// and never contains a date before it.
    /// RFC 5545 leaves the result undefined for a start date that the rule doesn't match;
    /// in that case the sequence begins with the first date after the start date
    /// that the rule matches, and `COUNT` counts from that date.
    ///
    /// The rule's dates are local times in the calendar's time zone.
    /// As RFC 5545, section 3.3.5 states,
    /// a local time that occurs twice when clocks go back
    /// refers to its first occurrence,
    /// and a local time that doesn't exist when clocks go forward
    /// uses the offset from UTC before the change,
    /// so 2:30 AM on the day that clocks go forward at 2 AM becomes 3:30 AM.
    /// If that makes two dates equal, the sequence contains the date once.
    /// A date that doesn't exist, such as February 30, isn't part of the sequence.
    /// `UNTIL` includes a date equal to it,
    /// and the second 60 in `BYSECOND` means the second 59.
    ///
    /// The method uses only the time zone of `calendar`.
    /// RFC 5545 defines rules on the Gregorian calendar
    /// and defines weeks by `WKST` and the rule that week 1
    /// is the first week with at least four days in the year,
    /// so the calendar's identifier, `firstWeekday`, and `minimumDaysInFirstWeek`
    /// don't change the dates.
    ///
    /// RFC 5545 doesn't permit some rule parts with some frequencies,
    /// such as `BYMONTHDAY` in a weekly rule.
    /// Such a part limits the dates that the rule selects.
    /// A `BYDAY` entry with an occurrence, such as `1MO`,
    /// counts within the month or year only in a monthly or yearly rule;
    /// in a rule with another frequency, it selects every such weekday.
    ///
    /// The Gregorian calendar repeats every 400 years,
    /// so a rule that produces no date in one full cycle of its pattern
    /// can't produce another.
    /// The sequence ends after one such cycle without a date:
    /// 400 years for a rule with an interval of 1,
    /// and up to 400 times the interval for other rules.
    /// For example, `FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30` has no dates,
    /// and its sequence ends after it examines 400 years.
    ///
    /// - Parameters:
    ///   - start: The start date of the first event (`DTSTART`).
    ///   - range: The range of dates to return, or `nil` for every date.
    ///     `COUNT` still counts the dates before the range.
    ///   - calendar: The calendar whose time zone gives the local times of the dates.
    /// - Returns: The dates of the rule, in increasing order.
    public func recurrences(
        of start: Date,
        in range: Range<Date>? = nil,
        calendar: Calendar = .current
    ) -> some Sequence<Date> & Sendable {
        Recurrences(rule: self, start: start, range: range, timeZone: calendar.timeZone)
    }
}

/// The dates of a recurrence rule.
struct Recurrences: Sequence, Sendable {
    let rule: RecurrenceRule
    let start: Date
    let range: Range<Date>?
    let timeZone: TimeZone

    func makeIterator() -> Iterator {
        Iterator(self)
    }
}

// MARK: - Day filter

/// The rule parts that select days, as a test of a single day.
struct DayFilter {
    let months: [Bool]
    let hasMonths: Bool
    let weekNumbers: Set<Int>
    let yearDays: Set<Int>
    let monthDays: Set<Int>
    let weekdays: [Bool]
    let hasWeekdays: Bool
    /// Weekdays with an occurrence, which count within the month or the year.
    let ordinals: [(occurrence: Int, weekday: Int)]
    /// Whether an occurrence counts within the month, rather than the year.
    let ordinalsCountWithinMonth: Bool
    let weekStart: Int
    /// The weekday that a yearly rule with only `BYWEEKNO` takes from the start date.
    let defaultWeekday: Int?

    /// Whether the rule has a part that selects days,
    /// so that the start date doesn't supply the day.
    let selectsDays: Bool

    init(rule: RecurrenceRule, startWeekday: Int) {
        var months = [Bool](repeating: false, count: 13)
        for month in rule.byMonths { months[month] = true }
        self.months = months
        hasMonths = !rule.byMonths.isEmpty
        weekNumbers = Set(rule.byWeeks)
        yearDays = Set(rule.byYearDays)
        monthDays = Set(rule.byMonthDays)

        let countsOccurrences = rule.frequency == .monthly || rule.frequency == .yearly
        var weekdays = [Bool](repeating: false, count: 7)
        var ordinals: [(occurrence: Int, weekday: Int)] = []
        for entry in rule.byWeekdays {
            let weekday = entry.weekday.calendarWeekday - 1
            if let occurrence = entry.occurrence, countsOccurrences {
                ordinals.append((occurrence, weekday))
            } else {
                weekdays[weekday] = true
            }
        }
        self.weekdays = weekdays
        hasWeekdays = weekdays.contains(true)
        self.ordinals = ordinals
        ordinalsCountWithinMonth = rule.frequency == .monthly || !rule.byMonths.isEmpty
        weekStart = rule.weekStart.calendarWeekday - 1

        selectsDays =
            !rule.byWeeks.isEmpty || !rule.byYearDays.isEmpty
            || !rule.byMonthDays.isEmpty || !rule.byWeekdays.isEmpty
        // RFC 5545, section 3.3.10: "Information, not contained in the rule,
        // necessary to determine the various recurrence instance start time and dates
        // are derived from the Start Time ("DTSTART") component attribute."
        // BYWEEKNO selects weeks, so the start date supplies the day of the week.
        let onlyWeeks = !rule.byWeeks.isEmpty && rule.byYearDays.isEmpty && rule.byMonthDays.isEmpty && rule.byWeekdays.isEmpty
        defaultWeekday = rule.frequency == .yearly && onlyWeeks ? startWeekday : nil
    }

    /// Returns whether the day passes every part that selects or limits days.
    func matches(day: Int, year: Int, month: Int, dayOfMonth: Int) -> Bool {
        if hasMonths && !months[month] {
            return false
        }
        if !weekNumbers.isEmpty && !matchesWeekNumber(day: day, year: year) {
            return false
        }
        if !yearDays.isEmpty {
            let dayOfYear = day - Gregorian.dayNumber(year: year, month: 1, day: 1) + 1
            let fromEnd = dayOfYear - Gregorian.daysInYear(year) - 1
            if !yearDays.contains(dayOfYear) && !yearDays.contains(fromEnd) {
                return false
            }
        }
        if !monthDays.isEmpty {
            let fromEnd = dayOfMonth - Gregorian.daysInMonth(month, year: year) - 1
            if !monthDays.contains(dayOfMonth) && !monthDays.contains(fromEnd) {
                return false
            }
        }
        let weekday = Gregorian.weekday(dayNumber: day)
        if let defaultWeekday, weekday != defaultWeekday {
            return false
        }
        if hasWeekdays || !ordinals.isEmpty {
            return weekdays[weekday] || matchesOrdinal(day: day, weekday: weekday, year: year, month: month)
        }
        return true
    }

    private func matchesOrdinal(day: Int, weekday: Int, year: Int, month: Int) -> Bool {
        guard !ordinals.isEmpty else { return false }
        let first: Int
        let last: Int
        if ordinalsCountWithinMonth {
            first = Gregorian.dayNumber(year: year, month: month, day: 1)
            last = first + Gregorian.daysInMonth(month, year: year) - 1
        } else {
            first = Gregorian.dayNumber(year: year, month: 1, day: 1)
            last = first + Gregorian.daysInYear(year) - 1
        }
        let fromStart = (day - first) / 7 + 1
        let fromEnd = -((last - day) / 7 + 1)
        return ordinals.contains { $0.weekday == weekday && ($0.occurrence == fromStart || $0.occurrence == fromEnd) }
    }

    /// Returns whether the day's week, numbered from `WKST`, is in `BYWEEKNO`.
    ///
    /// Week 1 is the first week with at least four days in the year,
    /// so a day early in January can be in the last week of the previous year,
    /// and a day late in December can be in week 1 of the next year.
    private func matchesWeekNumber(day: Int, year: Int) -> Bool {
        var weekYear = year
        if day < firstDayOfWeekOne(year) {
            weekYear = year - 1
        } else if day >= firstDayOfWeekOne(year + 1) {
            weekYear = year + 1
        }
        let firstDay = firstDayOfWeekOne(weekYear)
        let week = (day - firstDay) / 7 + 1
        let weekCount = (firstDayOfWeekOne(weekYear + 1) - firstDay) / 7
        return weekNumbers.contains(week) || weekNumbers.contains(week - weekCount - 1)
    }

    private func firstDayOfWeekOne(_ year: Int) -> Int {
        let januaryFirst = Gregorian.dayNumber(year: year, month: 1, day: 1)
        let daysAfterWeekStart = floorModulo(Gregorian.weekday(dayNumber: januaryFirst) - weekStart, 7)
        return daysAfterWeekStart <= 3 ? januaryFirst - daysAfterWeekStart : januaryFirst - daysAfterWeekStart + 7
    }
}

// MARK: - Iterator

extension Recurrences {
    struct Iterator: IteratorProtocol {
        private static let secondsPerDay: Int64 = 86_400

        private let rule: RecurrenceRule
        private let start: Date
        private let range: Range<Date>?
        private let timeZone: TimeZone
        private let filter: DayFilter

        /// The start date's local time, in seconds since 1970-01-01T00:00 local time.
        private let startWall: Int64
        /// The start date's fraction of a second, which every date keeps.
        private let fraction: TimeInterval
        private let startDay: Int
        private let startYear: Int
        private let startMonth: Int
        private let startDayOfMonth: Int
        private let startWeekday: Int
        private let startHour: Int
        private let startMinute: Int
        private let startSecond: Int

        private let hours: [Int]
        private let minutes: [Int]
        private let seconds: [Int]

        // State
        private var hasStarted = false
        private var isGenerating = true
        private var isFinished = false
        /// The next period to generate, for a daily or longer rule.
        private var period = 0
        /// The next day to examine, for an hourly, minutely, or secondly rule.
        private var day = 0
        /// The period or day that produced the last date, or the first one examined.
        private var lastProductive = 0
        /// The number of periods or days without a date after which the rule can't produce one.
        private var searchLimit = Int.max
        /// The local time after which no date can be in the sequence.
        private var endWall = Int64.max
        private var buffer: [Int64] = []
        private var bufferIndex = 0
        /// Dates of nonexistent local times, which can fall after later local times.
        private var pending: [Date] = []
        private var count = 0
        private var lastDate: Date?

        // Daily and longer
        private var timesOfDay: [Int64] = []
        // Hourly, minutely, and secondly
        private var step: Int64 = 0
        private var gridOrigin: Int64 = 0
        private var periodOffsets: [Int64] = []

        init(_ recurrences: Recurrences) {
            rule = recurrences.rule
            start = recurrences.start
            range = recurrences.range
            timeZone = recurrences.timeZone

            let local = start.timeIntervalSince1970 + TimeInterval(timeZone.secondsFromGMT(for: start))
            let wholeSeconds = local.rounded(.down)
            startWall = Int64(wholeSeconds)
            fraction = local - wholeSeconds
            startDay = Int(floorDivide(startWall, Self.secondsPerDay))
            (startYear, startMonth, startDayOfMonth) = Gregorian.date(dayNumber: startDay)
            startWeekday = Gregorian.weekday(dayNumber: startDay)
            let secondOfDay = Int(startWall - Int64(startDay) * Self.secondsPerDay)
            startHour = secondOfDay / 3600
            startMinute = secondOfDay / 60 % 60
            startSecond = secondOfDay % 60

            filter = DayFilter(rule: rule, startWeekday: startWeekday)
            hours = rule.byHours.sorted()
            minutes = rule.byMinutes.sorted()
            // RFC 5545, section 3.3.5: "Implementations that do not support leap seconds
            // SHOULD interpret the second 60 as equivalent to the second 59."
            seconds = Array(Set(rule.bySeconds.map { Swift.min($0, 59) })).sorted()
        }

        mutating func next() -> Date? {
            if !hasStarted {
                hasStarted = true
                prepare()
            }
            while !isFinished {
                if bufferIndex < buffer.count {
                    let wall = buffer[bufferIndex]
                    bufferIndex += 1
                    if wall < startWall {
                        continue
                    }
                    let (date, isShifted) = wall == startWall ? (start, false) : resolve(wall)
                    if isShifted {
                        insertPending(date)
                        continue
                    }
                    if let first = pending.first, first <= date {
                        pending.removeFirst()
                        if first < date {
                            // Deliver the earlier date first, and return to this one.
                            bufferIndex -= 1
                            if let result = deliver(first) {
                                return result
                            }
                            continue
                        }
                    }
                    if let result = deliver(date) {
                        return result
                    }
                } else if isGenerating {
                    buffer.removeAll(keepingCapacity: true)
                    bufferIndex = 0
                    if rule.frequency.isSubDaily {
                        generateDay()
                    } else {
                        generatePeriod()
                    }
                } else if !pending.isEmpty {
                    let date = pending.removeFirst()
                    if let result = deliver(date) {
                        return result
                    }
                } else {
                    isFinished = true
                }
            }
            return nil
        }

        /// Counts a date and returns it if it's in the range,
        /// or returns `nil` and possibly ends the sequence.
        private mutating func deliver(_ date: Date) -> Date? {
            // During a repeated hour, a later local time can resolve to a date before the start.
            guard date >= start else { return nil }
            if let lastDate, date <= lastDate {
                // RFC 5545, section 3.8.5.3: "Duplicate instances are ignored."
                return nil
            }
            if let until = rule.until, date > until {
                isFinished = true
                return nil
            }
            if let range, date >= range.upperBound {
                isFinished = true
                return nil
            }
            count += 1
            lastDate = date
            lastProductive = rule.frequency.isSubDaily ? day - 1 : period - 1
            if let limit = rule.count, count >= limit {
                isFinished = true
            }
            if let range, date < range.lowerBound {
                return nil
            }
            return date
        }

        private mutating func insertPending(_ date: Date) {
            let index = pending.firstIndex { $0 >= date } ?? pending.endIndex
            if index < pending.endIndex && pending[index] == date {
                return
            }
            pending.insert(date, at: index)
        }

        // MARK: Local times

        /// Returns the date of a local time in the time zone,
        /// and whether the local time doesn't exist.
        ///
        /// As RFC 5545, section 3.3.5 states,
        /// a local time that occurs twice refers to its first occurrence,
        /// and a local time that doesn't exist uses the offset from UTC before the gap.
        private func resolve(_ wall: Int64) -> (Date, Bool) {
            let before = offset(at: wall - Self.secondsPerDay)
            let after = offset(at: wall + Self.secondsPerDay)
            let instantBefore = wall - before
            if before == after {
                return (date(instantBefore), false)
            }
            let instantAfter = wall - after
            let isValidBefore = offset(at: instantBefore) == before
            let isValidAfter = offset(at: instantAfter) == after
            switch (isValidBefore, isValidAfter) {
            case (true, true): return (date(Swift.min(instantBefore, instantAfter)), false)
            case (true, false): return (date(instantBefore), false)
            case (false, true): return (date(instantAfter), false)
            case (false, false): return (date(instantBefore), true)
            }
        }

        private func offset(at seconds: Int64) -> Int64 {
            Int64(timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: TimeInterval(seconds))))
        }

        private func date(_ seconds: Int64) -> Date {
            Date(timeIntervalSince1970: TimeInterval(seconds) + fraction)
        }

        private func wall(of date: Date) -> Int64 {
            let local = date.timeIntervalSince1970 + TimeInterval(timeZone.secondsFromGMT(for: date))
            guard local.isFinite, abs(local) < 1e15 else {
                return local < 0 ? Int64.min / 2 : Int64.max / 2
            }
            return Int64(local.rounded(.down))
        }

        // MARK: Preparation

        private mutating func prepare() {
            // Offsets from UTC differ by less than two days,
            // so no local time after this one can be in the sequence.
            let margin = 2 * Self.secondsPerDay
            if let until = rule.until {
                endWall = Swift.min(endWall, wall(of: until) + margin)
            }
            if let range {
                endWall = Swift.min(endWall, wall(of: range.upperBound) + margin)
            }

            if rule.frequency.isSubDaily {
                prepareSubDaily()
            } else {
                prepareDaily()
            }
        }

        private mutating func prepareDaily() {
            let hourList = hours.isEmpty ? [startHour] : hours
            let minuteList = minutes.isEmpty ? [startMinute] : minutes
            let secondList = seconds.isEmpty ? [startSecond] : seconds
            for hour in hourList {
                for minute in minuteList {
                    for second in secondList {
                        timesOfDay.append(Int64(hour * 3600 + minute * 60 + second))
                    }
                }
            }

            // The pattern of a rule repeats when both the calendar's 400-year cycle
            // and the interval end together.
            let cycle: Int
            switch rule.frequency {
            case .yearly: cycle = 400
            case .monthly: cycle = 4800
            case .weekly: cycle = Gregorian.daysPerCycle / 7
            default: cycle = Gregorian.daysPerCycle
            }
            searchLimit = cycle / greatestCommonDivisor(cycle, rule.interval)

            if rule.count == nil, let range {
                let lowerDay = Int(floorDivide(wall(of: range.lowerBound) - 2 * Self.secondsPerDay, Self.secondsPerDay))
                if let first = periodContaining(day: lowerDay), first > 0 {
                    period = first
                }
            }
            lastProductive = period
        }

        /// Returns the index of the period that contains a day, if the index fits in an integer.
        private func periodContaining(day: Int) -> Int? {
            let (year, month, _) = Gregorian.date(dayNumber: day)
            switch rule.frequency {
            case .yearly:
                return floorDivide(year - startYear, rule.interval)
            case .monthly:
                return floorDivide((year * 12 + month) - (startYear * 12 + startMonth), rule.interval)
            case .weekly:
                let (weeks, overflow) = rule.interval.multipliedReportingOverflow(by: 7)
                return overflow ? nil : floorDivide(day - startWeekBegin, weeks)
            default:
                return floorDivide(day - startDay, rule.interval)
            }
        }

        private var startWeekBegin: Int {
            startDay - floorModulo(startWeekday - filter.weekStart, 7)
        }

        private mutating func prepareSubDaily() {
            let unit: Int64
            switch rule.frequency {
            case .hourly: unit = 3600
            case .minutely: unit = 60
            default: unit = 1
            }
            let (product, overflow) = Int64(rule.interval).multipliedReportingOverflow(by: unit)
            guard !overflow else {
                isGenerating = false
                return
            }
            step = product
            gridOrigin = floorDivide(startWall, unit) * unit

            // The times within each period that the rule expands to.
            switch rule.frequency {
            case .hourly:
                for minute in minutes.isEmpty ? [startMinute] : minutes {
                    for second in seconds.isEmpty ? [startSecond] : seconds {
                        periodOffsets.append(Int64(minute * 60 + second))
                    }
                }
            case .minutely:
                periodOffsets = (seconds.isEmpty ? [startSecond] : seconds).map(Int64.init)
            default:
                periodOffsets = [0]
            }

            // A time of day is ever on the grid of periods only if it differs
            // from the start's time of day by a multiple of this divisor.
            let divisor = greatestCommonDivisor(step, Self.secondsPerDay)
            let startTime = floorModulo(gridOrigin, Self.secondsPerDay)
            if !periodTimesOfDay().contains(where: { floorModulo($0 - startTime, divisor) == 0 }) {
                isGenerating = false
                return
            }

            // The grid's pattern within days repeats every `daysPerGrid` days,
            // and the calendar's every 400 years.
            let daysPerGrid = Int(step / divisor)
            let common = greatestCommonDivisor(Gregorian.daysPerCycle, daysPerGrid)
            let (limit, limitOverflow) = (Gregorian.daysPerCycle / common).multipliedReportingOverflow(by: daysPerGrid)
            searchLimit = limitOverflow ? Int.max : limit

            day = startDay
            if rule.count == nil, let range {
                let lowerDay = Int(floorDivide(wall(of: range.lowerBound) - 2 * Self.secondsPerDay, Self.secondsPerDay))
                day = Swift.max(day, lowerDay)
            }
            lastProductive = day
        }

        /// The times of day, in seconds, of the periods that the time limits permit.
        private func periodTimesOfDay() -> [Int64] {
            let hourList = hours.isEmpty ? Array(0 ..< 24) : hours
            switch rule.frequency {
            case .hourly:
                return hourList.map { Int64($0 * 3600) }
            case .minutely:
                let minuteList = minutes.isEmpty ? Array(0 ..< 60) : minutes
                return hourList.flatMap { hour in minuteList.map { Int64(hour * 3600 + $0 * 60) } }
            default:
                let minuteList = minutes.isEmpty ? Array(0 ..< 60) : minutes
                let secondList = seconds.isEmpty ? Array(0 ..< 60) : seconds
                return hourList.flatMap { hour in
                    minuteList.flatMap { minute in secondList.map { Int64(hour * 3600 + minute * 60 + $0) } }
                }
            }
        }

        // MARK: Daily and longer

        private mutating func generatePeriod() {
            guard period - lastProductive <= searchLimit else {
                isGenerating = false
                return
            }
            let index = period
            period += 1

            var days: [Int] = []
            switch rule.frequency {
            case .yearly:
                let (offset, overflow) = index.multipliedReportingOverflow(by: rule.interval)
                guard !overflow, case let (year, yearOverflow) = startYear.addingReportingOverflow(offset), !yearOverflow,
                    abs(year) < 10_000_000
                else {
                    isGenerating = false
                    return
                }
                guard Int64(Gregorian.dayNumber(year: year, month: 1, day: 1)) * Self.secondsPerDay <= endWall else {
                    isGenerating = false
                    return
                }
                let monthList: [Int]
                if filter.hasMonths {
                    monthList = rule.byMonths.sorted()
                } else {
                    monthList = filter.selectsDays ? Array(1 ... 12) : [startMonth]
                }
                for month in monthList {
                    appendDays(year: year, month: month, to: &days)
                }
            case .monthly:
                let (offset, overflow) = index.multipliedReportingOverflow(by: rule.interval)
                guard !overflow, case let (monthIndex, indexOverflow) = (startYear * 12 + startMonth - 1).addingReportingOverflow(offset),
                    !indexOverflow, abs(monthIndex) < 120_000_000
                else {
                    isGenerating = false
                    return
                }
                let year = floorDivide(monthIndex, 12)
                let month = floorModulo(monthIndex, 12) + 1
                guard Int64(Gregorian.dayNumber(year: year, month: month, day: 1)) * Self.secondsPerDay <= endWall else {
                    isGenerating = false
                    return
                }
                if !filter.hasMonths || filter.months[month] {
                    appendDays(year: year, month: month, to: &days)
                }
            case .weekly:
                let (offset, overflow) = index.multipliedReportingOverflow(by: rule.interval &* 7)
                guard !overflow, rule.interval < Int.max / 7, case let (first, firstOverflow) = startWeekBegin.addingReportingOverflow(offset),
                    !firstOverflow, abs(first) < 3_650_000_000
                else {
                    isGenerating = false
                    return
                }
                guard Int64(first) * Self.secondsPerDay <= endWall else {
                    isGenerating = false
                    return
                }
                for day in first ..< first + 7 {
                    let weekday = Gregorian.weekday(dayNumber: day)
                    if !filter.selectsDays && weekday != startWeekday {
                        continue
                    }
                    let (year, month, dayOfMonth) = Gregorian.date(dayNumber: day)
                    if filter.matches(day: day, year: year, month: month, dayOfMonth: dayOfMonth) {
                        days.append(day)
                    }
                }
            default:
                let (offset, overflow) = index.multipliedReportingOverflow(by: rule.interval)
                guard !overflow, case let (day, dayOverflow) = startDay.addingReportingOverflow(offset), !dayOverflow,
                    abs(day) < 3_650_000_000
                else {
                    isGenerating = false
                    return
                }
                guard Int64(day) * Self.secondsPerDay <= endWall else {
                    isGenerating = false
                    return
                }
                let (year, month, dayOfMonth) = Gregorian.date(dayNumber: day)
                if filter.matches(day: day, year: year, month: month, dayOfMonth: dayOfMonth) {
                    days.append(day)
                }
            }

            var candidates: [Int64] = []
            candidates.reserveCapacity(days.count * timesOfDay.count)
            for day in days {
                let midnight = Int64(day) * Self.secondsPerDay
                for time in timesOfDay {
                    candidates.append(midnight + time)
                }
            }
            buffer.append(contentsOf: selectingSetPositions(candidates))
        }

        /// Appends the days of a month that the rule selects,
        /// or the start date's day of the month if the rule selects no day.
        private func appendDays(year: Int, month: Int, to days: inout [Int]) {
            let length = Gregorian.daysInMonth(month, year: year)
            let first = Gregorian.dayNumber(year: year, month: month, day: 1)
            if filter.selectsDays {
                for dayOfMonth in 1 ... length {
                    let day = first + dayOfMonth - 1
                    if filter.matches(day: day, year: year, month: month, dayOfMonth: dayOfMonth) {
                        days.append(day)
                    }
                }
            } else if startDayOfMonth <= length {
                // A date that doesn't exist, such as February 30, isn't a date of the rule.
                days.append(first + startDayOfMonth - 1)
            }
        }

        /// Returns the candidates at the positions in `BYSETPOS`,
        /// in increasing order, or every candidate if the rule has no `BYSETPOS`.
        private func selectingSetPositions(_ candidates: [Int64]) -> [Int64] {
            guard !rule.bySetPositions.isEmpty else {
                return candidates
            }
            var selected: [Int64] = []
            for position in rule.bySetPositions {
                let index = position > 0 ? position - 1 : candidates.count + position
                if candidates.indices.contains(index) {
                    selected.append(candidates[index])
                }
            }
            return Array(Set(selected)).sorted()
        }

        // MARK: Hourly, minutely, and secondly

        private mutating func generateDay() {
            // Move to the day of the next period at or after the start of this day.
            let dayStart = Int64(day) * Self.secondsPerDay
            let (periods, overflow) = Swift.max(0, ceilingDivide(dayStart - gridOrigin, step)).multipliedReportingOverflow(by: step)
            guard !overflow, case let (next, nextOverflow) = gridOrigin.addingReportingOverflow(periods), !nextOverflow,
                abs(next) < Int64(3_650_000_000) * Self.secondsPerDay
            else {
                isGenerating = false
                return
            }
            day = Int(floorDivide(next, Self.secondsPerDay))
            guard day - lastProductive <= searchLimit, Int64(day) * Self.secondsPerDay <= endWall else {
                isGenerating = false
                return
            }
            let currentDay = day
            day += 1

            let (year, month, dayOfMonth) = Gregorian.date(dayNumber: currentDay)
            guard filter.matches(day: currentDay, year: year, month: month, dayOfMonth: dayOfMonth) else {
                return
            }
            let midnight = Int64(currentDay) * Self.secondsPerDay
            for hour in hours.isEmpty ? Array(0 ..< 24) : hours {
                let hourStart = midnight + Int64(hour) * 3600
                for periodStart in periodStarts(inHourStartingAt: hourStart) {
                    let candidates = periodOffsets.map { periodStart + $0 }
                    buffer.append(contentsOf: selectingSetPositions(candidates))
                }
            }
        }

        /// Returns the starts of the periods in an hour that the minute and second limits permit.
        private func periodStarts(inHourStartingAt hourStart: Int64) -> [Int64] {
            let hourEnd = hourStart + 3600
            let limitsMinutes = rule.frequency != .hourly && !minutes.isEmpty
            let limitsSeconds = rule.frequency == .secondly && !seconds.isEmpty
            func isOnGrid(_ time: Int64) -> Bool {
                floorModulo(time - gridOrigin, step) == 0
            }

            let gridCount = step >= 3600 ? 1 : 3600 / step
            let minuteCount = limitsMinutes ? minutes.count : 60
            let secondCount = limitsSeconds ? seconds.count : 60
            let combinationCount: Int64 =
                switch rule.frequency {
                case .hourly: 1
                case .minutely: Int64(minuteCount)
                default: Int64(minuteCount * secondCount)
                }

            var starts: [Int64] = []
            if combinationCount < gridCount {
                // Test each time that the limits permit.
                for minute in limitsMinutes ? minutes : Array(0 ..< 60) {
                    let minuteStart = hourStart + Int64(minute) * 60
                    if rule.frequency == .secondly {
                        for second in limitsSeconds ? seconds : Array(0 ..< 60) where isOnGrid(minuteStart + Int64(second)) {
                            starts.append(minuteStart + Int64(second))
                        }
                    } else if isOnGrid(minuteStart) {
                        starts.append(minuteStart)
                    }
                }
            } else {
                // Test each period in the hour.
                var time = gridOrigin + ceilingDivide(hourStart - gridOrigin, step) * step
                while time < hourEnd {
                    let secondOfHour = Int(time - hourStart)
                    let minuteMatches = !limitsMinutes || minutes.contains(secondOfHour / 60)
                    let secondMatches = !limitsSeconds || seconds.contains(secondOfHour % 60)
                    if minuteMatches && secondMatches {
                        starts.append(time)
                    }
                    time += step
                }
            }
            return starts
        }
    }
}

extension RecurrenceRule.Frequency {
    /// Whether the frequency is shorter than a day.
    var isSubDaily: Bool {
        self == .hourly || self == .minutely || self == .secondly
    }
}
