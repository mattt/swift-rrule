/// Proleptic Gregorian date arithmetic on day numbers,
/// where day 0 is January 1, 1970.
///
/// RFC 5545 defines recurrence rules on the Gregorian calendar,
/// so the expansion uses this arithmetic in place of `Calendar`.
/// The algorithms are Howard Hinnant's `days_from_civil` and `civil_from_days`.
enum Gregorian {
    /// The number of days in one 400-year cycle, after which the calendar repeats.
    static let daysPerCycle = 146_097

    /// Returns the day number of a date.
    static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = floorDivide(y, 400)
        let yearOfEra = y - era * 400
        let shiftedMonth = (month + 9) % 12
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * daysPerCycle + dayOfEra - 719_468
    }

    /// Returns the year, month, and day of a day number.
    static func date(dayNumber: Int) -> (year: Int, month: Int, day: Int) {
        let z = dayNumber + 719_468
        let era = floorDivide(z, daysPerCycle)
        let dayOfEra = z - era * daysPerCycle
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }

    /// Returns the day of the week of a day number, where Sunday is 0.
    static func weekday(dayNumber: Int) -> Int {
        floorModulo(dayNumber + 4, 7)
    }

    static func isLeapYear(_ year: Int) -> Bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    static func daysInMonth(_ month: Int, year: Int) -> Int {
        switch month {
        case 2: isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    static func daysInYear(_ year: Int) -> Int {
        isLeapYear(year) ? 366 : 365
    }
}

/// Returns the quotient of a division, rounded toward negative infinity.
func floorDivide<T: SignedInteger>(_ dividend: T, _ divisor: T) -> T {
    let quotient = dividend / divisor
    return dividend % divisor != 0 && (dividend < 0) != (divisor < 0) ? quotient - 1 : quotient
}

/// Returns the remainder of a division, with the sign of the divisor.
func floorModulo<T: SignedInteger>(_ dividend: T, _ divisor: T) -> T {
    dividend - floorDivide(dividend, divisor) * divisor
}

/// Returns the quotient of a division, rounded toward positive infinity.
func ceilingDivide<T: SignedInteger>(_ dividend: T, _ divisor: T) -> T {
    -floorDivide(-dividend, divisor)
}

/// Returns the greatest common divisor of two positive integers.
func greatestCommonDivisor<T: BinaryInteger>(_ a: T, _ b: T) -> T {
    var (a, b) = (a, b)
    while b != 0 { (a, b) = (b, a % b) }
    return a
}
