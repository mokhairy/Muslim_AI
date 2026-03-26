from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from django.utils import timezone

from .calendar_utils import (
    CalendarModeDefinition,
    IslamicDateValue,
    gregorian_to_hijri_for_mode,
    supported_gregorian_range,
)


@dataclass(frozen=True)
class CalendarDisplayRecord:
    gregorian_date: date
    hijri_value: IslamicDateValue
    calendar_mode: CalendarModeDefinition

    @property
    def weekday(self) -> str:
        return self.gregorian_date.strftime("%A")

    @property
    def hijri_year(self) -> int:
        return self.hijri_value.year

    @property
    def hijri_month(self) -> int:
        return self.hijri_value.month

    @property
    def hijri_day(self) -> int:
        return self.hijri_value.day

    @property
    def hijri_month_name(self) -> str:
        return self.hijri_value.month_name

    @property
    def hijri_display(self) -> str:
        return self.hijri_value.formatted


def resolve_calendar_record(
    gregorian_date: date,
    *,
    mode: CalendarModeDefinition,
) -> CalendarDisplayRecord:
    return CalendarDisplayRecord(
        gregorian_date=gregorian_date,
        hijri_value=gregorian_to_hijri_for_mode(gregorian_date, mode.slug),
        calendar_mode=mode,
    )


def today_record(mode: CalendarModeDefinition) -> CalendarDisplayRecord:
    supported_min, supported_max = supported_gregorian_range(mode.slug)
    today = min(max(timezone.localdate(), supported_min), supported_max)
    return resolve_calendar_record(today, mode=mode)
