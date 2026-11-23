# /// script
# requires-python = ">=3.11"
# dependencies = ["python-dateutil==2.9.0.post0"]
# ///
"""Generate the dateutil fixture for the differential expansion test.

Run from the repository root:

    uv run Tests/generate_dateutil_fixture.py

The script writes Tests/RRULETests/Resources/dateutil-fixture.json.
Each entry has a rule, a local start date and time and its UTC time, a time zone,
an end date, and the dates that python-dateutil gives,
at most LIMIT of them and none after the end date, as UTC times.
A rule that dateutil doesn't finish within TIME_LIMIT_SECONDS is left out.

dateutil works in local wall time.
Converting a local time with fold=0 to UTC gives the first occurrence
of a repeated time and uses the offset before a gap for a nonexistent time,
as RFC 5545, section 3.3.5 states.
"""

import json
import random
import signal
from datetime import UTC, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from dateutil.rrule import rrulestr

LIMIT = 25
YEARS = 20
TIME_LIMIT_SECONDS = 30
OUTPUT = Path(__file__).parent / "RRULETests" / "Resources" / "dateutil-fixture.json"

TIME_ZONES = [
    "America/New_York",
    "America/Los_Angeles",
    "Europe/London",
    "Australia/Sydney",
    "Asia/Kolkata",
    "UTC",
]

WEEKDAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

# Rules for specific cases: daylight saving time, leap years, month ends, and week 53.
CURATED = [
    # Daylight saving time in New York: clocks go forward on 2025-03-09
    # and back on 2025-11-02, at 2:00 AM.
    ("FREQ=DAILY;COUNT=5", "2025-03-07T02:30:00", "America/New_York"),
    ("FREQ=DAILY;COUNT=5", "2025-10-31T01:30:00", "America/New_York"),
    ("FREQ=WEEKLY;COUNT=4", "2025-03-02T02:30:00", "America/New_York"),
    ("FREQ=HOURLY;COUNT=6", "2025-11-01T23:00:00", "America/New_York"),
    ("FREQ=MINUTELY;INTERVAL=30;COUNT=8", "2025-11-02T00:00:00", "America/New_York"),
    (
        "FREQ=DAILY;BYHOUR=1,2,3;BYMINUTE=30;COUNT=9",
        "2025-11-01T01:30:00",
        "America/New_York",
    ),
    (
        "FREQ=MONTHLY;BYDAY=2SU;BYHOUR=2;BYMINUTE=30;COUNT=6",
        "2025-01-12T02:30:00",
        "America/New_York",
    ),
    (
        "FREQ=YEARLY;BYMONTH=3;BYDAY=2SU;BYHOUR=1,3;COUNT=6",
        "2025-03-09T01:00:00",
        "America/New_York",
    ),
    ("FREQ=DAILY;COUNT=5", "2025-10-04T02:30:00", "Australia/Sydney"),
    ("FREQ=DAILY;COUNT=5", "2025-04-04T02:30:00", "Australia/Sydney"),
    ("FREQ=DAILY;COUNT=5", "2025-03-29T01:30:00", "Europe/London"),
    # Leap years and month ends
    ("FREQ=YEARLY;COUNT=5", "2024-02-29T10:00:00", "UTC"),
    ("FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29;COUNT=4", "2023-01-01T08:00:00", "UTC"),
    (
        "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=-1;COUNT=6",
        "2023-02-28T08:00:00",
        "America/New_York",
    ),
    ("FREQ=MONTHLY;COUNT=12", "2025-01-31T09:00:00", "America/New_York"),
    ("FREQ=MONTHLY;BYMONTHDAY=-1;COUNT=12", "2025-01-31T09:00:00", "America/New_York"),
    ("FREQ=MONTHLY;BYMONTHDAY=31,-31;COUNT=12", "2025-01-01T09:00:00", "Europe/London"),
    ("FREQ=MONTHLY;BYMONTHDAY=29,30;COUNT=12", "2024-01-29T09:00:00", "UTC"),
    ("FREQ=YEARLY;BYYEARDAY=60,-306;COUNT=8", "2023-01-01T12:00:00", "UTC"),
    ("FREQ=YEARLY;BYYEARDAY=366;COUNT=4", "2020-01-01T12:00:00", "UTC"),
    ("FREQ=YEARLY;BYYEARDAY=-366;COUNT=4", "2020-01-01T12:00:00", "UTC"),
    (
        "FREQ=DAILY;BYMONTHDAY=-1;BYMONTH=2;COUNT=6",
        "2023-01-01T00:00:00",
        "Asia/Kolkata",
    ),
    # Week numbers, week 53, and WKST
    ("FREQ=YEARLY;BYWEEKNO=53;BYDAY=MO;COUNT=4", "2015-01-01T09:00:00", "UTC"),
    ("FREQ=YEARLY;BYWEEKNO=53;BYDAY=TH;WKST=SU;COUNT=4", "2015-01-01T09:00:00", "UTC"),
    ("FREQ=YEARLY;BYWEEKNO=1;BYDAY=MO,SU;COUNT=8", "2019-01-01T09:00:00", "UTC"),
    ("FREQ=YEARLY;BYWEEKNO=-1;BYDAY=MO,FR;COUNT=8", "2019-01-01T09:00:00", "UTC"),
    (
        "FREQ=YEARLY;BYWEEKNO=1,52;BYDAY=TU;WKST=SU;COUNT=8",
        "2019-01-01T09:00:00",
        "America/New_York",
    ),
    ("FREQ=YEARLY;BYWEEKNO=26;BYDAY=WE;WKST=WE;COUNT=6", "2020-01-01T09:00:00", "UTC"),
    (
        "FREQ=YEARLY;BYWEEKNO=10,20;BYDAY=SA,SU;BYMONTH=3;COUNT=8",
        "2020-01-01T09:00:00",
        "UTC",
    ),
    (
        "FREQ=WEEKLY;INTERVAL=3;BYDAY=SA,MO;WKST=TU;COUNT=10",
        "2025-01-01T09:00:00",
        "UTC",
    ),
    (
        "FREQ=WEEKLY;INTERVAL=2;BYDAY=SU,WE;WKST=TH;COUNT=10",
        "2025-01-01T09:00:00",
        "UTC",
    ),
    # Ordinal weekdays and set positions
    ("FREQ=YEARLY;BYDAY=-1SU;COUNT=5", "2025-01-01T09:00:00", "UTC"),
    ("FREQ=YEARLY;BYDAY=53MO,-53MO;COUNT=4", "2000-01-01T09:00:00", "UTC"),
    ("FREQ=YEARLY;BYMONTH=1,7;BYDAY=-1FR,2MO;COUNT=8", "2025-01-01T09:00:00", "UTC"),
    ("FREQ=MONTHLY;BYDAY=5FR;COUNT=6", "2025-01-01T09:00:00", "UTC"),
    (
        "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=12",
        "2026-01-01T09:00:00",
        "America/Los_Angeles",
    ),
    (
        "FREQ=MONTHLY;BYDAY=SA,SU;BYSETPOS=1,-1;COUNT=12",
        "2026-01-01T09:00:00",
        "America/Los_Angeles",
    ),
    ("FREQ=WEEKLY;BYDAY=MO,WE,FR;BYSETPOS=2;COUNT=6", "2026-01-01T09:00:00", "UTC"),
    ("FREQ=DAILY;BYHOUR=8,12,18;BYSETPOS=-1;COUNT=5", "2026-01-01T09:00:00", "UTC"),
    (
        "FREQ=YEARLY;BYMONTH=6;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=10,-10;COUNT=6",
        "2026-01-01T09:00:00",
        "UTC",
    ),
    (
        "FREQ=HOURLY;BYMINUTE=0,15,30,45;BYSETPOS=2,-1;COUNT=8",
        "2026-01-01T09:00:00",
        "UTC",
    ),
    # Sub-daily rules with limits
    ("FREQ=SECONDLY;INTERVAL=17;COUNT=10", "2026-01-01T09:00:05", "UTC"),
    ("FREQ=SECONDLY;BYSECOND=0,30;BYMINUTE=0;COUNT=6", "2026-01-01T09:00:00", "UTC"),
    ("FREQ=MINUTELY;INTERVAL=7;BYHOUR=9;COUNT=12", "2026-01-01T08:58:00", "UTC"),
    ("FREQ=HOURLY;INTERVAL=5;BYDAY=MO;COUNT=10", "2026-01-01T09:00:00", "UTC"),
    (
        "FREQ=HOURLY;BYMONTHDAY=1;BYHOUR=0,12;COUNT=6",
        "2026-01-01T00:00:00",
        "Asia/Kolkata",
    ),
    ("FREQ=MINUTELY;INTERVAL=45;BYYEARDAY=1,-1;COUNT=10", "2025-12-31T20:00:00", "UTC"),
    # UNTIL equal to a date is inclusive
    ("FREQ=DAILY;UNTIL=20260105T140000Z", "2026-01-01T09:00:00", "America/New_York"),
    (
        "FREQ=WEEKLY;UNTIL=20260129T170000Z;BYDAY=TH",
        "2026-01-01T09:00:00",
        "America/Los_Angeles",
    ),
    # Cases where RFC 5545 and dateutil differ; the Swift test lists each one.
    ("FREQ=YEARLY;BYWEEKNO=20;COUNT=4", "1997-05-12T09:00:00", "America/New_York"),
    ("FREQ=HOURLY;COUNT=6", "2025-03-08T23:00:00", "America/New_York"),
    ("FREQ=MONTHLY;BYDAY=1FR,MO;COUNT=6", "2026-01-01T09:00:00", "UTC"),
    ("FREQ=WEEKLY;BYDAY=MO,WE,FR;BYSETPOS=1;COUNT=3", "2026-01-01T09:00:00", "UTC"),
    ("FREQ=MINUTELY;INTERVAL=30;COUNT=8", "2025-03-09T00:30:00", "America/New_York"),
    # A start date that the rule doesn't match
    ("FREQ=MONTHLY;BYDAY=1SU;COUNT=4", "2026-01-15T09:00:00", "UTC"),
    ("FREQ=WEEKLY;BYDAY=TU;COUNT=3", "2026-01-01T09:00:00", "UTC"),
    ("FREQ=DAILY;BYHOUR=8;COUNT=3", "2026-01-01T09:00:00", "UTC"),
]


def random_rule(rng: random.Random) -> tuple[str, str, str]:
    frequency = rng.choice(
        [
            "SECONDLY",
            "MINUTELY",
            "HOURLY",
            "DAILY",
            "DAILY",
            "WEEKLY",
            "WEEKLY",
            "MONTHLY",
            "MONTHLY",
            "YEARLY",
            "YEARLY",
        ]
    )
    parts = [f"FREQ={frequency}"]
    interval = rng.choice([1, 1, 1, 2, 3, 4])
    if interval > 1:
        parts.append(f"INTERVAL={interval}")

    def sample(values, low, high):
        return sorted(rng.sample(values, rng.randint(low, high)))

    def joined(values):
        return ",".join(str(value) for value in values)

    has_weeks = False
    if rng.random() < 0.3:
        parts.append(f"BYMONTH={joined(sample(range(1, 13), 1, 3))}")
    if frequency == "YEARLY" and rng.random() < 0.15:
        has_weeks = True
        parts.append(
            f"BYWEEKNO={joined(sample(list(range(1, 54)) + list(range(-53, 0)), 1, 2))}"
        )
    if (
        frequency in ("SECONDLY", "MINUTELY", "HOURLY", "YEARLY")
        and rng.random() < 0.15
    ):
        parts.append(
            f"BYYEARDAY={joined(sample(list(range(1, 367)) + list(range(-366, 0)), 1, 3))}"
        )
    if frequency != "WEEKLY" and rng.random() < 0.25:
        parts.append(
            f"BYMONTHDAY={joined(sample(list(range(1, 32)) + list(range(-31, 0)), 1, 4))}"
        )
    if rng.random() < 0.45 or has_weeks:
        # dateutil requires a day to match both a weekday with an occurrence
        # and a weekday without one, so a rule uses only one kind; see CURATED.
        with_occurrences = (
            frequency in ("MONTHLY", "YEARLY") and not has_weeks and rng.random() < 0.4
        )
        entries = []
        for weekday in sample(WEEKDAYS, 1, 3):
            if with_occurrences:
                limit = (
                    5
                    if frequency == "MONTHLY"
                    or any(part.startswith("BYMONTH=") for part in parts)
                    else 53
                )
                ordinal = rng.choice(
                    [1, 2, 3, 4, -1, -2, rng.randint(1, limit), -rng.randint(1, limit)]
                )
                entries.append(f"{ordinal}{weekday}")
            else:
                entries.append(weekday)
        parts.append(f"BYDAY={','.join(entries)}")
    if rng.random() < 0.3:
        parts.append(f"BYHOUR={joined(sample(range(24), 1, 3))}")
    if rng.random() < 0.25:
        parts.append(f"BYMINUTE={joined(sample(range(60), 1, 3))}")
    if (
        frequency in ("SECONDLY", "MINUTELY", "HOURLY")
        and rng.random() < 0.25
        or rng.random() < 0.1
    ):
        parts.append(f"BYSECOND={joined(sample(range(60), 1, 3))}")
    # dateutil starts the first week's set at the start date, so a weekly rule
    # with BYSETPOS starts on its week start; see CURATED.
    if (
        len(parts) > 1
        and any(part.startswith("BY") for part in parts)
        and rng.random() < 0.2
    ):
        parts.append(f"BYSETPOS={joined(sample([1, 2, 3, -1, -2], 1, 2))}")
    if rng.random() < 0.2:
        parts.append(f"WKST={rng.choice(WEEKDAYS)}")
    if rng.random() < 0.3:
        parts.append(f"COUNT={rng.randint(1, 30)}")

    start = datetime(
        rng.randint(1995, 2035),
        rng.randint(1, 12),
        rng.randint(1, 28),
        rng.randint(0, 23),
        rng.choice([0, 0, 15, 30, rng.randint(0, 59)]),
        rng.choice([0, 0, 0, rng.randint(0, 59)]),
    )
    if frequency == "WEEKLY" and any(part.startswith("BYSETPOS=") for part in parts):
        week_start = next(
            (part[5:] for part in parts if part.startswith("WKST=")), "MO"
        )
        start -= timedelta(days=(start.weekday() - WEEKDAYS.index(week_start)) % 7)
    return ";".join(parts), start.isoformat(), rng.choice(TIME_ZONES)


class Timeout(Exception):
    pass


def expand(rule: str, start: str, time_zone: str):
    zone = ZoneInfo(time_zone)
    dtstart = datetime.fromisoformat(start).replace(tzinfo=zone)
    end = dtstart.replace(year=dtstart.year + YEARS)
    dates = []

    def stop(signum, frame):
        raise Timeout()

    signal.signal(signal.SIGALRM, stop)
    signal.alarm(TIME_LIMIT_SECONDS)
    try:
        for date in rrulestr(rule, dtstart=dtstart):
            if date > end or len(dates) == LIMIT:
                break
            dates.append(date.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"))
    finally:
        signal.alarm(0)
    return {
        "rule": rule,
        "start": start,
        "startUTC": dtstart.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "timeZone": time_zone,
        "end": end.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "dates": dates,
    }


def main():
    rng = random.Random(5545)
    candidates = list(CURATED)
    while len(candidates) < len(CURATED) + 300:
        candidates.append(random_rule(rng))

    entries = []
    for rule, start, time_zone in candidates:
        try:
            entry = expand(rule, start, time_zone)
        except Timeout:
            continue
        except ValueError:
            # dateutil rejects a sub-daily rule whose times never fall on its interval,
            # which is a rule without dates.
            end = datetime.fromisoformat(start).replace(tzinfo=ZoneInfo(time_zone))
            end = end.replace(year=end.year + YEARS)
            entry = {
                "rule": rule,
                "start": start,
                "startUTC": end.replace(year=end.year - YEARS)
                .astimezone(UTC)
                .strftime("%Y-%m-%dT%H:%M:%SZ"),
                "timeZone": time_zone,
                "end": end.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "dates": [],
            }
        entries.append(entry)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(entries, indent=1) + "\n")
    print(f"Wrote {len(entries)} rules to {OUTPUT}")


if __name__ == "__main__":
    main()
