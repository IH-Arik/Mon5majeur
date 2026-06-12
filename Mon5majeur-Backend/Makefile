.PHONY: help install dev test lint format migrate upgrade docker-up docker-down

help:
	@echo "Available commands:"
	@echo "  install     Install production dependencies"
	@echo "  dev         Install dev dependencies"
	@echo "  run         Start dev server"
	@echo "  test        Run all tests"
	@echo "  lint        Run ruff + mypy"
	@echo "  format      Auto-format with ruff"
	@echo "  migrate     Generate new Alembic migration"
	@echo "  upgrade     Apply pending migrations"
	@echo "  docker-up   Start services with docker-compose"
	@echo "  docker-down Stop docker services"

install:
	pip install -r requirements.txt

dev:
	pip install -r requirements-dev.txt

run:
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

test:
	pytest tests/ -v --cov=app --cov-report=term-missing

lint:
	ruff check .
	mypy app --ignore-missing-imports

format:
	ruff check . --fix
	ruff format .

migrate:
	alembic revision --autogenerate -m "$(msg)"

upgrade:
	alembic upgrade head

downgrade:
	alembic downgrade -1

docker-up:
	docker compose up -d

docker-down:
	docker compose down

docker-build:
	docker compose build
