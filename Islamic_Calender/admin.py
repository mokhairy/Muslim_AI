from django.contrib import admin

from .models import CalendarDate


@admin.register(CalendarDate)
class CalendarDateAdmin(admin.ModelAdmin):
    list_display = (
        "gregorian_date",
        "weekday",
        "hijri_day",
        "hijri_month_name",
        "hijri_year",
    )
    list_filter = ("gregorian_year", "gregorian_month", "hijri_year", "hijri_month")
    search_fields = ("gregorian_date", "=hijri_year", "=hijri_month", "=hijri_day")
    ordering = ("gregorian_date",)


# Register your models here.
