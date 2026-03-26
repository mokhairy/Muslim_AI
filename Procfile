web: ./.venv/bin/python -m gunicorn Muslim_AI.wsgi:application --bind 0.0.0.0:${PORT:-8000}
worker: ./.venv/bin/python manage.py run_prayer_automation --interval ${PRAYER_AUTOMATION_INTERVAL:-20}
