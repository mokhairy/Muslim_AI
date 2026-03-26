.PHONY: test lint format-check format serve worker serve-prod collectstatic

test:
	./.venv/bin/python manage.py test

lint:
	./.venv/bin/python -m ruff check .

format-check:
	./.venv/bin/python -m ruff format --check .

format:
	./.venv/bin/python -m ruff check --fix .
	./.venv/bin/python -m ruff format .

serve:
	DJANGO_SETTINGS_MODULE=Muslim_AI.settings_development ./.venv/bin/python manage.py runserver

worker:
	DJANGO_SETTINGS_MODULE=Muslim_AI.settings_development ./.venv/bin/python manage.py run_prayer_automation --interval $${PRAYER_AUTOMATION_INTERVAL:-20}

serve-prod:
	DJANGO_SETTINGS_MODULE=Muslim_AI.settings_production ./.venv/bin/python -m gunicorn Muslim_AI.wsgi:application --bind 0.0.0.0:$${PORT:-8000}

collectstatic:
	DJANGO_SETTINGS_MODULE=Muslim_AI.settings_production ./.venv/bin/python manage.py collectstatic --noinput
