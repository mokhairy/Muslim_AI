# Move To Another Machine

This guide assumes the repository may be copied to another Mac or Linux machine and a new engineer or agent needs a reliable way to get it running.

## Do Not Copy The Current `.venv`

Recreate the virtual environment from scratch.

Reason:

- the existing `.venv/bin/pip` wrapper is stale and points at an older absolute path
- copied virtual environments are brittle across machines and Python installs

Recommended rebuild:

```bash
cd /path/to/Muslim_AI
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m pip install -r requirements-dev.txt
python -m pip install -r requirements-prod.txt
```

## Minimum App Startup

Local workstation startup:

```bash
export DJANGO_SETTINGS_MODULE=Muslim_AI.settings_development
export DJANGO_SECRET_KEY='dev-only-secret-key'
export DJANGO_ALLOWED_HOSTS='127.0.0.1,localhost'
python manage.py migrate
python manage.py runserver 127.0.0.1:8000
```

If you want the same background split used in this session:

```bash
DJANGO_SETTINGS_MODULE=Muslim_AI.settings_development \
DJANGO_SECRET_KEY='dev-only-secret-key' \
DJANGO_ALLOWED_HOSTS='*' \
./.venv/bin/python -m gunicorn Muslim_AI.wsgi:application --bind 0.0.0.0:8888

DJANGO_SETTINGS_MODULE=Muslim_AI.settings_development \
DJANGO_SECRET_KEY='dev-only-secret-key' \
DJANGO_ALLOWED_HOSTS='*' \
./.venv/bin/python manage.py run_prayer_automation --interval 20
```

## Required Local Expectations

### Browser geolocation

The prayer and qibla pages now depend heavily on browser geolocation.

Practical implications:

- `localhost` and `127.0.0.1` usually work for browser geolocation
- plain HTTP on arbitrary LAN hostnames or raw IPs may be blocked by the browser
- if serving to another device, use HTTPS or expect geolocation restrictions

### Local speaker playback

The app now includes a local audio target called `This machine speakers`.

Dependencies by OS:

- macOS: expects `/usr/bin/afplay`
- Linux: tries `ffplay`, then `paplay`, then `aplay`

If the machine lacks those tools, local broadcast will fail but network Cast/DLNA should still work.

## Static Files

Current behavior:

- debug static serving is enabled in `Muslim_AI/urls.py`
- `collectstatic` should still be run if using `gunicorn`

Do this after dependency setup:

```bash
./.venv/bin/python manage.py collectstatic --noinput
```

Expected generated path:

- `staticfiles/`

## macOS LaunchAgent Setup

If the target machine is macOS and you want the same persistent behavior:

1. Copy the example plist files from:
   - [doc/launchd/com.mkhairy.muslim-ai.web.plist.example](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/launchd/com.mkhairy.muslim-ai.web.plist.example)
   - [doc/launchd/com.mkhairy.muslim-ai.worker.plist.example](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/launchd/com.mkhairy.muslim-ai.worker.plist.example)
2. Replace absolute paths with the new machine's repo path.
3. Save them to `~/Library/LaunchAgents/`.
4. Load them:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mkhairy.muslim-ai.web.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mkhairy.muslim-ai.worker.plist
```

To unload:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.mkhairy.muslim-ai.web
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.mkhairy.muslim-ai.worker
```

## What To Verify First On A New Machine

Run these in order:

```bash
./.venv/bin/python -V
./.venv/bin/python manage.py migrate
./.venv/bin/python manage.py test Prayer_Time.tests Islamic_Calender.tests
./.venv/bin/python manage.py collectstatic --noinput
curl -I http://127.0.0.1:8000/
```

If using `gunicorn` on `8888`:

```bash
curl -I http://127.0.0.1:8888/
curl -I http://127.0.0.1:8888/static/Islamic_Calender/site.css
```

## Files A New Agent Should Read

1. [agent.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/agent.md)
2. [doc/current-state.md](/Users/mkhairy/Documents/GitHub/Muslim_AI/doc/current-state.md)
3. [Prayer_Time/views.py](/Users/mkhairy/Documents/GitHub/Muslim_AI/Prayer_Time/views.py)
4. [Prayer_Time/services.py](/Users/mkhairy/Documents/GitHub/Muslim_AI/Prayer_Time/services.py)
5. [Muslim_AI/urls.py](/Users/mkhairy/Documents/GitHub/Muslim_AI/Muslim_AI/urls.py)

## If Something Fails

Common likely causes:

- stale `.venv`
- browser geolocation restrictions
- missing local audio playback tool
- `collectstatic` not run
- LaunchAgent plist still points to the old machine's absolute paths
