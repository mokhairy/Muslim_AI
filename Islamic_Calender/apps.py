from django.apps import AppConfig


class IslamicCalendarConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "Islamic_Calender"
    label = "islamic_calender"
    verbose_name = "Islamic Calendar"


# Backward-compatible alias for the previous class name.
IslamicCalenderConfig = IslamicCalendarConfig
