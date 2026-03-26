from __future__ import annotations

from datetime import date

from django import forms

from .services import AUTOMATED_PRAYER_NAMES, get_adhan_stream_choices


def prayer_stream_field_name(prayer_name: str) -> str:
    return f"stream_for_{prayer_name.lower()}"


class PrayerTimesLookupForm(forms.Form):
    prayer_date = forms.DateField(
        label="Date",
        widget=forms.DateInput(attrs={"type": "date"}),
    )
    latitude = forms.FloatField(
        label="Latitude",
        min_value=-90,
        max_value=90,
        widget=forms.NumberInput(attrs={"step": "any"}),
    )
    longitude = forms.FloatField(
        label="Longitude",
        min_value=-180,
        max_value=180,
        widget=forms.NumberInput(attrs={"step": "any"}),
    )
    location_label = forms.CharField(
        label="Location label",
        required=False,
        max_length=120,
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["prayer_date"].initial = date.today().isoformat()


class QiblaLookupForm(forms.Form):
    latitude = forms.FloatField(
        label="Latitude",
        min_value=-90,
        max_value=90,
        widget=forms.NumberInput(attrs={"step": "any"}),
    )
    longitude = forms.FloatField(
        label="Longitude",
        min_value=-180,
        max_value=180,
        widget=forms.NumberInput(attrs={"step": "any"}),
    )
    location_label = forms.CharField(
        label="Location label",
        required=False,
        max_length=120,
    )


class PrayerAutomationForm(forms.Form):
    enabled = forms.BooleanField(label="Enable automatic adhan", required=False)
    speaker_group_id = forms.ChoiceField(label="Speaker preset", required=False, choices=())
    location_label = forms.CharField(label="Location label", required=False, max_length=120)
    latitude = forms.FloatField(
        label="Latitude",
        min_value=-90,
        max_value=90,
        widget=forms.NumberInput(attrs={"step": "any"}),
    )
    longitude = forms.FloatField(
        label="Longitude",
        min_value=-180,
        max_value=180,
        widget=forms.NumberInput(attrs={"step": "any"}),
    )
    selected_stream_url = forms.ChoiceField(label="Adhan stream", choices=())
    enabled_prayers = forms.MultipleChoiceField(
        label="Automatic prayers",
        required=False,
        widget=forms.CheckboxSelectMultiple,
        choices=[(name, name) for name in AUTOMATED_PRAYER_NAMES],
    )
    selected_device_ids = forms.MultipleChoiceField(
        label="Target speakers",
        required=False,
        widget=forms.CheckboxSelectMultiple,
        choices=(),
    )

    def __init__(
        self,
        *args,
        device_choices: list[tuple[str, str]] | None = None,
        group_choices: list[tuple[str, str]] | None = None,
        **kwargs,
    ):
        super().__init__(*args, **kwargs)
        stream_choices = get_adhan_stream_choices()
        self.fields["selected_stream_url"].choices = stream_choices
        self.fields["selected_device_ids"].choices = device_choices or []
        self.fields["speaker_group_id"].choices = [("", "No preset")] + (group_choices or [])
        custom_stream_choices = [("", "Use default stream")] + stream_choices
        for prayer_name in AUTOMATED_PRAYER_NAMES:
            self.fields[prayer_stream_field_name(prayer_name)] = forms.ChoiceField(
                label=f"{prayer_name} custom stream",
                required=False,
                choices=custom_stream_choices,
            )
        self.order_fields(
            [
                "enabled",
                "speaker_group_id",
                "location_label",
                "latitude",
                "longitude",
                "selected_stream_url",
                *[prayer_stream_field_name(prayer_name) for prayer_name in AUTOMATED_PRAYER_NAMES],
                "enabled_prayers",
                "selected_device_ids",
            ]
        )

    def clean(self):
        cleaned_data = super().clean()
        enabled = cleaned_data.get("enabled")
        selected_devices = cleaned_data.get("selected_device_ids") or []
        enabled_prayers = cleaned_data.get("enabled_prayers") or []
        if enabled and not selected_devices:
            self.add_error(
                "selected_device_ids",
                "Select at least one speaker for automatic adhan.",
            )
        if enabled and not enabled_prayers:
            self.add_error("enabled_prayers", "Choose at least one prayer to automate.")
        return cleaned_data


class SpeakerGroupForm(forms.Form):
    name = forms.CharField(label="Preset name", max_length=120)
    selected_device_ids = forms.MultipleChoiceField(
        label="Preset speakers",
        required=False,
        widget=forms.CheckboxSelectMultiple,
        choices=(),
    )

    def __init__(
        self,
        *args,
        device_choices: list[tuple[str, str]] | None = None,
        **kwargs,
    ):
        super().__init__(*args, **kwargs)
        self.fields["selected_device_ids"].choices = device_choices or []

    def clean_selected_device_ids(self):
        selected_device_ids = self.cleaned_data.get("selected_device_ids") or []
        if not selected_device_ids:
            raise forms.ValidationError("Select at least one speaker for the preset.")
        return selected_device_ids
