from __future__ import annotations

from django.core.management.base import BaseCommand, CommandError

from Prayer_Time.automation import process_automation_tick, run_automation_loop


class Command(BaseCommand):
    help = "Run the prayer automation worker once or in a foreground loop."

    def add_arguments(self, parser) -> None:
        parser.add_argument(
            "--once",
            action="store_true",
            help="Process one automation tick and exit.",
        )
        parser.add_argument(
            "--interval",
            type=int,
            default=20,
            help="Seconds to wait between ticks when running continuously.",
        )

    def handle(self, *args, **options) -> None:
        interval = options["interval"]
        if interval < 1:
            raise CommandError("--interval must be at least 1 second.")

        if options["once"]:
            process_automation_tick()
            self.stdout.write(self.style.SUCCESS("Processed one prayer automation tick."))
            return

        self.stdout.write(
            self.style.WARNING(
                "Starting prayer automation loop with a "
                f"{interval}-second interval. Press Ctrl+C to stop."
            )
        )
        try:
            run_automation_loop(interval_seconds=interval)
        except KeyboardInterrupt:
            self.stdout.write(self.style.WARNING("Prayer automation loop stopped."))
