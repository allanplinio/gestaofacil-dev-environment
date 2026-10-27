# PLAN-PRODUCAO — Go-live do GestãoFácil para uma empresa

Criado em 20/10/2026. Escopo: **uma empresa**, VPS único (Fase 0 do `PLAN-INFRA.md`).
Este plano não repete o `PLAN-SEGURANCA.md`: referencia os itens dele que ainda travam a subida e acrescenta o que só aparece na hora de ligar a produção.

## Premissa: tudo em um único VPS (definida por você em 20/10/2026)

Front, as duas APIs, os dois Postgres, o Redis, o Horizon e o scheduler rodam na mesma máquina. Consequências que moldam as fases abaixo:

1. **Um domínio de falha só.** Se o disco ou o VPS morrer, o banco, os XMLs e os certificados morrem juntos. Backup na mesma máquina não conta: a cópia **fora do VPS** é obrigatória (C3), não opcional.
2. **O host também é superfície de ataque.** Só 80/443 (e SSH) podem estar abertos; Postgres, Redis e o nfe-api ficam só na rede interna do Docker (A2, A4, A9).
3. **Memória é o recurso escasso.** O `PLAN-INFRA.md` prevê para a Fase 0 um VPS de 2 vCPU e 4 GB. Cabem: 2 PHP-FPM, 2 Postgres, Redis, Horizon, scheduler e nginx; os dois Postgres e o Horizon são os que mais pesam. Medir antes de liberar (A10).
4. **Disco enche e derruba tudo.** XMLs (5 anos), logs do Docker, logs do Laravel e dumps de backup disputam o mesmo volume (A11).
5. **Manutenção do host derruba o serviço.** Atualizar o sistema ou reiniciar o Docker para a emissão por um tempo. Janela combinada com a empresa e deploy fora do expediente (A7).

**Regra deste documento:** cada afirmação traz a evidência (arquivo:linha, comando ou consulta feita em 20/10/2026). O que não foi conferido está na seção 7 e **não** é tratado como fato.

---

## 0. Correções à primeira lista de recomendações

Na primeira resposta eu listei itens a partir de memória antiga e dos planos. A conferência mostrou que três estavam errados e um estava incompleto:

| Eu disse | O que o código mostra | Evidência |
|---|---|---|
| Cancelamento, CC-e e inutilização gravam o resultado no pedido (202) | **Já corrigido.** Cancelamento vira `cancelando` até a SEFAZ responder e volta a `autorizada` se recusar; CC-e só liga a flag quando a SEFAZ registra; inutilização fica `enviada` | `gestaofacil-api/app/Services/NfeEmissaoService.php:762-935`; `gestaofacil-api/CLAUDE.md` ("Cancelamento e CC-e são assíncronos (16/10/2026)") |
| A numeração do nfe-api pode retroceder sem recusa | **Já corrigido.** Retroceder devolve 409 e grava `Log::warning` | `nfe-api/app/Http/Controllers/Api/V1/NfeNumberingController.php:59` (409) e `:76` (log) |
| Naturezas criadas antes do emitente caem em regime normal | **Já corrigido.** Sem emitente a natureza é recusada (422); as 6 padrão nascem junto com o emitente | `nfe-api/CLAUDE.md` seção "Naturezas e regime tributário" |
| A lista de notas some depois das 21h por causa do fuso | **Já corrigido.** `APP_TIMEZONE=America/Sao_Paulo` e sessão do Postgres no mesmo fuso | `gestaofacil-api/CLAUDE.md` seção "Datas"; commit `daef8bb` |
| `config/` do gestaofacil-api nunca foi commitado | **Já corrigido.** 14 arquivos versionados. **Falta provar com um clone limpo** | `git ls-files config` em `gestaofacil-api` |

As memórias `decisoes_pendentes_fiscal` e `project_config_ausente_gestaofacil_api` estavam desatualizadas e foram corrigidas.

---

## 1. Estado real encontrado (o que sustenta este plano)

### 1.1 Infraestrutura
- **Não existe nada de produção no repositório.** Só há o compose de desenvolvimento em `gestaofacil-dev-environment/docker-compose.yml`. Os compose das pastas dos projetos estão marcados como obsoletos (`DOCKER-COMPOSE.md`).
- **`gestaofacil-dev-environment` não é um repositório git** (`git rev-parse` falha). Toda a infra, inclusive o futuro compose de produção, hoje não tem histórico nem cópia.
- O compose de dev publica `5432`, `5433` e `6379` no host, usa `APP_ENV=local` e `APP_DEBUG=true`, tem uma rede só (`gestaofacil_net`), o usuário da aplicação é o `POSTGRES_USER` (superusuário) e a senha do Redis cai em `secret` se a variável faltar (`${REDIS_PASSWORD:-secret}`).
- A senha do banco do gestaofacil e a do nfe-api têm o **mesmo valor** no `.env` de dev (hash idêntico, comparado sem imprimir o valor).
- O Dockerfile do **nfe-api é de dev**: não copia o código, não roda `composer install`, não tem `USER` (`nfe-api/docker/php/Dockerfile`). O do gestaofacil-api tem `composer install --no-dev`, mas usa `composer:latest`, `--ignore-platform-reqs` e `--no-scripts`, e só traz php-fpm.
- O nginx de dev só escuta na porta 80, sem TLS e sem HSTS, e **publica o nfe-api no mesmo proxy** (`nfe.gestaofacil.localhost`). O nfe-api tem CORS vazio (`nfe-api/config/cors.php:10`): foi desenhado para ser chamado só pelo servidor.
- O front usa `VITE_API_URL` em tempo de **build** (`gestaofacil-fe/src/services/api.ts:51`), com fallback `http://localhost:8000`. O Dockerfile de produção do front **não declara** `ARG`/`ENV` para ela. A CSP do `serve.json` tem `connect-src 'self'`: se a API ficar em outro subdomínio, o navegador bloqueia.
- Nenhuma das duas APIs configura `trustProxies` (grep vazio em `bootstrap/` e `app/`).

### 1.2 Backup
- Existe só `nfe-api/scripts/backup-db.sh`. **Testei com um `pg_dump` falso:** o script falha mesmo quando o dump funciona (`BACKUP_FILE=$(create_backup)` captura as linhas de log e `gunzip -t` as trata como nome de arquivo → "Backup corrompido", exit 1). Quando o `pg_dump` falha, o pipeline sem `pipefail` ainda deixa um `.gz` vazio no disco.
- Cobre **só o banco do nfe-api**. Não há backup do banco do gestaofacil, nem de `storage/app` do nfe-api (onde ficam os XMLs autorizados: `Storage::disk('local')->put($xmlPath…)` em `ProcessNfeJob.php:117`), nem de `storage/certificates`.
- A retenção fiscal é de 5 anos (`PLAN-INFRA.md` §1). Perder os XMLs é perda de obrigação legal, não só de dado.
- `nfe-api/docs/PHASE_12_PRODUCTION_HARDENING.md` é um checklist com todas as caixas vazias ("implementação depende de infraestrutura real").

### 1.3 Credenciais
- O `nfe-api/.env.bak` já foi apagado (PLAN-SEGURANCA Fase 0), mas **`gestaofacil-dev-environment/.env.bak-1789954489` continua no disco** (20/09/2026) e **`Makefile.bak-1789956866`** também.
- Comparando por hash curto: as senhas de banco do `.bak` são iguais às atuais; a `NFE_CERT_ENCRYPTION_KEY` do `.bak` é **diferente** da atual. Não sei se os `.pfx` foram re-cifrados nessa troca.
- O `.gitignore` do dev-environment ignora só `.env`; `.env.bak-*` **não** casa. Se a pasta virar repositório, o `.bak` entra no commit.

### 1.4 Fiscal
- **Nenhuma nota em produção.** Consulta no `nfe_db` de dev: 14 notas, todas `environment=2` (NF-e 55: 4 autorizadas, 1 descartada; NFC-e 65: 6 autorizadas, 3 rejeitadas). UF testada: PE (26). `nfe-api/CLAUDE.md` confirma.
- O certificado cadastrado no dev (`11500611000115`) está em `environment=2` e **vence em 02/02/2027**.
- O ambiente de cada CNPJ é **o campo `environment` do certificado**, com padrão 2 (`CertificateService.php:63`). A troca é `PUT` no ambiente (`CertificateController::updateEnvironment`).
- A numeração é por `(cnpj, serie, environment, modelo)` (`NfeNumberingController::store`, bloco `$chave`). Ao trocar para produção **não existe linha de numeração do ambiente 1**: a emissão começa do 1 se ninguém configurar.
- O CSC da NFC-e é **um par só** por certificado (`csc_id`, `csc_encrypted`; migration `2026_09_15_000001`). Não há um CSC por ambiente: o de produção precisa **substituir** o de homologação.
- O compose de dev avisa: sem `NFE_RESP_TEC_CNPJ` a tag `infRespTec` não é gerada e a PE rejeita com 972.
- Proteções que já existem: gateway `fake` é recusado em produção (`AppServiceProvider.php:20`); `APP_DEBUG=true` é recusado fora de local/testing (`:40`); fora de local o gateway padrão é `real` (`config/nfe.php:29`).
- O DF-e e o CNPJ alfanumérico **nunca rodaram contra a SEFAZ real** (`CLAUDE.md` do gestaofacil-api e do nfe-api). Em produção, `NFE_DFE_REAL_HABILITADO` passa a ser `true` por padrão (`config/nfe.php:70`).

### 1.5 Operação
- O scheduler (`schedule:work`) e o Horizon só existem no compose de dev (`gestaofacil_scheduler`, `nfe_worker`). Sem eles não há reconciliação de notas pendentes (5 min) nem varredura DF-e (04:00). O nfe-api não tem nada agendado (`routes/console.php`).
- `MAIL_MAILER` padrão é `log` nas duas APIs, e o `.env` do gestaofacil usa `log`: em produção a recuperação de senha **não envia e-mail** até configurar SMTP.
- Não há comando para revogar tokens antigos. `tokens()->delete()` só roda na troca/redefinição de senha (`UserPasswordController.php:90`, `PasswordResetController.php:148`).
- Existe `/up` nas duas APIs e `/api/v1/health` no nfe-api. Há `LOG_SLACK_WEBHOOK_URL` nas configs de log, mas nenhum alerta ligado a ele foi verificado.
- Existe CI de segurança nas duas APIs (`security.yml`) e CI no front (`ci.yml`). **Não existe workflow de deploy.**

---

## 2. Fase A — Infra de produção (bloqueia tudo)

Decisão registrada: VPS único, deploy manual por `deploy.sh` (`PLAN-INFRA.md` §11).

- [ ] **A1. Versionar a infra.** Transformar `gestaofacil-dev-environment` em repositório (ou criar `gestaofacil-infra`). Antes: apagar `.env.bak-*` e `Makefile.bak-*` e acrescentar `.env.*` ao `.gitignore` (só `.env.example` versionado).
- [ ] **A2. `docker-compose.prod.yml`** separado do de dev, com:
  - `APP_ENV=production`, `APP_DEBUG=false` explícitos;
  - sem `ports:` em Postgres e Redis; só o proxy publica 80/443;
  - redes separadas: proxy ↔ apps; apps ↔ bancos/Redis;
  - role do Postgres da aplicação **sem superuser** (criar role dono do banco; o gatilho de auditoria só protege assim);
  - senhas **sem fallback** (`${VAR:?}` em vez de `${VAR:-secret}`), uma por banco;
  - `restart: unless-stopped` em apps, `scheduler`, `horizon`.
- [ ] **A3. Imagens de produção.** Criar o Dockerfile de produção do nfe-api (hoje é dev). Nos dois: código copiado para a imagem, `composer install --no-dev --optimize-autoloader` **sem** `--ignore-platform-reqs`/`--no-scripts` se possível, `composer:2` fixado, `USER www-data`, opcache.
- [ ] **A4. nfe-api não público.** Não publicar o vhost do nfe-api no proxy externo; só a rede interna (`nfe.gestaofacil.internal`). Só `app.` (front) e `api.` (gestaofacil-api) saem na internet.
- [ ] **A5. TLS.** HTTPS com redirect de 80, TLS 1.2+, HSTS. Resolver `trustProxies` nas APIs (ou confirmar por teste que nada depende de `isSecure()`).
- [ ] **A6. Front.** Passar `VITE_API_URL` como `ARG` no Dockerfile de produção e conferir no `dist` que não sobrou `localhost:8000`. Se `app.` e `api.` forem origens diferentes, acrescentar a origem da API no `connect-src` do `serve.json`. Conferir no Firefox que a CSP não bloqueia nada (item já pendente no PLAN-SEGURANCA).
- [ ] **A7. `deploy.sh`** conforme `PLAN-INFRA.md` §11: backup antes → `git pull` → `composer install` → migrations → `scripts/deploy-config.sh` (nas duas APIs) → health check com rollback.
- [ ] **A8. Prova de clone limpo.** Clonar os repositórios em pasta vazia, subir com o compose de produção, rodar `deploy-config.sh` e `migrate`. É o teste que fecha o risco antigo de `config/`.

Itens que existem por causa do VPS único (recomendações de endurecimento do host; não são fatos do repositório):

- [ ] **A9. Proteção do host.** Firewall (ufw ou do provedor) liberando só 22, 80 e 443; SSH só por chave, sem senha e sem login de root; `fail2ban`; atualizações de segurança automáticas (`unattended-upgrades`). Atenção: o Docker publica portas **por cima** do ufw; por isso A2 (sem `ports:` em banco e Redis) é a proteção real, e o ufw sozinho não basta.
- [ ] **A10. Dimensionar a memória.** Subir a stack de produção no VPS escolhido, rodar a carga de 200 emissões simuladas que o `PLAN-INFRA.md` exige antes de sair da Fase 0 e registrar o uso de RAM/CPU. Definir limites (`mem_limit`) e `shared_buffers` do Postgres para nenhum serviço derrubar os outros. Criar swap como margem, não como solução.
- [ ] **A11. Disco.** Rotação de log do Docker (`max-size`/`max-file` no daemon ou no compose), alerta de disco a 80 %, e `storage/app` do nfe-api em volume nomeado, nunca dentro da imagem. Estimar o crescimento: o `PLAN-INFRA.md` usa 15 KB por XML e 100 a 200 notas por dia.
- [ ] **A12. Reinício do servidor.** Provar que, após `reboot`, tudo volta sozinho (`restart: unless-stopped`, Docker habilitado no boot, health check passando) e que as filas pendentes são retomadas.

**Critério de saída:** stack sobe do zero a partir do git, sem nenhum arquivo copiado à mão além dos `.env`; e sobe de novo sozinha após um reboot.

## 3. Fase B — Segredos

- [ ] **B1.** Gerar, só no servidor: `APP_KEY` (duas), senha de cada banco (distintas), senha do Redis, `NFE_CERT_ENCRYPTION_KEY`, `API_NFE_TOKEN_SECRET`, `PROVISIONAMENTO_CHAVE_HASH`/`NFE_API_PROVISIONAMENTO_CHAVE`. Nada reaproveitado de dev.
- [ ] **B2.** Guardar `NFE_CERT_ENCRYPTION_KEY` **fora** do servidor e do backup dos dados (gerenciador de senhas). Sem ela os `.pfx` do backup não abrem.
- [ ] **B3. Decisão sua:** a pasta `nfe` já foi copiada, sincronizada ou compartilhada? Se sim, tudo acima é obrigatório (já é, pois a produção nasce com chaves novas) **e** o certificado A1 real nunca deve passar pelo ambiente de dev.
- [ ] **B4.** Ativar `SANCTUM_TOKEN_EXPIRATION` (12 h) desde o primeiro dia: banco novo não tem tokens antigos, então o item "revogar tokens" do PLAN-SEGURANCA §70 deixa de se aplicar em produção.

## 4. Fase C — Backup e restauração (bloqueia a primeira nota real)

- [ ] **C1. Corrigir `backup-db.sh`:** `set -o pipefail`; as funções de log escrevem em `stderr`; falha também notifica (hoje só o sucesso chama `send_notification`).
- [ ] **C2. Ampliar o escopo:** os dois bancos + `storage/app` do nfe-api (XMLs, DANFEs) + `storage/certificates` (cifrados). A chave de B2 fica separada.
- [ ] **C3. Cópia fora do servidor — obrigatória por ser VPS único** (regra 3-2-1 do `PLAN-INFRA.md` §7), cifrada, em outro provedor ou conta, com credencial de **só escrita** no VPS: quem invadir o VPS não pode apagar os backups. Agendar no cron **do host** (não dentro de um container que pode estar parado). Considerar também o snapshot do provedor como camada extra, nunca como único backup.
- [ ] **C4. Teste de restauração real**, num ambiente limpo: restaurar, subir a stack e **emitir uma nota de homologação** com o certificado restaurado. Registrar data e tempo gasto em `docs/RESTORE_PROCEDURE.md`.
- [ ] **C5. Alerta de backup que não rodou** (arquivo com mais de 24 h).

**Critério de saída:** C4 feito e registrado. Backup que nunca foi restaurado não conta.

## 5. Fase D — Operação

- [ ] **D1.** `gestaofacil_scheduler` e `nfe_worker` (Horizon) no compose de produção, com restart automático. Conferir após subir: `php artisan schedule:list` e `horizon:status`.
- [ ] **D2. SMTP real** nas duas APIs; testar recuperação de senha de ponta a ponta.
- [ ] **D3. Monitoramento mínimo:** uptime check em `/up` (as duas) e `/api/v1/health` (nfe-api, interno); alerta por e-mail se o Horizon parar, se houver job falhando ou se o backup faltar. Ligar o canal de log (`LOG_SLACK_WEBHOOK_URL`) ou outro destino que você use.
- [ ] **D4. Logs fora do servidor** ou cópia periódica (retenção diária de 90 dias já existe).
- [ ] **D5. Permissões:** `.env` em `600`; `storage/` com dono do deploy e grupo `www-data`, `775` (PLAN-SEGURANCA Fase 8).

## 6. Fase E — Fiscal: do homologação à primeira nota real

Ordem importa. Tudo aqui se faz **com a empresa real, mas ainda em `environment=2`**, até o passo E5.

- [ ] **E1. Dados da empresa (com o contador):** CNPJ, IE, CRT/regime, UF, série(s), CSC e ID do CSC de **produção** da NFC-e (gerados no portal da SEFAZ da UF), responsável técnico (`NFE_RESP_TEC_*`).
- [ ] **E2. Certificado A1 real** (validade conferida; o de dev vence em 02/02/2027). Cadastrar pelo fluxo de produção, emitente primeiro (cria as naturezas), depois revisar naturezas, depois numeração.
- [ ] **E3. Ciclo completo em homologação com o certificado real** (`tpAmb=2`): emitir NF-e 55; emitir NFC-e 65 (se a empresa usa); cancelar; CC-e (só 55); inutilizar. Conferir cada estado intermediário na tela (`cancelando` → `cancelada`).
- [ ] **E4. Se a empresa vem de outro sistema:** descobrir o último número emitido em produção por série e modelo. A numeração do ambiente 1 começa do 1 se ninguém configurar.
- [ ] **E5. Virada para `environment=1`**, nesta sequência: trocar o ambiente do CNPJ → **configurar `numero_inicial` do ambiente 1** (E4) → **substituir o CSC pelo de produção** → conferir na tela que ambiente, numeração e CSC mostram produção.
- [ ] **E6. Primeira nota real de baixo valor**, conferida no portal da SEFAZ (chave, protocolo, XML). Só então operar normalmente.
- [ ] **E7. Contingência:** manter o sistema atual da empresa disponível por algumas semanas. Procedimento para queda do nfe-api ou da SEFAZ (emissão `pendente` sem protocolo é reconciliada a cada 5 min; confirmar com o contador o plano para NFC-e em contingência).
- [x] **E8. DF-e:** ativar a busca só **depois** de E6 e fazer a primeira consulta acompanhada. Decidir antes se há outro sistema consultando o mesmo CNPJ (a cota é compartilhada). **Feito (20/10/2026):** o Allan testou a busca de notas de entrada na SEFAZ real, em produção, e funciona.

**Critério de saída:** nota real autorizada, XML guardado e incluído no backup seguinte.

## 6b. O que instalar no servidor

Princípio: **o host fica enxuto; PHP, Postgres, Redis e Node rodam só em containers.** Não instalar PHP, Composer, Node nem Postgres no host.

### No host (Ubuntu Server LTS; escolha minha, o repositório não fixa o SO)
| Pacote | Para quê |
|---|---|
| Docker Engine + plugin Compose (repositório oficial da Docker) | roda toda a stack |
| `git` | `git pull` do deploy; deploy key somente leitura (`PLAN-INFRA.md` §11) |
| `ufw`, `fail2ban`, `unattended-upgrades` | firewall, bloqueio de força bruta no SSH, atualizações de segurança |
| `chrony` | relógio sincronizado: a NF-e leva data/hora de emissão e a SEFAZ valida; TLS também depende da hora |
| `certbot` (ou Caddy como proxy) | certificado TLS e renovação. **Decisão sua:** o nginx atual do compose não faz TLS |
| ferramenta de backup externo: `restic` ou `rclone` (cifra no cliente) | o `backup-db.sh` atual chama `aws cli`; trocar ou instalar o `aws` conforme o destino escolhido |
| `cron`/timers do systemd, `logrotate` | backup, renovação do certificado, rotação |
| `curl`, `jq`, `ncdu`/`htop` | health check do deploy e diagnóstico |
| `postgresql-client-16` | **só** se o backup rodar no host; alternativa: `docker exec … pg_dump`, sem instalar nada (a imagem do banco é `postgres:16-alpine`) |

### Dentro das imagens (versões vindas do repositório)
- PHP **8.3** (gestaofacil-api exige `^8.3`; nfe-api `^8.2`), `php-fpm`. Extensões do nfe-api: `pdo_pgsql, curl, gd, mbstring, soap, xml, zip, intl, pcntl, redis` (sped-nfe exige curl, dom, gd, mbstring, openssl, soap, xml, zip).
- PostgreSQL **16**, Redis **7**, nginx **1.27**, Node **20** (só no build do front), Composer **2** (build).
- **Lacuna comprovada:** a imagem de produção do gestaofacil-api instala só `pdo pdo_pgsql zip` (`gestaofacil-api/Dockerfile`), e o `composer install` usa `--ignore-platform-reqs`, que **esconde** extensão faltando. A imagem de dev tem também `bcmath, intl, gd, pcntl, opcache, redis`. O `.env` de dev usa `REDIS_CLIENT=predis`, mas o padrão em `config/database.php:149` é `phpredis`: sem a extensão e sem essa variável, o Redis não conecta. Tarefa A3: montar a imagem de produção a partir da lista que a aplicação realmente usa e **tirar o `--ignore-platform-reqs`**, para o build falhar quando faltar algo.
- Certificado A1: o código só chama `openssl_pkcs12_read` (`CertificateService.php:112`), sem tratamento do provedor legado do OpenSSL 3. O certificado de teste abriu na imagem atual, mas certificados de outras autoridades certificadoras podem usar cifras antigas (RC2). **Testar o `.pfx` real da empresa na imagem de produção antes da virada** (E2).

## 6c. Segurança a considerar (específica para este desenho)

**Rede e exposição**
- Só 80/443 públicos. Postgres, Redis e nfe-api sem porta no host (A2, A4). O Docker ignora o `ufw` ao publicar portas: conferir de fora com `nmap` a partir de outra máquina.
- O nfe-api tem dois painéis: Filament em `/admin` e Horizon em `/horizon`. **Verificado no dev:** `/horizon` responde 200 (ambiente local) e `/admin/login` responde 404. Não há gate do Horizon nem `canAccessPanel` no código, e o modelo de usuário do painel (`App\Models\User`) não existe. Em produção o Horizon tende a negar por padrão (comportamento conhecido do pacote, **não verificado aqui**). Como o nfe-api fica interno (A4), nenhum dos dois deve ser alcançável de fora; confirmar por teste na subida e acessar, se necessário, por túnel SSH.
- Rate limit: o login tem `throttle-logins` e `throttle:5,1` nas rotas de senha (`routes/api.php`). Conferir atrás do proxy que o IP limitado é o do cliente, não o do proxy: sem `trustProxies` (grep vazio), todos podem aparecer com o IP do container do nginx e compartilhar o mesmo limite.

**Segredos e certificado**
- Certificados `.pfx` ficam cifrados com `NFE_CERT_ENCRYPTION_KEY` (migration `add_emitente`, `SECURITY.md` §3). Mas **a chave está no `.env` do mesmo servidor** que guarda o arquivo cifrado: quem lê o disco lê os dois. Aceito para o piloto; mitigar com `.env` `600`, disco do VPS cifrado se o provedor oferecer, e acesso SSH só seu.
- Certificado A1 é a identidade fiscal da empresa: invasão do VPS permite emitir e cancelar notas. Por isso a lista de SSH deve ser mínima e a auditoria (`auditoria_eventos`) precisa de cópia fora do servidor, senão o invasor apaga o rastro.
- Chaves nunca em imagem nem em `docker-compose.yml` versionado; só em `.env` do servidor (`PLAN-INFRA.md` §11).

**Aplicação**
- Confirmar `APP_ENV=production` e `APP_DEBUG=false` (a guarda recusa debug fora de local/testing, mas não obriga a definir `production`).
- [x] **`laravel/tinker` fora de produção (20/10/2026).** Estava em `require` do gestaofacil-api, e `--no-dev` não o removia. Movido para `require-dev` junto com `psy/psysh` (`composer.json`/`composer.lock`, nenhuma versão alterada). Conferido: `composer install --no-dev --dry-run` agora lista os dois como "Removing". Em dev nada muda (`make tinker` continua). **Ainda não commitado.** O nfe-api já não tinha `tinker` (`grep` em `composer.json`).
- Webhook entre as APIs é assinado com HMAC (`API_NFE_TOKEN_SECRET`, com `_ANTERIOR` para rotação): gerar nova em produção.
- LGPD: o banco guarda CPF/CNPJ e dados de clientes da empresa. Backup externo cifrado, retenção definida e acesso restrito; XMLs de terceiros (DF-e) incluídos.

**Operação**
- Conta única de administração do servidor, com 2FA onde o provedor permitir (painel do VPS é a porta dos fundos: quem entra nele reinstala a máquina).
- Atualizações: imagens com versão fixa (`postgres:16-alpine`, `redis:7-alpine`, `nginx:1.27-alpine` já estão) e reconstruir periodicamente para pegar correções; CI de auditoria (`security.yml`) já bloqueia vulnerabilidade alta.
- Plano de incidente: o que fazer se o certificado vazar (revogar na AC, trocar chave, avisar a empresa) e se o VPS for comprometido (isolar, restaurar de backup limpo). Escrever uma página antes da virada (Fase 12 do PLAN-SEGURANCA).

## 7. O que NÃO foi verificado (não tratar como fato)

- Se há teste automatizado para `updateEnvironment`/`trocarAmbiente` e para o efeito dele na numeração e no CSC. Procurei por "ambiente" nos testes e há ocorrências em vários arquivos, mas não li quais cobrem a troca.
- Se existe aviso de certificado vencendo. Há referências a validade em `EstadoDoCertificado`, `ConfiguracaoFiscalController` e no front, mas não conferi o comportamento.
- Capacidade real do VPS (CPU/RAM/disco para os XMLs de 5 anos) e preço. Os números vêm do `PLAN-INFRA.md`, sem cotação minha.
- Se o webhook do nfe-api para o gestaofacil funciona atrás de TLS e da rede separada de A2/A4 (o caminho muda de HTTP interno para o novo desenho).
- Regras específicas da UF da empresa (a única testada foi PE).
- Itens do PLAN-SEGURANCA que citei sem reler o código: IDOR nos endpoints restantes, alerta de acesso cruzado, `FLUSHALL`/`CONFIG` no Redis, revisão manual dos fluxos críticos (Fase 11).
- Se o PostgreSQL de produção aceita o gatilho de somente acréscimo da auditoria com o role sem superuser (testado só em dev).

## 7b. Decisões de arquitetura que o VPS único reabre (precisam da sua resposta)

- **Um ou dois Postgres?** Hoje são dois containers (`gestaofacil_db`, `nfe_db`) por causa da fronteira fiscal (`SECURITY.md`). No mesmo VPS, uma instância com dois bancos e dois roles economiza RAM, mas junta o backup e o domínio de falha. Meu parecer: manter dois bancos separados com roles distintos; decidir entre uma ou duas instâncias depois da medição de A10.
- **Redis compartilhado.** Já é um só, com banco numerado por app (`REDIS_DB` 0-3 no compose de dev). Em produção, manter, mas com senha forte e sem exposição ao host.
- **Janela de manutenção.** Combinar com a empresa o horário de deploy e reinício; o scheduler do DF-e roda às 04:00 e a reconciliação a cada 5 minutos, então deploy fora desses horários.

## 8. Decisões que dependem de você

1. **Onde roda:** o VPS do `PLAN-INFRA.md` (NVMe 4, ~R$ 50/mês com backup) já foi contratado?
2. **Domínios:** nomes reais para front e API.
3. **A empresa vem de outro sistema?** Define E4 e a coordenação do DF-e.
4. **Qual é a UF, o regime e se emite NFC-e**, além de NF-e 55.
5. **Qual certificado** vai para produção: **em aberto (20/10/2026, ainda não definido).** O de dev (`11500611000115`) vence em 02/02/2027 e não se sabe se é da empresa real. Os itens E2 e E3 não começam sem isso.
6. **SMTP:** qual provedor.
7. **Destino dos backups e dos alertas.** Backup automático: **será montado depois pelo Allan (20/10/2026).** O plano mantém C1 a C5 como pré-requisito da primeira nota real: sem backup externo testado, não se liga `environment=1`.
8. **A pasta já saiu desta máquina?** (B3)

## 9. Ordem sugerida e tempo de bloqueio

`A → B → C` (nesta ordem; C4 só é possível com A funcionando) → `D` → `E1-E3` (em paralelo com D) → `E4-E8`.
Nada de `environment=1` antes de C4 e E3 estarem registrados.
