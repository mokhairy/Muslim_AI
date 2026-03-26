from __future__ import annotations

from datetime import date

from django.core.management.base import BaseCommand

from Islamic_Calender.calendar_utils import MAX_SUPPORTED_GREGORIAN, MIN_SUPPORTED_GREGORIAN
from Islamic_Calender.models import CalendarDate


class Command(BaseCommand):
    help = "Populate stored Gregorian/Hijri date mappings from the Hijri epoch to 2100."

    def add_arguments(self, parser):
        parser.add_argument(
            "--start-year",
            type=int,
            default=MIN_SUPPORTED_GREGORIAN.year,
            help="Gregorian start year for population.",
        )
        parser.add_argument(
            "--end-year",
            type=int,
            default=MAX_SUPPORTED_GREGORIAN.year,
            help="Gregorian end year for population.",
        )
        parser.add_argument(
            "--batch-size",
            type=int,
            default=2000,
            help="Bulk insert batch size.",
        )

    def handle(self, *args, **options):
        start_year = max(options["start_year"], MIN_SUPPORTED_GREGORIAN.year)
        end_year = min(options["end_year"], MAX_SUPPORTED_GREGORIAN.year)
        if start_year > end_year:
            self.stderr.write(self.style.ERROR("Start year must not be greater than end year."))
            return

        total_created = 0
        for year in range(start_year, end_year + 1):
            start_date = date(year, 1, 1)
            end_date = date(year, 12, 31)
            if year == MIN_SUPPORTED_GREGORIAN.year:
                start_date = MIN_SUPPORTED_GREGORIAN
            if year == MAX_SUPPORTED_GREGORIAN.year:
                end_date = MAX_SUPPORTED_GREGORIAN
            created = CalendarDate.populate_range(
                start_date=start_date,
                end_date=end_date,
                batch_size=options["batch_size"],
            )
            total_created += created
            self.stdout.write(f"{year}: created {created} rows")

        self.stdout.write(self.style.SUCCESS(f"Finished. Created {total_created} calendar rows."))
