from __future__ import annotations

from io import StringIO
from unittest.mock import patch

from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import SimpleTestCase


class PrayerAutomationCommandTests(SimpleTestCase):
    @patch("Prayer_Time.management.commands.run_prayer_automation.process_automation_tick")
    def test_once_mode_processes_single_tick(self, process_tick_mock):
        stdout = StringIO()

        call_command("run_prayer_automation", "--once", stdout=stdout)

        process_tick_mock.assert_called_once_with()
        self.assertIn("Processed one prayer automation tick.", stdout.getvalue())

    @patch("Prayer_Time.management.commands.run_prayer_automation.run_automation_loop")
    def test_loop_mode_runs_foreground_worker(self, run_loop_mock):
        stdout = StringIO()

        call_command("run_prayer_automation", "--interval", "5", stdout=stdout)

        run_loop_mock.assert_called_once_with(interval_seconds=5)
        self.assertIn(
            "Starting prayer automation loop with a 5-second interval.",
            stdout.getvalue(),
        )

    def test_interval_must_be_positive(self):
        with self.assertRaisesMessage(CommandError, "--interval must be at least 1 second."):
            call_command("run_prayer_automation", "--interval", "0")
