# Muslim_AI

`Muslim_AI` is a Django project with an `Islamic_Calender` package that powers the Islamic Calendar experience and displays Gregorian and Hijri dates side by side.

## Features

- Convert Gregorian dates to Hijri dates
- Convert Hijri dates to Gregorian dates
- Switch between `Umm al-Qura` and arithmetic `tabular` calendar modes
- Browse monthly calendars with both date systems shown together
- Check daily prayer times by selected date and current browser coordinates
- Stream adhan recordings from remote audio links inside the prayer-times page
- Discover Cast and DLNA smart speakers on the local network and test-broadcast adhan audio
- Run server-side automatic adhan playback when the live location time matches saved prayer times
- Use `Umm al-Qura` as the default app mode for dates from `1924-08-01` through `2077-11-16`
- Keep the arithmetic `tabular` mode available for the full built-in range from `0622-07-19` through `2100-12-31`
- Compare Ramadan last-ten-day trends for the selected calendar mode

## Run locally

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m pip install -r requirements-dev.txt
export DJANGO_SETTINGS_MODULE=Muslim_AI.settings_development
export DJANGO_SECRET_KEY='dev-only-secret-key'
python manage.py migrate
python manage.py runserver
```

## Configuration

Settings now read from environment variables instead of hardcoded values in source:

- `DJANGO_SETTINGS_MODULE`: use `Muslim_AI.settings_development` locally or `Muslim_AI.settings_production` in deployment
- `DJANGO_SECRET_KEY`: Django secret key
- `DJANGO_DEBUG`: `1` or `true` for local debug mode
- `DJANGO_ALLOWED_HOSTS`: comma-separated hostnames for deployment
- `DJANGO_TIME_ZONE`: optional override, defaults to `Asia/Muscat`
- `DJANGO_CSRF_TRUSTED_ORIGINS`: comma-separated production origins
- `DJANGO_SECURE_SSL_REDIRECT`: enable HTTPS redirect in production
- `DJANGO_SECURE_HSTS_SECONDS`: HSTS max age in production

## Quality Checks

Development checks now use `ruff` for linting and formatting.

```bash
make lint
make format-check
make test
```

To auto-fix lint issues and format the code:

```bash
make format
```

## Deployment

Example environment variables are in `.env.example`.

Production setup now has an explicit process split:

- `web`: WSGI app served by `gunicorn`
- `worker`: prayer automation loop via `run_prayer_automation`

Install production dependencies:

```bash
python -m pip install -r requirements.txt
python -m pip install -r requirements-prod.txt
```

Run the two processes manually:

```bash
DJANGO_SETTINGS_MODULE=Muslim_AI.settings_production ./.venv/bin/python -m gunicorn Muslim_AI.wsgi:application --bind 0.0.0.0:8000
DJANGO_SETTINGS_MODULE=Muslim_AI.settings_production ./.venv/bin/python manage.py run_prayer_automation --interval 20
```

For Railway deployments, `railway.toml` now runs `collectstatic` at build time and serves static files in production through `WhiteNoise`.

Or use the helper targets:

```bash
make serve
make worker
make serve-prod
make collectstatic
```

## Calendar modes

- `Umm al-Qura` is the default mode in the UI. It follows the Saudi civil Hijri calendar and is supported for Gregorian dates `1924-08-01` through `2077-11-16`.
- `Tabular` remains available as an alternate mode. It uses fixed arithmetic month rules across the wider built-in range.

## Prayer times

- The `/prayers/` page uses browser geolocation or manual coordinates plus a selected date to fetch daily prayer times from the AlAdhan API.
- The same page includes embedded audio players for remote adhan streams.
- The automation section can scan the local network for Google Cast devices and DLNA / UPnP media renderers, then save selected targets for manual or automatic adhan playback.
- Automatic playback now runs from an explicit management command instead of a hidden background thread inside `runserver`.

Run one automation tick:

```bash
python manage.py run_prayer_automation --once
```

Run the foreground automation worker:

```bash
python manage.py run_prayer_automation --interval 20
```

## Optional full data population

The `CalendarDate` model and population command remain tabular-only. To pre-populate stored tabular date rows up to 2100, run:

```bash
python manage.py populate_calendar_dates
```
