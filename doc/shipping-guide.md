# Shipping Guide

This document describes the best way to ship this application properly, not just how it was made to run on a developer workstation.

## Short Answer

The best shipping path is:

1. keep Django as the app backend
2. run `gunicorn` behind a reverse proxy
3. use `Muslim_AI.settings_production`
4. serve static files through a proper web server or object storage/CDN
5. run the prayer automation worker as a separate managed process
6. use real environment variables and secrets
7. do not ship the current development LaunchAgent setup as the public deployment strategy

## Why The Current Local Setup Should Not Be The Final Deployment

Current local background setup characteristics:

- uses `settings_development`
- sets `DJANGO_ALLOWED_HOSTS=*`
- uses a development secret key
- serves static files via Django URL patterns
- relies on workstation tools like `afplay`
- runs as user-level macOS LaunchAgents

That is useful for local persistence, but it is not robust or secure enough for public deployment.

## Recommended Deployment Architecture

### Application layout

Use two long-running processes:

- web
  - `gunicorn Muslim_AI.wsgi:application`
- worker
  - `python manage.py run_prayer_automation --interval 20`

### Reverse proxy

Put one of these in front of `gunicorn`:

- Nginx
- Caddy
- Traefik

Responsibilities of the proxy:

- HTTPS termination
- serving static files
- host routing
- optional compression and caching

### Static files

Best production choices:

- Nginx/Caddy serving files from `STATIC_ROOT`
- or object storage + CDN if the app grows

Current debug-only static route should not be your production static strategy.

## Best Hosting Options

### Option 1: VPS / dedicated server

Best if you need:

- long-lived worker process
- predictable network access for DLNA/Cast discovery
- control over background jobs

Recommended stack:

- Ubuntu server
- Python virtualenv
- systemd units for web and worker
- Nginx or Caddy

This is the cleanest equivalent of the local split-process design.

### Option 2: Containerized deployment

Best if you want reproducibility and cleaner migration between machines.

Recommended stack:

- Dockerfile for the web app
- separate worker container
- reverse proxy container
- volume or managed database if SQLite is replaced

This is likely the best general shipping direction if multiple environments are expected.

### Option 3: PaaS

Possible, but with caveats.

Good for:

- web frontend/API deployment

Potential problems:

- long-running worker process support varies
- local-network speaker discovery and local machine playback do not map cleanly to PaaS

If the app's value depends on local network discovery and workstation audio output, a PaaS is usually not the best fit for the full product.

## Database Recommendation

Current database:

- SQLite

For public shipping, prefer:

- PostgreSQL

Reasons:

- better concurrency
- safer write behavior
- easier backup and migration story
- better fit for multi-process deployments

SQLite is acceptable for:

- local workstation use
- small single-user setups
- demos

## Secrets and Configuration

Before shipping, require:

- strong `DJANGO_SECRET_KEY`
- explicit `DJANGO_ALLOWED_HOSTS`
- explicit `DJANGO_CSRF_TRUSTED_ORIGINS`
- production `DJANGO_SETTINGS_MODULE=Muslim_AI.settings_production`
- review of `DJANGO_SECURE_SSL_REDIRECT`
- review of HSTS settings

## Background Worker Strategy

The prayer automation worker is already conceptually separated from the web process. Preserve that.

Production service manager options:

- Linux: `systemd`
- containers: orchestrator-managed worker
- macOS local use: `launchd`

Do not collapse the worker back into the web process.

## Audio / Speaker Feature Considerations

These features affect shipping decisions heavily:

- Cast discovery
- DLNA discovery
- local machine playback

Implications:

- local machine playback is only meaningful when the app runs on a user-controlled machine
- Cast/DLNA discovery usually expects local network presence
- cloud hosting can break or severely limit those features

That leads to two realistic product directions:

### Direction A: local companion app

Treat this as a workstation or home-server app.

Best deployment pattern:

- packaged local install
- background service
- local browser UI

### Direction B: split architecture

Separate public web features from local-device control features.

Possible split:

- cloud-hosted Django app for calendar, prayer lookup, Quran, hadith
- local agent/service on the user's machine for speaker discovery and playback

This is more work, but it is the cleanest long-term product architecture if remote access matters.

## Recommended Immediate Shipping Plan

If shipping soon with minimal rewrite:

1. keep the product as a local/private deployment target first
2. move from `settings_development` to `settings_production`
3. switch to PostgreSQL if more than one process/user matters
4. serve static files through Nginx or Caddy
5. run web + worker under `systemd` or Docker Compose
6. keep local speaker and DLNA/Cast features only on machines that are actually on the target network

## Recommended Documentation / Ops Additions

Before public or team shipping, add:

- Dockerfile
- `docker-compose.yml` or deployment manifests
- `.env.production.example`
- systemd unit files or container equivalents
- backup/restore notes for the database
- health check endpoint
- structured logging plan
- explicit static/media deployment plan

## Bottom Line

The best way to ship this application depends on whether the speaker-control features are core:

- if yes, ship it as a local/private service first
- if no, separate those features and host the rest normally

The current workstation `launchd` solution is a useful operational bridge, not the final production design.
