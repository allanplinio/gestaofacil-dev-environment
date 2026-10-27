.DEFAULT_GOAL := help
.PHONY: help doctor setup up down restart ps logs build rebuild clean hosts \
	        install install-api install-nfe install-fe \
	        migrate migrate-api migrate-nfe seed-api seed-nfe \
	        shell-api shell-nfe shell-fe db-api db-nfe redis-cli \
	        test test-api test-nfe test-fe logs-api logs-nfe logs-fe logs-worker logs-nginx \
	        status-real import-legacy cache-clear cache-clear-api cache-clear-nfe

# ═══════════════════════════════════════════════════════════════════════════
#  GestãoFácil — Ambiente de Desenvolvimento Local
# ═══════════════════════════════════════════════════════════════════════════

BLUE  := \033[0;34m
GREEN := \033[0;32m
YELL  := \033[0;33m
RED   := \033[0;31m
NC    := \033[0m

DC := docker compose

help:
	@printf "$(BLUE)╔════════════════════════════════════════════════════════════════╗$(NC)\n"
	@printf "$(BLUE)║   GestãoFácil — Ambiente de Desenvolvimento Local              ║$(NC)\n"
	@printf "$(BLUE)╚════════════════════════════════════════════════════════════════╝$(NC)\n\n"
	@printf "$(GREEN)Primeira vez:$(NC)\n"
	@printf "  $(YELL)make doctor$(NC)        Checa conflito de porta ANTES de subir\n"
	@printf "  $(YELL)make hosts$(NC)         Mostra as linhas para o /etc/hosts\n"
	@printf "  $(YELL)make setup$(NC)         Sobe tudo + instala deps + migra os dois bancos\n\n"
	@printf "$(GREEN)Dia a dia:$(NC)\n"
	@printf "  $(YELL)make up$(NC) / $(YELL)down$(NC) / $(YELL)restart$(NC) / $(YELL)ps$(NC)\n"
	@printf "  $(YELL)make status-real$(NC)   Estado VERIFICADO (migrations aplicadas, fila, proxy)\n"
	@printf "  $(YELL)make logs$(NC)          Logs de tudo (ou logs-api, logs-nfe, logs-fe,\n"
	@printf "                      logs-worker, logs-nginx)\n\n"
	@printf "$(GREEN)Dependências e banco:$(NC)\n"
	@printf "  $(YELL)make install$(NC)       composer + npm nos três projetos\n"
	@printf "  $(YELL)make migrate$(NC)       Migrations dos dois bancos\n"
	@printf "  $(YELL)make seed-api$(NC) / $(YELL)seed-nfe$(NC)\n"
	@printf "  $(YELL)make cache-clear$(NC)   Limpa cache dos dois servidores Laravel\n"
	@printf "  $(YELL)make db-api$(NC) / $(YELL)db-nfe$(NC)   psql dentro do container\n"
	@printf "  $(YELL)make redis-cli$(NC)\n\n"
	@printf "$(GREEN)Shell e testes:$(NC)\n"
	@printf "  $(YELL)make shell-api$(NC) / $(YELL)shell-nfe$(NC) / $(YELL)shell-fe$(NC)\n"
	@printf "  $(YELL)make test$(NC)          todas as suites (api + nfe + front)\n"
	@printf "  $(YELL)make test-api$(NC) / $(YELL)test-nfe$(NC) / $(YELL)test-fe$(NC)\n"
	@printf "  $(YELL)make test-api ARGS=\"--filter=Nome\"$(NC)  um arquivo ou filtro\n\n"
	@printf "$(GREEN)Manutenção:$(NC)\n"
	@printf "  $(YELL)make build$(NC)         Rebuild das imagens\n"
	@printf "  $(YELL)make rebuild$(NC)       Rebuild sem cache\n"
	@printf "  $(YELL)make import-legacy$(NC) Traz os dados dos volumes da stack antiga\n"
	@printf "  $(RED)make clean$(NC)         Remove containers E VOLUMES (apaga os bancos)\n\n"
	@printf "$(GREEN)URLs:$(NC)\n"
	@printf "  Frontend       http://gestaofacil.localhost\n"
	@printf "  API Gestão     http://api.gestaofacil.localhost\n"
	@printf "  API NFe        http://nfe.gestaofacil.localhost\n\n"

# ═══════════════════════════════════════════════════════════════════════════
#  Pré-voo
# ═══════════════════════════════════════════════════════════════════════════

doctor:
	@printf "$(BLUE)── Checagem de ambiente ──$(NC)\n\n"
	@test -f .env || { printf "$(RED)FALTA .env$(NC)  → rode: cp .env.example .env\n"; exit 1; }
	@printf "$(GREEN)ok$(NC)  .env existe\n"
	@for d in ../gestaofacil-fe ../gestaofacil-api ../nfe-api; do \
		test -d $$d && printf "$(GREEN)ok$(NC)  $$d encontrado\n" \
		            || printf "$(RED)ERRO$(NC)  $$d NAO existe — clone os 3 projetos na mesma pasta\n"; \
	done
	@printf "\n$(BLUE)── Portas ──$(NC)\n"
	@set -a; . ./.env; set +a; \
	for p in "$${HTTP_PORT:-80}:proxy" "$${GESTAOFACIL_DB_PORT:-5432}:gestaofacil_db" \
	         "$${NFE_DB_PORT:-5433}:nfe_db" "$${REDIS_PORT:-6379}:redis"; do \
		port=$${p%%:*}; svc=$${p##*:}; \
		if ss -ltn 2>/dev/null | grep -qE "[:.]$$port[[:space:]]"; then \
			owner=$$(docker ps --format '{{.Names}} {{.Ports}}' | grep -E ":$$port->" | awk '{print $$1}' | head -1); \
			if [ -n "$$owner" ]; then printf "$(YELL)uso$(NC)   %-6s ocupada por container $$owner\n" "$$port"; \
			else printf "$(RED)CONFLITO$(NC) %-6s ($$svc) ocupada por algo FORA do compose\n" "$$port"; fi; \
		else printf "$(GREEN)livre$(NC) %-6s ($$svc)\n" "$$port"; fi; \
	done
	@printf "\n$(BLUE)── docker-proxy orfao ──$(NC)\n"
	@nets=$$(docker network ls -q | xargs -r docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null | cut -d. -f1-2 | sort -u); \
	found=0; \
	for pid in $$(pgrep -f docker-proxy 2>/dev/null); do \
		line=$$(tr '\0' ' ' < /proc/$$pid/cmdline 2>/dev/null); \
		cip=$$(echo "$$line" | sed -n 's/.*-container-ip \([0-9.]*\).*/\1/p'); \
		hp=$$(echo "$$line" | sed -n 's/.*-host-port \([0-9]*\).*/\1/p'); \
		[ -z "$$cip" ] && continue; \
		pre=$$(echo "$$cip" | cut -d. -f1-2); \
		if ! echo "$$nets" | grep -q "^$$pre$$"; then \
			printf "$(RED)ORFAO$(NC) pid=%-8s porta=%-6s aponta para rede inexistente %s\n" "$$pid" "$$hp" "$$cip"; found=1; \
		fi; \
	done; \
	if [ $$found -eq 1 ]; then \
		printf "\n  Sao processos de containers ja removidos que continuam segurando a porta.\n"; \
		printf "  Libere com: $(YELL)sudo kill <pid>$(NC)\n"; \
	else printf "$(GREEN)ok$(NC)  nenhum docker-proxy orfao\n"; fi
	@printf "\n$(BLUE)── Postgres nativo no host ──$(NC)\n"
	@if ss -ltn 2>/dev/null | grep -qE '127.0.0.1:5432[[:space:]]'; then \
		printf "$(YELL)aviso$(NC) ha um PostgreSQL do sistema em 127.0.0.1:5432.\n"; \
		printf "        Se GESTAOFACIL_DB_PORT=5432 o container nao sobe.\n"; \
		printf "        Use $(YELL)GESTAOFACIL_DB_PORT=5442$(NC) no .env, ou pare com:\n"; \
		printf "        sudo systemctl stop postgresql\n"; \
	else printf "$(GREEN)ok$(NC)  porta 5432 do host livre\n"; fi
	@printf "\n$(BLUE)── Resolucao de *.localhost ──$(NC)\n"
	@if getent hosts gestaofacil.localhost >/dev/null 2>&1; then \
		printf "$(GREEN)ok$(NC)  gestaofacil.localhost resolve\n"; \
	else printf "$(YELL)aviso$(NC) nao resolve — rode $(YELL)make hosts$(NC)\n"; fi

hosts:
	@printf "Adicione ao /etc/hosts (sudo):\n\n"
	@printf "127.0.0.1  gestaofacil.localhost api.gestaofacil.localhost nfe.gestaofacil.localhost\n\n"
	@printf "Comando pronto:\n"
	@printf "  echo '127.0.0.1  gestaofacil.localhost api.gestaofacil.localhost nfe.gestaofacil.localhost' | sudo tee -a /etc/hosts\n"

# ═══════════════════════════════════════════════════════════════════════════
#  Ciclo de vida
# ═══════════════════════════════════════════════════════════════════════════

setup: doctor up install migrate
	@printf "\n$(GREEN)Ambiente pronto.$(NC) Valide com: $(YELL)make status-real$(NC)\n"

up:
	@test -f .env || cp .env.example .env
	$(DC) up -d
	@printf "$(GREEN)Containers no ar.$(NC) Verifique de fato com: make status-real\n"

down:
	$(DC) down

restart:
	$(DC) restart

ps:
	$(DC) ps

build:
	$(DC) build

rebuild:
	$(DC) build --no-cache

clean:
	@printf "$(RED)Isso APAGA os bancos gestaofacil_pgdata e nfe_pgdata.$(NC)\n"
	@printf "Digite 'apagar' para confirmar: "; read ans; [ "$$ans" = "apagar" ] || { echo "cancelado"; exit 1; }
	$(DC) down -v

# ═══════════════════════════════════════════════════════════════════════════
#  Logs
# ═══════════════════════════════════════════════════════════════════════════

logs:
	$(DC) logs -f --tail=100

logs-api:
	$(DC) logs -f --tail=100 gestaofacil_api

logs-nfe:
	$(DC) logs -f --tail=100 nfe_api

logs-worker:
	$(DC) logs -f --tail=100 nfe_worker

logs-fe:
	$(DC) logs -f --tail=100 gestaofacil_fe

logs-nginx:
	$(DC) logs -f --tail=100 gestaofacil_nginx

# ═══════════════════════════════════════════════════════════════════════════
#  Dependências
# ═══════════════════════════════════════════════════════════════════════════

install: install-api install-nfe install-fe

install-api:
	$(DC) exec gestaofacil_api composer install

install-nfe:
	$(DC) exec nfe_api composer install

install-fe:
	$(DC) exec gestaofacil_fe npm install

# ═══════════════════════════════════════════════════════════════════════════
#  Cache
# ═══════════════════════════════════════════════════════════════════════════

cache-clear: cache-clear-api cache-clear-nfe
	@printf "$(GREEN)Cache dos dois servidores Laravel limpo.$(NC)\n"

cache-clear-api:
	@printf "Limpando cache de gestaofacil-api...\n"
	$(DC) exec gestaofacil_api php artisan config:cache
	$(DC) exec gestaofacil_api php artisan cache:clear
	@printf "$(GREEN)✓ gestaofacil-api$(NC)\n"

cache-clear-nfe:
	@printf "Limpando cache de nfe-api...\n"
	$(DC) exec nfe_api php artisan config:cache
	$(DC) exec nfe_api php artisan cache:clear
	@printf "$(GREEN)✓ nfe-api$(NC)\n"

# ═══════════════════════════════════════════════════════════════════════════
#  Banco de dados
# ═══════════════════════════════════════════════════════════════════════════

migrate: migrate-api migrate-nfe

migrate-api:
	$(DC) exec gestaofacil_api php artisan migrate --force

migrate-nfe:
	$(DC) exec nfe_api php artisan migrate --force

seed-api:
	$(DC) exec gestaofacil_api php artisan db:seed

seed-nfe:
	$(DC) exec nfe_api php artisan db:seed

db-api:
	@set -a; . ./.env; set +a; \
	$(DC) exec gestaofacil_db psql -U $${GESTAOFACIL_DB_USERNAME:-gestaofacil} -d $${GESTAOFACIL_DB_DATABASE:-gestaofacil}

db-nfe:
	@set -a; . ./.env; set +a; \
	$(DC) exec nfe_db psql -U $${NFE_DB_USERNAME:-nfe_api} -d $${NFE_DB_DATABASE:-nfe_api}

redis-cli:
	$(DC) exec gestaofacil_redis redis-cli

# ═══════════════════════════════════════════════════════════════════════════
#  Shell e testes
# ═══════════════════════════════════════════════════════════════════════════

shell-api:
	$(DC) exec gestaofacil_api bash

shell-nfe:
	$(DC) exec nfe_api bash

shell-fe:
	$(DC) exec gestaofacil_fe sh

# As variaveis de ambiente do container (docker-compose) tem precedencia sobre o
# phpunit.xml do projeto. Sem sobrescrever aqui, a suite aponta para o banco de
# DESENVOLVIMENTO - e o guarda de seguranca do TestCase aborta tudo, ou pior, um
# migrate:fresh limparia o banco de trabalho. Por isso cada alvo forca o ambiente
# de teste explicitamente, e cria o banco _test se ainda nao existir.
# APP_CONFIG_CACHE aponta para um arquivo inexistente: com o config cacheado
# (bootstrap/cache/config.php, gerado pelo cache-clear) o Laravel ignoraria as -e.
TEST_ENV_API := -e APP_CONFIG_CACHE=/tmp/sem-config-cache.php \
	-e APP_ENV=testing -e DB_DATABASE=gestaofacil_test \
	-e QUEUE_CONNECTION=sync -e CACHE_STORE=array -e CACHE_DRIVER=array -e SESSION_DRIVER=array

# NFE_SEFAZ_GATEWAY=fake: o .env deste diretorio pode deixar o container em `real`
# (SEFAZ homologacao de verdade), e o phpunit.xml do nfe-api nao fixa o gateway.
# Sem isto, teste que nao injeta o fake resolveria o RealSefazGateway.
TEST_ENV_NFE := -e APP_CONFIG_CACHE=/tmp/sem-config-cache.php \
	-e APP_ENV=testing -e DB_DATABASE=nfe_api_test \
	-e QUEUE_CONNECTION=sync -e CACHE_STORE=array -e CACHE_DRIVER=array -e SESSION_DRIVER=array \
	-e NFE_SEFAZ_GATEWAY=fake

# Rode um arquivo ou um filtro:  make test-api ARGS="--filter=ConfiguracaoFiscal"
ARGS ?=

test-api:
	@$(DC) exec -T gestaofacil_db psql -U gestaofacil -d postgres \
		-c "CREATE DATABASE gestaofacil_test OWNER gestaofacil" >/dev/null 2>&1 || true
	$(DC) exec $(TEST_ENV_API) gestaofacil_api php artisan test $(ARGS)

test-nfe:
	@$(DC) exec -T nfe_db psql -U nfe_api -d postgres \
		-c "CREATE DATABASE nfe_api_test OWNER nfe_api" >/dev/null 2>&1 || true
	$(DC) exec $(TEST_ENV_NFE) nfe_api php artisan test $(ARGS)

test-fe:
	$(DC) exec gestaofacil_fe sh -c 'cd /app && npm run type-check && npm run build'

test: test-api test-nfe test-fe

# ═══════════════════════════════════════════════════════════════════════════
#  Verificação real (nao confie em "subiu", confira o que responde)
# ═══════════════════════════════════════════════════════════════════════════

status-real:
	@set -a; . ./.env; set +a; \
	printf "$(BLUE)── Containers ──$(NC)\n"; \
	$(DC) ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'; \
	printf "\n$(BLUE)── Migrations aplicadas vs arquivos no disco ──$(NC)\n"; \
	for pair in "gestaofacil_api:gestaofacil_db:$${GESTAOFACIL_DB_USERNAME:-gestaofacil}:$${GESTAOFACIL_DB_DATABASE:-gestaofacil}:../gestaofacil-api" \
	            "nfe_api:nfe_db:$${NFE_DB_USERNAME:-nfe_api}:$${NFE_DB_DATABASE:-nfe_api}:../nfe-api"; do \
		app=$$(echo $$pair | cut -d: -f1); dbs=$$(echo $$pair | cut -d: -f2); \
		usr=$$(echo $$pair | cut -d: -f3); dbn=$$(echo $$pair | cut -d: -f4); \
		dir=$$(echo $$pair | cut -d: -f5); \
		files=$$(ls $$dir/database/migrations 2>/dev/null | wc -l); \
		applied=$$($(DC) exec -T $$dbs psql -U $$usr -d $$dbn -tAc "select count(*) from migrations" 2>/dev/null | tr -d '\r' || echo 0); \
		tables=$$($(DC) exec -T $$dbs psql -U $$usr -d $$dbn -tAc "select count(*) from information_schema.tables where table_schema='public'" 2>/dev/null | tr -d '\r' || echo 0); \
		if [ "$$applied" = "$$files" ] && [ "$$files" != "0" ]; then st="$(GREEN)ok$(NC)"; else st="$(RED)DIVERGE$(NC)"; fi; \
		printf "  %b %-16s arquivos=%-4s aplicadas=%-4s tabelas=%s\n" "$$st" "$$app" "$$files" "$$applied" "$$tables"; \
	done; \
	printf "\n$(BLUE)── Proxy responde? ──$(NC)\n"; \
	for h in gestaofacil.localhost api.gestaofacil.localhost nfe.gestaofacil.localhost; do \
		code=$$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $$h" http://127.0.0.1:$${HTTP_PORT:-80}/ --max-time 10 2>/dev/null || true); \
		case "$$code" in \
			2*|3*) st="$(GREEN)HTTP $$code$(NC)" ;; \
			4*|5*) st="$(YELL)HTTP $$code$(NC)" ;; \
			*)     st="$(RED)sem resposta (proxy fora do ar?)$(NC)" ;; \
		esac; \
		printf "  %-32s %b\n" "$$h" "$$st"; \
	done; \
	printf "\n$(BLUE)── Fila (Horizon) ──$(NC)\n"; \
	$(DC) exec -T gestaofacil_redis redis-cli -n 1 llen queues:default 2>/dev/null \
		| xargs -r printf "  jobs pendentes na fila default: %s\n"; \
	failed=$$($(DC) exec -T nfe_db psql -U $${NFE_DB_USERNAME:-nfe_api} -d $${NFE_DB_DATABASE:-nfe_api} -tAc "select count(*) from failed_jobs" 2>/dev/null | tr -d '\r' | tr -d ' '); \
	[ -z "$$failed" ] && failed="n/d (tabela ausente)"; \
	printf "  jobs falhados: %s\n" "$$failed"; \
	printf "\n$(YELL)Lembrete:$(NC) NFE_SEFAZ_GATEWAY=%s — 'fake' nao emite nota com validade fiscal.\n" "$${NFE_SEFAZ_GATEWAY:-fake}"

# ═══════════════════════════════════════════════════════════════════════════
#  Migração dos dados da stack antiga
# ═══════════════════════════════════════════════════════════════════════════

import-legacy:
	@printf "$(BLUE)Importa dados dos containers da stack antiga para a nova.$(NC)\n"
	@printf "Pre-requisito: a stack antiga precisa estar de pe (containers gestao-db / nfe-db).\n\n"
	@if ! docker ps --format '{{.Names}}' | grep -qx 'gestao-db'; then \
		printf "$(RED)container gestao-db nao esta rodando — nada a importar$(NC)\n"; exit 1; fi
	@set -a; . ./.env; set +a; \
	printf "Exportando gestaofacil...\n"; \
	docker exec gestao-db pg_dump -U gestaofacil -d gestaofacil --no-owner --no-acl \
		> /tmp/legacy_gestaofacil.sql && \
	$(DC) exec -T gestaofacil_db psql -U $${GESTAOFACIL_DB_USERNAME:-gestaofacil} \
		-d $${GESTAOFACIL_DB_DATABASE:-gestaofacil} < /tmp/legacy_gestaofacil.sql >/dev/null && \
	printf "$(GREEN)gestaofacil importado$(NC)\n"
	@printf "\nConfira com: make status-real\n"

