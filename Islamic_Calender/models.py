from __future__ import annotations

from datetime import date, timedelta

from django.core.exceptions import ValidationError
from django.db import models

from .calendar_utils import (
    HIJRI_MONTH_NAMES,
    MAX_SUPPORTED_GREGORIAN,
    MIN_SUPPORTED_GREGORIAN,
    gregorian_to_hijri,
    hijri_to_gregorian,
)


class CalendarDate(models.Model):
    gregorian_date = models.DateField(unique=True)
    gregorian_year = models.PositiveSmallIntegerField(db_index=True, editable=False)
    gregorian_month = models.PositiveSmallIntegerField(db_index=True, editable=False)
    gregorian_day = models.PositiveSmallIntegerField(editable=False)
    hijri_year = models.PositiveSmallIntegerField(db_index=True)
    hijri_month = models.PositiveSmallIntegerField(db_index=True)
    hijri_day = models.PositiveSmallIntegerField()
    weekday = models.CharField(max_length=9, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("gregorian_date",)
        constraints = [
            models.UniqueConstraint(
                fields=("hijri_year", "hijri_month", "hijri_day"),
                name="unique_hijri_date",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.gregorian_date.isoformat()} / {self.hijri_display}"

    @property
    def hijri_month_name(self) -> str:
        return HIJRI_MONTH_NAMES[self.hijri_month - 1]

    @property
    def hijri_display(self) -> str:
        return f"{self.hijri_day} {self.hijri_month_name} {self.hijri_year} AH"

    def clean(self) -> None:
        super().clean()
        if self.gregorian_date and not (
            MIN_SUPPORTED_GREGORIAN <= self.gregorian_date <= MAX_SUPPORTED_GREGORIAN
        ):
            raise ValidationError(
                {
                    "gregorian_date": (
                        f"Gregorian date must be between "
                        f"{MIN_SUPPORTED_GREGORIAN.isoformat()} and "
                        f"{MAX_SUPPORTED_GREGORIAN.isoformat()}."
                    )
                }
            )

    def save(self, *args, **kwargs):
        if not self.gregorian_date:
            if self.hijri_year and self.hijri_month and self.hijri_day:
                self.gregorian_date = hijri_to_gregorian(
                    self.hijri_year,
                    self.hijri_month,
                    self.hijri_day,
                )
            else:
                raise ValidationError("Provide either a Gregorian date or a complete Hijri date.")

        hijri_value = gregorian_to_hijri(self.gregorian_date)
        self.gregorian_year = self.gregorian_date.year
        self.gregorian_month = self.gregorian_date.month
        self.gregorian_day = self.gregorian_date.day
        self.hijri_year = hijri_value.year
        self.hijri_month = hijri_value.month
        self.hijri_day = hijri_value.day
        self.weekday = self.gregorian_date.strftime("%A")
        super().save(*args, **kwargs)

    @classmethod
    def build_for_gregorian(cls, gregorian_date: date) -> CalendarDate:
        hijri_value = gregorian_to_hijri(gregorian_date)
        return cls(
            gregorian_date=gregorian_date,
            gregorian_year=gregorian_date.year,
            gregorian_month=gregorian_date.month,
            gregorian_day=gregorian_date.day,
            hijri_year=hijri_value.year,
            hijri_month=hijri_value.month,
            hijri_day=hijri_value.day,
            weekday=gregorian_date.strftime("%A"),
        )

    @classmethod
    def get_or_create_for_gregorian(cls, gregorian_date: date) -> CalendarDate:
        instance = cls.objects.filter(gregorian_date=gregorian_date).first()
        if instance:
            return instance

        instance = cls.build_for_gregorian(gregorian_date)
        instance.save()
        return instance

    @classmethod
    def get_or_create_for_hijri(cls, year: int, month: int, day: int) -> CalendarDate:
        gregorian_date = hijri_to_gregorian(year, month, day)
        return cls.get_or_create_for_gregorian(gregorian_date)

    @classmethod
    def populate_range(
        cls,
        start_date: date = MIN_SUPPORTED_GREGORIAN,
        end_date: date = MAX_SUPPORTED_GREGORIAN,
        batch_size: int = 2000,
    ) -> int:
        if start_date > end_date:
            return 0

        existing_dates = set(
            cls.objects.filter(gregorian_date__range=(start_date, end_date)).values_list(
                "gregorian_date",
                flat=True,
            )
        )
        current = start_date
        created = 0
        pending: list[CalendarDate] = []
        while current <= end_date:
            if current not in existing_dates:
                pending.append(cls.build_for_gregorian(current))
                if len(pending) >= batch_size:
                    cls.objects.bulk_create(pending, ignore_conflicts=True)
                    created += len(pending)
                    pending = []
            current += timedelta(days=1)

        if pending:
            cls.objects.bulk_create(pending, ignore_conflicts=True)
            created += len(pending)

        return created
