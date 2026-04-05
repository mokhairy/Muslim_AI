# Agent Notes

This file is the shortest reliable entry point for the next agent working on this repository.

## Project Shape

- Framework: Django 6
- Python: `.venv/bin/python` currently resolves to Python `3.14.3`
- Main project package: `Muslim_AI`
- Main feature area touched in this session: `Prayer_Time`
- Local database: `db.sqlite3`

## What Changed In This Session

### Prayer workflow

- The prayer lookup and qibla pages now default to browser geolocation on first plain load.
- The `Use Current Location` buttons now auto-submit the form after coordinates are captured.
- The prayer lookup form now defaults `prayer_date` to `timezone.localdate()` so browser validation does not block geolocation submit.

### Broadcasting

- A built-in local audio target was added:
  - device id: `local:system_output`
  - display name: `This machine speakers`
- If there are no saved selected devices, this local target is selected by default.
- Local playback is handled in `Prayer_Time/services.py` and currently uses:
  - macOS: `afplay`
  - Linux fallback chain: `ffplay`, `paplay`, `aplay`

### Background execution

- The app was configured to run under macOS `launchd` as two user LaunchAgents:
  - web: `gunicorn` on `0.0.0.0:8888`
  - worker: `manage.py run_prayer_automation --interval 20`
- The live LaunchAgent files exist outside the repo in:
  - `~/Library/LaunchAgents/com.mkhairy.muslim-ai.web.plist`
  - `~/Library/LaunchAgents/com.mkhairy.muslim-ai.worker.plist`
- Repo copies of those definitions now exist under `doc/launchd/`.

### Static files

- CSS was missing under background `gunicorn` because `/static/...` was not being served.
- Fix applied:
  - `Muslim_AI/urls.py` now serves static files in `DEBUG`
  - `collectstatic` was run and `staticfiles/` was populated

## Current Runtime State

- The background web and worker services were explicitly stopped on `2026-04-05`.
- Port `8888` is no longer listening.
- LaunchAgent plist files still exist on disk, but they are currently unloaded.

## Important Caveats

- The virtualenv `pip` wrapper is stale. Running `./.venv/bin/pip ...` failed because its shebang points at an old project path.
- Use `./.venv/bin/python -m pip ...` instead.
- On a new machine, recreate `.venv` rather than copying it.
- Current background service setup uses `Muslim_AI.settings_development` and `DJANGO_ALLOWED_HOSTS=*`.
- That is acceptable for local workstation use, but not the correct way to ship publicly.

## Best Immediate Starting Points

If you need to continue app work, read these first:

1. [doc/README.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/README.md)
2. [doc/current-state.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/current-state.md)
3. [doc/move-to-new-machine.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/move-to-new-machine.md)
4. [doc/shipping-guide.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/shipping-guide.md)

Then inspect these code paths:

- [Prayer_Time/views.py](/Users/mkhairy/Documents/GitHub/Muslim_AI/Prayer_Time/views.py)
- [Prayer_Time/services.py](/Users/mkhairy/Documents/GitHub/Muslim_AI/Prayer_Time/services.py)
- [Prayer_Time/templates/Prayer_Time/home.html](/Users/mkhairy/Documents/GitHub/Muslim_AI/Prayer_Time/templates/Prayer_Time/home.html)
- [Prayer_Time/templates/Prayer_Time/qibla.html](/Users/mkhairy/Documents/GitHub/Muslim_AI/Prayer_Time/templates/Prayer_Time/qibla.html)
- [Muslim_AI/urls.py](/Users/mkhairy/Documents/GitHub/Muslim_AI/Muslim_AI/urls.py)

## Commands That Were Useful

```bash
./.venv/bin/python manage.py test Prayer_Time.tests Islamic_Calender.tests
./.venv/bin/python -m ruff check Prayer_Time/services.py Prayer_Time/views.py Prayer_Time/tests.py
./.venv/bin/python manage.py collectstatic --noinput
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mkhairy.muslim-ai.web.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mkhairy.muslim-ai.worker.plist
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.mkhairy.muslim-ai.web
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.mkhairy.muslim-ai.worker
```
