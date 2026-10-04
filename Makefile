# Atalhos do projeto Navizin.
# Uso: `make help` lista os comandos.

COMPOSE ?= podman-compose
PY ?= python3

.PHONY: help up down logs ps server-install server-run server-test env

help: ## Lista os comandos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

env: ## Cria o .env a partir do .env.example (não sobrescreve)
	@test -f .env || cp .env.example .env && echo ".env pronto"

up: env ## Sobe PostgreSQL, Redis, MinIO, Jaeger e Prometheus
	$(COMPOSE) up -d

down: ## Derruba os containers (mantém os volumes)
	$(COMPOSE) down

logs: ## Mostra os logs de todos os serviços
	$(COMPOSE) logs -f

ps: ## Lista o estado dos containers
	$(COMPOSE) ps

server-install: ## Cria a venv do servidor e instala as dependências
	cd server && $(PY) -m venv .venv && .venv/bin/pip install -r requirements.txt

server-run: ## Sobe a API FastAPI em modo de desenvolvimento
	cd server && .venv/bin/uvicorn app.main:app --reload --port 8000

server-test: ## Roda os testes do servidor
	cd server && .venv/bin/pytest -q
