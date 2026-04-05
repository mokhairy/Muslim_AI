# Current State

## Summary

This repository is a Django application centered on Islamic calendar, prayer-time lookup, qibla lookup, Quran, hadith, azkar, and related content pages. The most active recent work was in the `Prayer_Time` app.

The codebase currently runs locally and can also run as persistent background processes on macOS through `launchd`. That background setup was created for workstation use, not as the final shipping architecture.

## What Was Changed

### 1. Geolocation-first prayer lookup

The prayer lookup page was changed so the app prefers the browser's current location on first plain load.

Behavior now:

- initial GET to `/prayers/` requests browser geolocation
- on success, latitude and longitude are filled
- the form auto-submits immediately
- the same behavior was applied to the qibla page
- the manual `Use Current Location` buttons now also auto-submit

Files involved:

- [Prayer_Time/views.py](/Users/mkhairy/Documents/GitHub/Muslim_AI/Prayer_Time/views.py)
- [Prayer_Time/templates/Prayer_Time/home.html](/Users/mkhairy/Documents/GitHub/Muslim_AI/Prayer_Time/templates/Prayer_Time/home.html)
- [Prayer_Time/templates/Prayer_Time/qibla.html](/Users/mkhairy/Documents/GitHub/Muslim_AI/Prayer_Time/templates/Prayer_Time/qibla.html)

### 2. Prayer-date default fix

There was a client-side failure mode where the current-location button appeared broken because the prayer lookup form had a blank date input. The browser refused submission because `prayer_date` is required.

Fix:

- default `prayer_date` now comes from `timezone.localdate()` in the view

This is essential because the geolocation auto-submit path depends on the form being valid.

### 3. Local speaker target

Broadcasting previously assumed only Cast and DLNA devices. A built-in local target was added so adhan can be played on the same computer running the app.

Current local target:

- device id: `local:system_output`
- display name: `This machine speakers`
- protocol: `local`

Current behavior:

- local target is created automatically if missing
- local target remains available during device scans
- if there is no saved selected speaker list, the local target becomes the default selection

### 4. Static files under gunicorn

When the app was moved from `runserver` to background `gunicorn`, the HTML rendered but CSS was missing. The reason was simple:

- `runserver` serves app static files automatically in development
- `gunicorn` does not
- no static route or middleware had been added for the local background setup

Fix:

- `Muslim_AI/urls.py` now serves static files when `DEBUG` is enabled
- `collectstatic` was executed and `staticfiles/` was created

This makes the local `gunicorn` setup usable on the workstation.

## Background Service Setup

Two macOS user LaunchAgents were created outside the repo:

- `~/Library/LaunchAgents/com.mkhairy.muslim-ai.web.plist`
- `~/Library/LaunchAgents/com.mkhairy.muslim-ai.worker.plist`

Equivalent example files are now stored in:

- [doc/launchd/com.mkhairy.muslim-ai.web.plist.example](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/launchd/com.mkhairy.muslim-ai.web.plist.example)
- [doc/launchd/com.mkhairy.muslim-ai.worker.plist.example](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/launchd/com.mkhairy.muslim-ai.worker.plist.example)

Service split:

- web
  - `gunicorn`
  - binds `0.0.0.0:8888`
- worker
  - `manage.py run_prayer_automation --interval 20`

Important:

- Both services were stopped at the user's request on `2026-04-05`.
- The plist files still exist.
- They can be loaded again with `launchctl bootstrap ...`.

## Runtime/Environment Notes

### Python and dependencies

- Python interpreter: `./.venv/bin/python`
- `gunicorn` was installed into the virtualenv from `requirements-prod.txt`

### Virtualenv warning

The `pip` entry point inside `.venv/bin/` is stale and points to an older project path. This was observed directly:

- `./.venv/bin/pip ...` failed
- `./.venv/bin/python -m pip ...` worked

Recommendation:

- do not trust the copied `.venv` on another machine
- recreate `.venv` from scratch

### Current generated directories

These exist now and are generated artifacts:

- `staticfiles/`
- `.playwright-mcp/`

They should not be treated as source-of-truth application code.

## Validation Performed

These checks were run successfully during this session:

```bash
./.venv/bin/python manage.py test Prayer_Time.tests
./.venv/bin/python manage.py test Prayer_Time.tests Islamic_Calender.tests
./.venv/bin/python -m ruff check Prayer_Time/services.py Prayer_Time/views.py Prayer_Time/tests.py
./.venv/bin/python manage.py collectstatic --noinput
```

HTTP checks that passed when services were active:

- `curl -I http://127.0.0.1:8888/`
- `curl -I http://127.0.0.1:8888/static/Islamic_Calender/site.css`

## Known Risks / Non-final Decisions

### Development settings are still being used

The local background service was deliberately run with:

- `DJANGO_SETTINGS_MODULE=Muslim_AI.settings_development`
- `DJANGO_ALLOWED_HOSTS=*`
- `DJANGO_SECRET_KEY=dev-only-secret-key`

That is acceptable for local workstation use only. It is not the right production posture.

### Static file approach is local-development oriented

Serving static files from `urls.py` under `DEBUG` is convenient for a workstation service. It is not the long-term deployment pattern for public hosting.

### Local speaker playback is OS-dependent

Local playback was implemented pragmatically:

- macOS: `afplay`
- Linux: `ffplay`, then `paplay`, then `aplay`

This is useful locally, but it is not a universal media subsystem abstraction.

## Best Next Steps

If a new agent continues from here:

1. Read [agent.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/agent.md).
2. Read [move-to-new-machine.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/move-to-new-machine.md).
3. Decide whether the target is:
   - local workstation continuation
   - another workstation migration
   - actual deployment to users
4. If the goal is shipping, use [shipping-guide.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/shipping-guide.md) and do not preserve the current development-only launchd design unchanged.
