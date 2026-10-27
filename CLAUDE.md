# CLAUDE.md

Guia para o Claude Code trabalhar neste repositório. Só o que foi conferido no código.

## O que é

Orquestrador do ambiente de desenvolvimento: um `docker-compose.yml` e um `Makefile` que sobem
os três projetos juntos, com nginx na frente e um banco separado para cada API.

É repositório git (`github.com/allanplinio/gestaofacil-dev-environment`). Os projetos `nfe-api`, `gestaofacil-api`, `gestaofacil-fe` e `gestaofacil-e2e` têm repositório próprio e ficam ao lado desta pasta, fora dela.

`docs/` guarda a documentação transversal: os `PLAN-*`, `PROGRESS.md`, `REQUISITOS.md`, `SECURITY.md`, `DATA-MODEL.md` e as NTs em PDF. Antes ficavam na raiz `nfe/`, sem versionamento.

## Serviços

| Container | O que é | Como se chega |
|---|---|---|
| `gestaofacil_nginx` | Entrada única, porta `${HTTP_PORT:-80}` | — |
| `gestaofacil_fe` | Vite (React) | `http://gestaofacil.localhost:<porta>` |
| `gestaofacil_api` | API do ERP (Laravel) | `http://api.gestaofacil.localhost:<porta>` |
| `nfe_api` | Serviço de NF-e (Laravel) | `http://nfe.gestaofacil.localhost:<porta>` |
| `nfe_worker` | Horizon do Serviço de NF-e | — |
| `gestaofacil_db`, `nfe_db` | PostgreSQL (um por API) | `make db-api`, `make db-nfe` |
| `gestaofacil_redis` | Cache e filas | `make redis-cli` |

Os nomes `*.localhost` precisam estar no `/etc/hosts` — `make hosts` mostra a linha a
acrescentar. `make doctor` confere o que falta antes de subir.

## Comandos

```bash
make setup      # doctor + up + install + migrate (primeira vez)
make up / down / restart / ps / rebuild / clean
make logs | logs-api | logs-nfe | logs-worker | logs-fe | logs-nginx
make shell-api | shell-nfe | shell-fe
make migrate    # migrate-api + migrate-nfe
make seed-api | seed-nfe
make test       # test-api + test-nfe + test-fe
make test-api ARGS="tests/Feature/Nfe --filter=rascunho"
make status-real   # não confia em "subiu": containers, migrações aplicadas x arquivos no disco
                #  e o que cada serviço responde de fato
```

### Dois detalhes que enganam

- **`make cache-clear` gera o cache de configuração** (roda `config:cache`), não limpa. Depois
  de mexer em `config/`, rode-o e reinicie o Horizon do Serviço de NF-e
  (`docker exec nfe_worker php artisan horizon:terminate`): o worker mantém código e config em
  memória.
- **Os alvos de teste existem por um motivo.** As variáveis do container (`DB_DATABASE`,
  `CACHE_STORE=redis`, `QUEUE_CONNECTION=redis`) vencem o `phpunit.xml`, e o cache de
  configuração faz o Laravel ignorar as duas coisas. Rodar `php artisan test` direto no
  container aborta (proteção contra `migrate:fresh` no banco de desenvolvimento) ou usa o Redis
  real. `TEST_ENV_API`/`TEST_ENV_NFE` no `Makefile` passam `APP_CONFIG_CACHE` para um arquivo
  inexistente, `APP_ENV=testing`, o banco `_test` e cache/fila/sessão em memória; os alvos ainda
  criam o banco de teste se não existir.

`make test-fe` roda `tsc --noEmit` e o build — o frontend não tem teste automático.

## Configuração

Um `.env` na raiz deste diretório alimenta o compose (`HTTP_PORT`, credenciais dos bancos,
chaves das aplicações). `.env.example` é a referência. Os projetos são montados como volume, com
recarga automática: mudança em PHP ou TypeScript vale na hora, sem rebuild.

Dentro da rede, um serviço chama o outro pelo nome do container; o navegador usa os nomes
`*.localhost` na porta do nginx. É por isso que o frontend recebe `VITE_API_URL` apontando para
`api.gestaofacil.localhost` e não para `gestaofacil_api`.
