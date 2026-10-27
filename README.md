# gestaofacil-dev-environment

Orquestrador do ambiente de **desenvolvimento local** do ecossistema GestãoFácil.
Uma stack, um proxy, um Redis, dois bancos.

```
workspace/
├── gestaofacil-fe/                # Frontend  (React + Vite + TypeScript)
├── gestaofacil-api/               # API de Gestão  (PHP 8.3 / Laravel)
├── nfe-api/                       # API de Emissão de NFe  (PHP 8.3 / Laravel)
└── gestaofacil-dev-environment/   # ← você está aqui
    ├── docker-compose.yml
    ├── Makefile
    ├── .env.example
    ├── nginx/default.conf
    └── examples/                  # Dockerfiles de referência
```

Os quatro projetos ficam **lado a lado**. O compose alcança os outros três por
caminho relativo (`../gestaofacil-fe`), então essa disposição não é opcional.

---

## Por que este repositório existe

Antes existiam **quatro** `docker-compose.yml` — um na raiz e um dentro de cada
projeto — descrevendo os mesmos serviços com nomes, portas e senhas diferentes.
O resultado prático foi:

- **dois bancos `gestaofacil`** rodando ao mesmo tempo, em `5434` e `15434`,
  cada um com uma cópia dos dados. Conectar no DBeaver e não ver a alteração
  que a API acabou de gravar era consequência direta disso.
- **três instâncias de Redis** para dois consumidores.
- **três containers Nginx**, cada um com um `fastcgi_pass` para um nome de
  serviço diferente (`app`, `gestao_app`), em portas espalhadas (80, 8000, 8001).
- alvos de Makefile que chamavam nomes de container onde o compose esperava
  nome de serviço, falhavam calados, e **as migrations nunca rodaram** — o
  banco `nfe_api` ficou com zero tabelas enquanto a documentação dizia que
  várias fases estavam concluídas.

Aqui existe uma stack só. Se você precisa subir um serviço, sobe tudo.

---

## Pré-requisitos

- Docker Engine 24+ e Docker Compose v2 (`docker compose`, sem hífen)
- `make`
- Os três projetos clonados como irmãos desta pasta

---

## Passo a passo — primeira execução

### 1. Clonar os quatro repositórios lado a lado

```bash
mkdir -p ~/workspace && cd ~/workspace
git clone <url>/gestaofacil-fe.git
git clone <url>/gestaofacil-api.git
git clone <url>/nfe-api.git
git clone <url>/gestaofacil-dev-environment.git
cd gestaofacil-dev-environment
```

### 2. Criar o `.env`

```bash
cp .env.example .env
```

Preencha `NFE_CERT_ENCRYPTION_KEY` — sem ela a nfe-api não lê nem grava
certificado A1:

```bash
php -r "echo base64_encode(random_bytes(32)), PHP_EOL;"
```

### 3. Registrar os domínios locais

Navegadores modernos e o `systemd-resolved` resolvem `*.localhost` sozinhos.
Se o seu não resolver:

```bash
make hosts    # mostra a linha exata
echo '127.0.0.1  gestaofacil.localhost api.gestaofacil.localhost nfe.gestaofacil.localhost' | sudo tee -a /etc/hosts
```

### 4. Checar conflitos ANTES de subir

```bash
make doctor
```

Esse passo não é cerimônia. Ele detecta as três coisas que mais travam o
`up` nesta máquina: porta 80 ocupada, PostgreSQL nativo na 5432 e processos
`docker-proxy` órfãos segurando porta de container que já não existe.
Resolva o que ele apontar antes de seguir.

### 5. Subir

```bash
make setup     # up + install (composer/npm) + migrate dos dois bancos
```

Ou, passo a passo:

```bash
docker compose up -d
make install
make migrate
```

### 6. Conferir que subiu de verdade

```bash
make status-real
```

`docker compose ps` mostra "Up" para container que subiu e caiu em loop, e
"Up" não significa que a migration rodou. O `status-real` compara os arquivos
de migration no disco com as linhas aplicadas no banco, chama os três vhosts
pelo proxy e conta os jobs falhados.

### 7. Testar no navegador

| URL | O que deve aparecer |
|---|---|
| http://gestaofacil.localhost | Tela de login do frontend, com HMR ativo |
| http://api.gestaofacil.localhost | Resposta JSON da API de Gestão |
| http://nfe.gestaofacil.localhost | Resposta JSON da API de NFe |

> As URLs acima valem quando `HTTP_PORT=80`. Se o seu `.env` usa outra porta
> — o que acontece sempre que a 80 está ocupada — acrescente-a:
> `http://gestaofacil.localhost:8080`. O `make status-real` sempre testa a
> porta que está de fato no `.env`, então use ele como fonte da verdade.

Teste sem navegador:

```bash
curl -i http://api.gestaofacil.localhost/api/health
curl -i -H 'Host: nfe.gestaofacil.localhost' http://127.0.0.1/
```

---

## Serviços e portas

| Serviço | Container | Porta no host | Acesso |
|---|---|---|---|
| Proxy Nginx | `gestaofacil_nginx` | `80` | os três domínios abaixo |
| Frontend (Vite) | `gestaofacil_fe` | — | via proxy |
| API Gestão (PHP-FPM) | `gestaofacil_api` | — | via proxy |
| API NFe (PHP-FPM) | `nfe_api` | — | via proxy |
| Worker NFe (Horizon) | `nfe_worker` | — | sem porta |
| Postgres Gestão | `gestaofacil_db` | `5432` | DBeaver |
| Postgres NFe | `nfe_db` | `5433` | DBeaver |
| Redis compartilhado | `gestaofacil_redis` | `6379` | redis-cli |

As portas da tabela são os **defaults do `.env.example`**. O que vale na sua
máquina é o seu `.env` — confira com `make doctor`, que imprime a porta de cada
serviço e diz se ela está livre.

Só o proxy publica porta HTTP. PHP-FPM e Vite não são alcançáveis direto do
host de propósito: assim o ambiente local se comporta como produção, onde
nada fala com o FPM sem passar pelo Nginx.

### Conexão no DBeaver

| Conexão | Host | Porta | Database | User | Senha |
|---|---|---|---|---|---|
| Gestão | `localhost` | `5432` | `gestaofacil` | `gestaofacil` | `GESTAOFACIL_DB_PASSWORD` |
| NFe | `localhost` | `5433` | `nfe_api` | `nfe_api` | `NFE_DB_PASSWORD` |

> Se você tem PostgreSQL instalado no sistema, ele já ocupa a `5432` e o
> container não sobe. Mude `GESTAOFACIL_DB_PORT=5442` no `.env` — e lembre de
> usar `5442` no DBeaver também.

---

## O Redis é compartilhado — e isso exige cuidado

Uma instância atende os dois backends. Para as chaves não colidirem, cada
aplicação usa um database numerado diferente, fixado no `docker-compose.yml`:

| Aplicação | `REDIS_DB` (filas/sessão) | `REDIS_CACHE_DB` |
|---|---|---|
| gestaofacil-api | 0 | 2 |
| nfe-api | 1 | 3 |

Ao inspecionar manualmente, selecione o database certo:

```bash
make redis-cli
127.0.0.1:6379> SELECT 1     # filas da nfe-api
127.0.0.1:6379> KEYS *
```

Um `FLUSHALL` apaga cache e filas dos dois sistemas de uma vez. Prefira
`FLUSHDB` depois de escolher o database.

---

## Comunicação entre os serviços

Existem **dois conjuntos de nomes**, e a distinção não é estética:

| Quem resolve | Domínio | Porta na URL |
|---|---|---|
| Navegador (no host) | `*.gestaofacil.localhost` | sim — `HTTP_PORT` |
| Container → container | `*.gestaofacil.internal` | não — sempre 80 |

### Por que o interno não pode ser `.localhost`

A glibc implementa a RFC 6761: **todo nome terminado em `.localhost` é forçado
para `127.0.0.1` dentro do `getaddrinfo`**, sem nunca consultar o DNS do Docker.
Um container que chamasse `http://nfe.gestaofacil.localhost` bateria no próprio
loopback e receberia `Connection refused`.

O detalhe cruel é que isso **não aparece** num teste ingênuo: `getent hosts
nfe.gestaofacil.localhost` responde com o IP certo, porque o `getent` usa o NSS
e não aplica a regra especial. Só o `curl`/`file_get_contents` real falha.

Por isso o container do Nginx carrega os dois conjuntos de alias, e os vhosts de
API aceitam ambos no `server_name`:

```yaml
aliases:
  - gestaofacil.localhost        # navegador
  - api.gestaofacil.localhost
  - nfe.gestaofacil.localhost
  - api.gestaofacil.internal     # container → container
  - nfe.gestaofacil.internal
```

### Na prática

A gestaofacil-api chama a nfe-api assim (definido em `API_NFE_URL`):

```php
config('services.nfe_api.url')  // http://nfe.gestaofacil.internal/api/v1
```

Sem porta, porque dentro da rede o Nginx escuta na 80 independentemente do
`HTTP_PORT` publicado no host.

O frontend recebe a URL da API por `VITE_API_URL`, **com** a porta, porque quem
resolve aquela URL é o navegador:

```yaml
VITE_API_URL: http://api.gestaofacil.localhost:${HTTP_PORT:-80}
```

Isso torna a chamada do frontend cross-origin (`gestaofacil.localhost` →
`api.gestaofacil.localhost`). O CORS padrão do Laravel já responde ao preflight
com `Access-Control-Allow-Origin: *`; se um dia o projeto restringir origens,
os dois domínios precisam entrar na lista.

---

## Comandos

```
make doctor        Checa conflitos de porta e órfãos antes de subir
make hosts         Linha para o /etc/hosts
make setup         up + install + migrate
make up|down|restart|ps
make status-real   Estado verificado (migrations, proxy, fila)
make logs          Tudo; ou logs-api, logs-nfe, logs-fe, logs-worker, logs-nginx
make install       composer install nos dois PHP + npm install no front
make migrate       Migrations dos dois bancos
make seed-api / seed-nfe
make db-api / db-nfe / redis-cli
make shell-api / shell-nfe / shell-fe
make test-api / test-nfe
make build / rebuild
make import-legacy Traz os dados da stack antiga
make clean         Remove containers E VOLUMES (pede confirmação)
```

---

## Vindo da stack antiga

Os volumes antigos (`nfe-pgdata`, `gestao-pgdata`, `postgres_data`) **não** são
reaproveitados: a stack nova cria `gestaofacil_pgdata` e `nfe_pgdata` vazios.
Com os containers antigos ainda de pé:

```bash
make up
make import-legacy     # pg_dump do gestao-db → gestaofacil_db
make status-real
```

Para a nfe-api não há o que importar: aquele banco nunca teve as migrations
aplicadas. `make migrate` cria o schema do zero.

Depois de confirmar que a stack nova responde, derrube a antiga:

```bash
cd ..
docker compose -f docker-compose.yml down                       # stack da raiz
docker compose -f gestaofacil-api/docker-compose.yml down       # stack individual
docker compose -f gestaofacil-fe/docker-compose.yml down
```

Os `docker-compose.yml` da raiz e dos três projetos ficaram obsoletos. Mantê-los
no repositório é o que permite alguém rodar `make up` na pasta errada e recriar
o problema dos bancos duplicados — vale removê-los em commit próprio.

---

## Adicionando um quarto microsserviço

`examples/` tem os dois moldes:

- `php-laravel.Dockerfile` — imagem de dev para Laravel
- `node-frontend.Dockerfile` — multi-stage para frontend Node

As três regras que separam a imagem de dev da de produção:

1. **sem `COPY` do código** — ele chega por volume, senão a imagem envelhece a
   cada edição;
2. **sem `composer install`/`npm run build` no build** — as dependências são
   instaladas contra o volume e sobrevivem ao rebuild;
3. **sem `USER` fixo** — com bind mount, o uid 33 do `www-data` não casa com o
   uid do seu usuário e o Laravel falha ao escrever em `storage/`.

Depois de criar o Dockerfile, registre o serviço no `docker-compose.yml` e
adicione o `server { }` correspondente em `nginx/default.conf`. O `root` do
vhost e o `working_dir` do container **precisam ser o mesmo caminho absoluto**.

---

## Troubleshooting

### `bind: address already in use` na porta 80

Rode `make doctor`. O caso mais comum nesta máquina não é outro servidor web, e
sim **processos `docker-proxy` órfãos**: containers já removidos cujo proxy
continuou vivo segurando a porta. Eles não aparecem em `docker ps`.

```bash
make doctor                  # lista os PIDs órfãos
sudo kill <pid>
```

### O container do Postgres não sobe

Provavelmente o PostgreSQL do sistema já ocupa a 5432:

```bash
ss -ltn | grep 5432
sudo systemctl stop postgresql     # ou mude GESTAOFACIL_DB_PORT no .env
```

### DBeaver: `password authentication failed`

Confira a **porta** antes da senha. `5432` pode ser o Postgres do sistema, que
não conhece os usuários `gestaofacil` nem `nfe_api` e devolve exatamente esse
erro. Os bancos da stack estão em `5432` (Gestão) e `5433` (NFe) — conforme o
seu `.env`.

Se a porta estiver certa: os bancos usam `scram-sha-256`; driver JDBC anterior
ao 42.2 falha mesmo com a senha correta. Atualize o driver no DBeaver.

### Um container não alcança o outro (`Connection refused`)

Você usou um domínio `.localhost` numa chamada entre containers. Ele resolve
para loopback por regra da glibc, não para o proxy. Use o `.internal`:

```php
// errado dentro de um container
http://nfe.gestaofacil.localhost/api/v1
// certo
http://nfe.gestaofacil.internal/api/v1
```

Para confirmar, teste de dentro do container — e com `curl`, não com `getent`,
que não aplica a regra e dá falso positivo:

```bash
docker compose exec gestaofacil_api curl -v http://nfe.gestaofacil.internal/api/health
```

### `502 Bad Gateway`

O PHP-FPM não respondeu. `make logs-api` ou `make logs-nfe`. Causa frequente é
`vendor/` ausente — rode `make install`.

### `Primary script unknown` (404 do FPM)

O `root` do vhost em `nginx/default.conf` e o `working_dir` do container PHP
divergiram. Os dois precisam apontar para o mesmo caminho absoluto, porque o
Nginx manda `SCRIPT_FILENAME` e o FPM procura o arquivo naquele caminho.

### Permissão negada em `storage/` ou `bootstrap/cache/`

O uid do container não bate com o do dono dos arquivos no host:

```bash
id -u && id -g                              # normalmente 1000/1000
docker compose build --build-arg UID=$(id -u) --build-arg GID=$(id -g) gestaofacil_api
```

### HMR do frontend não atualiza

O proxy já repassa o WebSocket. Se ainda assim não recarregar, o problema
costuma ser o inotify não propagar pelo bind mount — `CHOKIDAR_USEPOLLING=true`
já está ligado no compose. Confira `make logs-fe`.

---

## Avisos honestos sobre este ambiente

Dois pontos que o ambiente **não** resolve e que é melhor saber antes de supor
o contrário:

1. **`NFE_SEFAZ_GATEWAY=fake` é o padrão.** Nesse modo a nfe-api não conversa
   com a SEFAZ: as notas são simuladas e **não têm validade fiscal alguma**.
   Emitir com sucesso aqui não prova que a integração real funciona.
2. **Subir não é validar.** `docker compose ps` dizendo "Up" já conviveu, neste
   projeto, com um banco de zero tabelas. Use `make status-real` — ele mede o
   que aconteceu, não o que era para ter acontecido.
