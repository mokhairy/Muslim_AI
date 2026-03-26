from __future__ import annotations

from datetime import date

from django import forms

from .calendar_utils import (
    APP_DEFAULT_CALENDAR_MODE,
    hijri_to_gregorian_for_mode,
    supported_gregorian_range,
)


class GregorianLookupForm(forms.Form):
    gregorian_date = forms.DateField(
        label="Gregorian date",
        widget=forms.DateInput(attrs={"type": "date"}),
    )

    def __init__(self, *args, calendar_mode: str = APP_DEFAULT_CALENDAR_MODE, **kwargs):
        super().__init__(*args, **kwargs)
        self.calendar_mode = calendar_mode
        supported_min, supported_max = supported_gregorian_range(calendar_mode)
        field = self.fields["gregorian_date"]
        initial_date = min(max(date.today(), supported_min), supported_max)
        field.initial = initial_date.isoformat()
        field.widget.attrs.update(
            {
                "min": supported_min.isoformat(),
                "max": supported_max.isoformat(),
            }
        )

    def clean_gregorian_date(self):
        value = self.cleaned_data["gregorian_date"]
        supported_min, supported_max = supported_gregorian_range(self.calendar_mode)
        if not supported_min <= value <= supported_max:
            raise forms.ValidationError(
                f"Supported Gregorian range is {supported_min.isoformat()} to "
                f"{supported_max.isoformat()} for this calendar mode."
            )
        return value


class HijriLookupForm(forms.Form):
    hijri_year = forms.IntegerField(label="Hijri year", min_value=1)
    hijri_month = forms.IntegerField(label="Hijri month", min_value=1, max_value=12)
    hijri_day = forms.IntegerField(label="Hijri day", min_value=1, max_value=30)

    def __init__(self, *args, calendar_mode: str = APP_DEFAULT_CALENDAR_MODE, **kwargs):
        super().__init__(*args, **kwargs)
        self.calendar_mode = calendar_mode

    def clean(self):
        cleaned_data = super().clean()
        year = cleaned_data.get("hijri_year")
        month = cleaned_data.get("hijri_month")
        day = cleaned_data.get("hijri_day")
        if year is None or month is None or day is None:
            return cleaned_data

        try:
            cleaned_data["gregorian_date"] = hijri_to_gregorian_for_mode(
                year,
                month,
                day,
                self.calendar_mode,
            )
        except ValueError as exc:
            raise forms.ValidationError(str(exc)) from exc
        return cleaned_data
