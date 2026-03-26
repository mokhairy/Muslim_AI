from __future__ import annotations

import os
from unittest.mock import patch

from django.test import SimpleTestCase

from Muslim_AI.settings_utils import env_bool, env_list


class SettingsUtilsTests(SimpleTestCase):
    def test_env_bool_returns_default_when_missing(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertFalse(env_bool("DJANGO_DEBUG"))
            self.assertTrue(env_bool("DJANGO_DEBUG", default=True))

    def test_env_bool_parses_truthy_values(self):
        with patch.dict(os.environ, {"DJANGO_DEBUG": "YeS"}, clear=True):
            self.assertTrue(env_bool("DJANGO_DEBUG"))

    def test_env_list_splits_and_trims_values(self):
        with patch.dict(
            os.environ,
            {"DJANGO_ALLOWED_HOSTS": "localhost, 127.0.0.1,example.com ,, "},
            clear=True,
        ):
            self.assertEqual(
                env_list("DJANGO_ALLOWED_HOSTS"),
                ["localhost", "127.0.0.1", "example.com"],
            )
