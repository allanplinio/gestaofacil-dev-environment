# PLAN-SEGURANCA.md — Plano de Segurança do GestãoFácil

> Plano vivo. Marque `[x]` conforme for verificado **na prática** (teste rodado, comando executado, comportamento observado), não por leitura de código ou de documento.
> Regra do projeto: nada é "pronto" sem evidência (ver `auditoria-realidade`).

## 0. Contexto e escopo

- **Porte atual:** uma empresa cliente, poucos usuários, v1 (ver `memory/v1_scope_summary.md`).
- **Porte previsto:** até ~10 clientes. O plano separa o que é **obrigatório agora** do que tem **gatilho** para entrar depois (seção 13).
- **Componentes:**

| Componente | Stack | Pasta |
|---|---|---|
| API de Vendas (GestãoFácil) | Laravel 11, PHP 8.3, Sanctum, PostgreSQL, Redis | `gestaofacil-api/` |
| Serviço de NFe | Laravel 11, PHP 8.2+, Sanctum, PostgreSQL, Redis | `nfe-api/` |
| Frontend | React 18 + Vite 5 | `gestaofacil-fe/` |
| Infra local | Docker Compose, Nginx | `gestaofacil-dev-environment/`, `*/docker/` |

- **Documentos já existentes que este plano NÃO repete** (apenas referencia):
  - `SECURITY.md` (raiz) e `gestaofacil-api/SECURITY.md`: isolamento multiempresa, fronteira fiscal, Argon2id, certificado, rate limit, reset de senha.
  - `nfe-api/SECURITY-ERROR-HANDLING.md`: tratamento de erros.
  - `memory/password-hashing-argon2id.md`: hashing de senha.

**Legenda do estado observado** (uma leitura de código/arquivos feita na criação deste plano, não uma auditoria):
- 🟢 indício de controle implementado no código
- 🟡 implementado parcialmente, ou com risco visto
- 🔴 risco concreto encontrado
- ⚪ não verificado ainda

---

## Fase 0 — Higiene imediata (fazer antes de qualquer outra coisa)

Riscos de exposição já existentes no disco.

- [x] 🔴 **Apagar `nfe-api/.env.bak-1789954252`** após confirmar que o `.env` atual tem tudo que precisa. *19/10/2026: removido. Conferido que as chaves são as mesmas do `.env` atual.*
- [ ] 🔴 **Trocar credenciais** que estiveram nesse `.bak` se a pasta já foi copiada, enviada, compartilhada ou sincronizada. *Pendente: depende de informação sua. Não sei se a pasta foi copiada ou sincronizada; se foi, trocar `APP_KEY`, senha do banco, senha do Redis e `NFE_CERT_ENCRYPTION_KEY`. A chave de criptografia dos certificados exige re-cifrar os arquivos (ver Fase 6).*
- [x] 🔴 **Tirar o XML fiscal real da raiz do projeto** (`26260911500611000115650030000000031529430910-nfe.xml`) e mover para pasta fora do repositório. *18/10/2026: movido para `../nfe-xml-privados/`. Fixture de teste anonimizada ainda não feita.*
- [x] 🟡 **Confirmar que `.env`, `.pfx`, `.p12`, `storage/certificates/`, `storage/app/*` não estão versionados.** *19/10/2026: `git ls-files` sem nenhum desses; `.gitignore` cobre `.env`. Histórico completo varrido com gitleaks (ver abaixo).*
- [x] ⚪ **Varredura de segredos no histórico do git** com `gitleaks` nos três repositórios. *19/10/2026: gitleaks 8.18.4 (imagem fixada). `gestaofacil-api` e `gestaofacil-fe`: nenhum achado. `nfe-api`: 2 achados, ambos placeholders de documentação (`.env.example` e `docs/SECRETS_MANAGEMENT.md`); conferidos por hash contra os `.env` atuais, não são chaves em uso. Allowlist estreita em `nfe-api/.gitleaks.toml`. **Ressalva:** quem copiou o `.env.example` antigo não tem chave real nele.*
- [x] ⚪ **Pré-commit com detecção de segredos.** *19/10/2026: `.githooks/pre-commit` nos três repositórios, com `core.hooksPath` configurado. Escaneia o diff do stage com gitleaks. Testado: commit limpo passa; commit com chave AWS falsa é bloqueado. Quem clona precisa rodar `git config core.hooksPath .githooks`.*
- [ ] ⚪ **Permissões de arquivo**: `.env` com `600`, `storage/` gravável só pelo usuário do PHP. *Parcial: `.env` de `gestaofacil-api`, `nfe-api` e do dev-environment em `600`; containers continuam lendo (testado). `storage/` está em `777` no dev porque o php-fpm roda como `www-data` e a pasta é montada do host: restringir sem definir dono e grupo quebra a escrita. Em produção: dono do deploy, grupo `www-data`, `775`.*

---

## Fase 1 — Configuração e ambiente

Problemas clássicos de Laravel/Docker que aparecem em produção.

- [x] 🟡 `APP_DEBUG=false` e `APP_ENV=production` em **qualquer** ambiente que não seja o do desenvolvedor. *19/10/2026: a guarda do `AppServiceProvider` (nas duas APIs) recusa `APP_DEBUG=true` em qualquer ambiente que não seja `local` ou `testing`, staging incluso. Testado: `staging` + debug para o deploy. O `.env.example` continua com debug ligado para o dev; quem sobe produção precisa definir `APP_ENV=production` explicitamente.*
- [x] ⚪ `php artisan config:cache` no deploy (e `config:clear` no dev). *19/10/2026: `scripts/deploy-config.sh` nas duas APIs (`config:clear`, `config:cache`, e no `nfe-api` também `horizon:terminate`). Testado: rodada normal passa; com `staging` + debug para com erro. O script ainda precisa ser chamado pelo processo de publicação, que não existe no repositório.*
- [x] 🟢 Nenhum `env()` chamado fora de arquivos de `config/`. *18/10/2026: teste automatizado nas duas APIs varre `app/` e `routes/`.*
- [ ] ⚪ `APP_KEY` único por ambiente; nunca reutilizado entre dev, homolog e produção. *Parcial: as duas APIs têm chaves diferentes (conferido por hash) e os `.env.example` vêm sem chave. Por ambiente depende do processo de publicação (operacional).*
- [ ] ⚪ Ambientes separados: dev / homolog / produção com credenciais diferentes em cada um. *Parcial: dev já separa bancos de teste (`gestaofacil_test`, `nfe_api_test`) e chaves de cifra. Homologação e produção não existem no repositório.*
- [x] 🟢 Telescope, Horizon, Debugbar e rotas `/_debug` desligados ou protegidos fora de dev. *`gestaofacil-api` não tem nenhum deles. `nfe-api` tem Horizon: teste confirma que visitante anônimo não acessa `/horizon`.*
- [x] 🟢 Página de erro genérica em produção (sem stack trace, sem SQL, sem caminho de arquivo). *Teste em `ConfigSegurancaTest`: a exceção não aparece no corpo da resposta da API. Cobre só rotas `/api`.*
- [x] 🟢 `server_tokens off` no Nginx. *Verificado no nginx em execução (container reiniciado, ver registro): `Server: nginx`. Ainda vaza `X-Powered-By: PHP/8.3`, item da Fase 8.*

---

## Fase 2 — Autenticação e sessão

- [x] 🟢 Senhas com Argon2id (`config/hashing.php`). *Verificado: hash gravado começa com `$argon2id$`. Rehash de hash legado não foi implementado, porque não há hash legado conhecido.*
- [x] 🟢 Rate limit no login e nas rotas de senha. *18/10/2026: `ThrottleLogins` passou a contar por par e-mail+IP (5/min) e por IP (20/min). Testes em `LoginTest`: limite por conta não barra outra conta do mesmo IP, e limite por IP barra varredura de contas.*
- [x] ⚪→🟢 Mensagem de erro de login **igual** para e-mail inexistente e senha errada. *18/10/2026: login verifica a senha antes do status; e-mail inexistente e senha errada devolvem a mesma resposta (`errors.email`). Hash fictício equaliza o tempo. Testes em `LoginTest`.*
- [x] ⚪→🟢 Resposta de "esqueci a senha" **igual** para e-mail existente e inexistente. *Mensagem igual no `PasswordForgotController` (já existia). Pendente abaixo: o tempo de resposta ainda muda quando o e-mail é enviado.*
- [ ] ⚪ *Pendente (novo):* tempo de resposta do "esqueci a senha" muda quando o e-mail existe e é enviado. Solução: enviar por fila, fora da requisição. Depende de worker de fila no ambiente.
- [x] ⚪→🟢 Token de reset de senha: uso único, expira em 60 min, guardado como **hash**, invalidado após uso. *Hash SHA-256 e exclusão após uso no código. Validade alterada de 24 h para 60 min (plano pedia 30–60 min). Testes em `PasswordResetValidadeTest`.*
- [x] ⚪→🟢 Ao trocar a senha: **revogar todos os tokens Sanctum** do usuário. *Feito no reset (`PasswordResetController`) e na troca logada (`UserPasswordController`). Testes existentes em `PasswordResetTest` e `UserPasswordTest` tratam dos tokens.*
- [x] ⚪→🟢 Tokens Sanctum com **expiração** definida. *12 h via `config/sanctum.php` (`SANCTUM_TOKEN_EXPIRATION`). Testes na seção "Sessão" de `LoginTest`. **Ação no deploy:** tokens emitidos antes desta mudança não têm `expires_at` e continuam válidos até revogação; revogar uma vez.*
- [ ] ⚪ **Abilities** mínimas por token. *Pendente (decisão): todo token sai com `*`. Abilities por perfil dependem de definir a matriz de permissões de API.*
- [x] ⚪→🟢 Logout revoga o token atual no servidor. *Código e teste existente: token inválido após logout.*
- [x] ⚪→🟢 Política de senha mínima. *`PasswordStrengthValidator`: mínimo 8, maiúscula, minúscula, número, especial e checagem de senha vazada. Ressalva: se o serviço de checagem falhar, a senha é aceita (falha aberta). Decisão pendente.*
- [ ] ⚪ Cookies de sessão: `Secure`, `HttpOnly`, `SameSite=Lax`. *Não se aplica hoje: autenticação só por token. Revisar se o front passar a usar cookie de sessão.*
- [ ] ⚪ Bloqueio temporário progressivo após falhas repetidas. *Pendente (decisão). O limite por janela já impede força bruta. Não existe bloqueio progressivo.*

---

## Fase 3 — Autorização e isolamento multiempresa (o risco nº 1 do sistema)

Um cliente nunca pode ver ou alterar dado de outro. Esta é a fase mais importante do sistema, e o `SECURITY.md` já a detalha.

- [x] 🟢 Todo model com dado de empresa usa o scope. *Varredura feita: todo model com `empresa_id` em `gestaofacil-api/app/Models` tem `CompanyScope`. Corrigidos nesta rodada: `NfeRequest` e `PasswordChangeHistory`, que tinham `empresa_id` sem o scope.*
- [ ] 🟡 **IDOR testado** em cada endpoint com `{id}`. *Parcial: `Seguranca/IsolamentoEntreEmpresasTest` cobre produto (show, update, delete), cliente, venda, fornecedor, emissão NF-e e seção de PDV. Faltam os demais endpoints com `{id}`: notas de entrada, itens, pagamentos, subrotas de emissão e outros.*
- [x] ⚪→🟢 Aninhamento de itens checado. *Feito por validação explícita em vez de `->scopeBindings()`: `VendaController`, `PdvVendaController` e `NotaEntradaController` confirmam que o item pertence ao pai (`venda_id`, `findOrFail` pelo pai).*
- [ ] ⚪ Teste automatizado "2 empresas" para **cada** endpoint novo. *Regra para o futuro. Nesta rodada não há endpoint novo; o teste base de isolamento foi criado.*
- [x] ⚪→🟢 Matriz de perfis escrita e testada. *Matriz em `App\Support\Permissoes`, espelhada no front e aplicada pelo middleware `RequireArea`. Não usa Policies do Laravel: é uma decisão de arquitetura. Testes em `Seguranca/PerfilTest`.*
- [x] ⚪→🟢 Vendedor não acessa configuração fiscal, usuários nem cancelamento. *Testes em `PerfilTest`: vendedor recebe 403 em usuários, produtos, notas (que incluem o cancelamento) e fiscal.*
- [ ] ⚪ Operações destrutivas exigem permissão própria e registram quem fez. *Pendente (decisão): operador acessa exclusão de produto e de cliente. Exigir permissão própria e registro de autoria é regra de negócio a definir.*
- [x] ⚪→🟢 Nenhum endpoint confia em `empresa_id` vindo do corpo. *Teste: `POST /produtos` com `empresa_id` de outra empresa cria o registro na empresa do usuário.*
- [x] ⚪→🟢 Webhook identifica a empresa pelo registro salvo. *`NfeEmissaoController::webhook` acha a emissão pelo `protocolo_id` e aplica o status na empresa dela. A assinatura HMAC é validada antes.*

---

## Fase 4 — Validação de entrada e injeções

- [x] 🟢 **Mass assignment**: todo model com `$fillable` explícito; nunca `$guarded`. *18/10/2026: varredura automatizada em `Seguranca/EntradaESeguraTest` (nenhum `$guarded` em `app/Models`). Campo `empresa_id` no corpo é ignorado: nota avulsa e produto nascem na empresa do usuário (testes).*
- [ ] ⚪ `FormRequest` com regras para todo endpoint de escrita; `validated()` em vez de `all()`. *Parcial: a validação é feita com `$request->validate()` nos controllers, que é o padrão do projeto. `NfeEmissaoController` ainda passa `$request->all()` ao serviço, que monta o payload só com campos conhecidos (`FormularioNotaAvulsa` e `$campos` do rascunho). Trocar por `FormRequest` é refatoração, não correção.*
- [x] 🟢 Nenhum `DB::raw`, `whereRaw`, `orderByRaw` ou `selectRaw` com valor do usuário. *Varredura case-insensitive em `app/`: a única ocorrência é o `orWhereRaw` de `Cliente::scopeBuscar`, com valor ligado (`?`) e só dígitos. Exceção documentada no teste. Ordenação: todos os `orderBy` usam colunas fixas; nenhum parâmetro de ordenação vem do usuário.*
- [x] 🟢 Busca `LIKE` com `%` e `_` escapados. *`Support\Busca::contem()` em Cliente, Produto e Fornecedor. Teste: buscar `%` e `_` acha só o texto literal.*
- [x] 🟢 Validação de CPF/CNPJ com dígito verificador. *`ValidCpfCnpj` nos clientes. Os testes de CPF e CNPJ inválidos conferem a mensagem da regra (usavam `toBeDefined`, que não existe no Pest; era falha de baseline). Fornecedor não tem CNPJ digitado: vem do XML importado.*
- [ ] ⚪ Valores monetários e quantidades calculados no backend. *Total e subtotal são calculados no `VendaService` a partir de quantidade e preço; `valor_total` do corpo não é validado nem gravado. Verificado por leitura, sem teste. **Decisão pendente:** o preço unitário informado pelo usuário é aceito (negociação). Se deve exigir permissão própria, é regra de negócio.*
- [x] 🟢 Limite de tamanho em todo campo de texto e em listas. *Campos de texto com `max`. Listas: nota avulsa com teto de 990 itens (NF-e) e 120 (NFC-e, já existia); PDV com teto de 500 itens; itens de venda entram um a um.*
- [x] 🟢 **Upload de arquivo** (certificado `.pfx`, XML de importação):
  - validar por conteúdo real: o certificado é aberto com `openssl_pkcs12_read` no `nfe-api` (com a senha); o XML passa pelo `LeitorXmlNfe`, que recusa o que não é NF-e;
  - tamanho máximo: 2 MB no gestaofacil (certificado e XML) e 5 MB no `nfe-api`;
  - nome gerado pelo servidor: o certificado é gravado pelo ID; o XML de importação não é gravado, é lido em memória;
  - fora da raiz web: certificado em `storage_path('certificates')` (diretório `0700`, arquivo `0400`); nada em `public/`.
  - *18/10/2026: verificado por leitura do código e da configuração (`config/nfe.php`), sem teste automatizado de upload.*
- [x] 🔴 **XML de importação (XXE e "billion laughs")**: ao ler XML de NF-e (`PLAN-IMPORTACAO-XML.md`), **não** usar `LIBXML_NOENT`; usar `LIBXML_NONET`; rejeitar DOCTYPE com entidades. Teste com um XML que tenta ler `/etc/passwd` e um com entidades aninhadas. Esse risco é fácil de cair por ser "só XML".
  - *18/10/2026, `gestaofacil-api`:* `LeitorXmlNfe` já recusa `DOCTYPE`/`ENTITY` antes do parse e usa `LIBXML_NONET`, sem `NOENT`/`DTDLOAD`. Coberto por `tests/Unit/Compras/LeitorXmlNfeTest.php` (fixture `com-doctype.xml`).
  - *18/10/2026, `nfe-api`:* `ProcessNfeEventoJob::protocoloAutorizacao` passou a usar `LIBXML_NONET`. Teste "XML de autorizacao com entidade externa..." em `tests/Feature/Events/NfeEventoXmlTest.php`. Atenção: o teste protege contra regressão; sem o `NONET`, ele já passaria, porque o libxml não substitui entidade externa sem `NOENT`.
  - *18/10/2026:* entidades aninhadas ("billion laughs") são recusadas antes do parse (`Seguranca/EntradaESeguraTest`). Zip bomb não se aplica: o fluxo não aceita ZIP.
- [x] 🟢 Importação em ZIP: limite de tamanho descompactado e de número de arquivos. *N/A: a importação aceita só XML (`mimetypes:application/xml,text/xml,text/plain`, 2 MB). A regra volta a valer se ZIP entrar.*
- [x] 🟢 **SSRF**: URL que o servidor busca passa por lista de permissão e bloqueia rede interna. *No gestaofacil nenhuma URL vem do usuário (são de configuração). No `nfe-api`, o destino do webhook cadastrado no painel é validado: https em produção e sem IP privado, reservado ou loopback, inclusive `169.254.169.254` (`WebhookUrlSegura`, testes em `Seguranca/WebhookUrlSeguraTest`). **Limite conhecido:** confere o host digitado, não o IP que o DNS resolve (DNS rebinding). Fechar isso exige checagem no envio; fica como decisão.*
- [x] 🟢 **Open redirect**: parâmetros de redirecionamento só aceitam caminhos internos. *N/A: não há `redirect()` no código da aplicação (varredura).*
- [x] 🟢 **Formula injection (CSV)**: exportação escapa células que começam com `= + - @`. *N/A hoje: não há exportação CSV nem planilha no código. A regra vale quando houver.*
- [x] 🟢 Deserialização: nada de `unserialize()` em dado externo; nada de `eval`/`exec`/`shell_exec` com entrada. *Varredura automatizada no gestaofacil (`Seguranca/EntradaESeguraTest`) e varredura por grep no `nfe-api`, sem ocorrências em ambos.*

---

## Fase 5 — Integração com o `nfe-api` (M2M e webhook)

- [x] 🟢 Assinatura HMAC no webhook, com comparação em tempo constante. *Verificado: `WebhookDispatcher::sign` (`hash_hmac` sha256) no `nfe-api`; `validateWebhookSignature` compara com `hash_equals` na gestaofacil. Testes de rotação em `Seguranca/EntradaESeguraTest`.*
- [ ] ⚪ **Anti-replay**: timestamp na assinatura, janela de 5 min e `event_id` já processado. *Decisão: não implementado. O timestamp exige mudança coordenada nos dois lados. O estrago de um replay (regredir o status da nota) já é bloqueado pela trava de estado final (teste "webhook com status anterior ao já gravado"). Reabrir se o webhook passar a carregar algo que não é status (valor, ação).*
- [x] 🟢 Webhook só aceita o IP/rota esperado, ou tem segredo por empresa. *Segredo por cliente no `nfe-api` (`webhook_secret` de cada `SystemClient`). Restrição por IP fixo não implementada: os ambientes de container mudam de IP. Decisão.*
- [x] 🟢 Token M2M (Bearer) do `nfe-api` **por cliente**, com rotação sem derrubar os outros. *Tokens Sanctum por `SystemClient`, com `nfe:client-token` e `nfe:client-revoke-tokens` (ver `nfe-api/CLAUDE.md`).*
- [x] 🟢 Segredo do webhook **rotacionável** (aceitar o antigo e o novo por um período). *`API_NFE_TOKEN_SECRET_ANTERIOR` é aceito durante a troca (testes). Esvaziar depois que a fila estiver limpa.*
- [ ] ⚪ Timeout e limite de tamanho de resposta no cliente HTTP. *Timeouts explícitos: 30 s em todas as chamadas da gestaofacil (`NfeApiClient`) e 10 s no webhook do `nfe-api`. **Pendente:** limite de tamanho da resposta, não configurado.*
- [x] 🟢 O `nfe-api` **não ecoa o emitente inteiro** na resposta para a API de Vendas. *Verificado por leitura: nenhuma resposta do `nfe-api` às rotas da API de Vendas inclui o emitente; `statusPayload` não tem emitente. Sem teste de contrato.*
- [x] 🟢 **Idempotência na emissão**: reenvio do mesmo pedido não gera duas NF-e. *`id_externo` no `POST /nfe` (`nfe-api/tests/Feature/Nfe/NfeIngestTest`) e reenvio com a mesma chave pela gestaofacil (`EnvioIdempotenteEReconciliacaoTest`).*
- [x] 🟢 Ambiente (homolog/produção) é propriedade **do registro**, validada dos dois lados. *O `nfe-api` deriva o `environment` do certificado (`NfeIngestController`); a gestaofacil só exibe o campo `ambiente`.*

---

## Fase 6 — Dados sensíveis e criptografia

- [ ] 🟢 Certificado `.pfx` guardado no `nfe-api`, fora da API de Vendas (ver `SECURITY.md` §3). **Verificar:** `Schema::hasColumn` e teste de fronteira rodando de fato.
- [ ] 🟢 `nfe_api_token_id` criptografado com `Crypt::encryptString()` (indício em `SECURITY.md`). **Verificar** que o campo está em `$casts` como `encrypted`.
- [ ] ⚪ Arquivo `.pfx` com permissão `0400` em diretório `0700` (ver `SECURITY.md` item de checklist).
- [ ] ⚪ Senha do certificado: criptografada com chave **separada** de `APP_KEY` (`NFE_CERT_ENCRYPTION_KEY`), nunca em log.
- [ ] ⚪ Nenhuma cópia decifrada do certificado em `/tmp` ou `storage/app` (teste com `Storage::fake()` e checagem do disco).
- [ ] ⚪ **Campos sensíveis fora de log**: senha, token, `.pfx`, senha do certificado, `Authorization`, CSC. Filtro no logger (`SECURITY.md` §Campos Sensíveis).
- [ ] ⚪ Dados pessoais (CPF, e-mail, endereço de cliente): só o necessário (minimização) e documentados em `DATA-MODEL.md`.
- [ ] ⚪ Plano de **rotação da chave de criptografia**: procedimento escrito e testado em homolog (re-criptografar tudo, inclusive `.pfx`).
- [ ] ⚪ Backups criptografados e com a chave guardada **separada** do backup.

---

## Fase 7 — Frontend (React + Vite)

- [x] 🟢 Nenhum `dangerouslySetInnerHTML` com dado vindo da API. *18/10/2026: varredura do `src/` sem ocorrências.*
- [x] 🟢 **Token de sessão**: decisão registrada. *Fica em `localStorage`, não em cookie `HttpOnly`. Migrar para cookie exige o fluxo SPA do Sanctum (CSRF e domínio compartilhado). Mitigação: sem HTML dinâmico, CSP sem `unsafe-inline` em script, expiração de 12 h. Registrado no `PROGRESS.md` do front.*
- [x] 🟢 Nenhum segredo em variável `VITE_*`. *Única variável é `VITE_API_URL`, a URL pública da API.*
- [x] 🟢 `sourcemap` desligado em produção. *`vite.config.ts` com `sourcemap: false`; build verificado: nenhum `.map` gerado.*
- [x] 🟢 Content-Security-Policy definida (sem `unsafe-inline` para script). *`serve.json` do front: `script-src 'self'`, `style-src 'self' 'unsafe-inline'`, `frame-ancestors 'none'`. Verificado com `curl` no `serve` da build. **Pendente:** conferir no console do Firefox que nada é bloqueado. **Ressalva:** `connect-src 'self'` exige a API na mesma origem; se a API ficar em outra, a origem entra na lista (está no Dockerfile).*
- [x] 🟢 `npm audit --omit=dev` sem vulnerabilidade alta/crítica no build de produção. *18/10/2026: 0 alta, 0 crítica, 2 moderadas em `react-router-dom` 6.30.6 (corrigida só na 7, mudança de versão maior). **Decisão pendente.***
- [ ] ⚪ Lockfile versionado e instalação com `npm ci` no CI. *Lockfile versionado e `npm ci` no Dockerfile de produção (antes era `npm install`). **Pendente:** o repositório do front não tem CI.*
- [ ] ⚪ Tratamento de 401 no front: limpa sessão e redireciona; 403 não mostra dado parcial. *401 verificado no `services/api.ts` (limpa o token e vai para o login). **Pendente:** comportamento de 403 não foi conferido tela a tela.*
- [x] 🟢 Ocultar na UI não basta: toda ação restrita também é bloqueada no backend. *Coberto na Fase 3 (`PerfilTest`, `RequireArea`).*
- [x] 🟢 Dados de NF-e e de certificado não ficam persistidos no navegador. *Varredura: o `localStorage` guarda só o token e preferências de tela do PDV; sem `persist` do zustand e sem IndexedDB.*

---

## Fase 8 — Infraestrutura, Docker e rede

- [ ] ⚪ Containers rodando com **usuário não-root** (`USER` no Dockerfile). *Frontend de produção: `USER node` (18/10/2026). APIs: sem Dockerfile de produção no repositório; o php-fpm roda os workers como `www-data`. **Pendente** para a imagem de produção das APIs.*
- [ ] ⚪ **Portas de banco e Redis não expostas** no host em produção. *Desenvolvimento expõe 5432, 5433 e 6379 em `localhost` (aceito e documentado). **Pendente:** não há compose de produção no repositório.*
- [ ] ⚪ Redis com `requirepass` e sem comandos perigosos expostos. *18/10/2026: `requirepass` ativo no compose de dev (`REDIS_PASSWORD`); sem senha o Redis recusa (`NOAUTH`), e as duas APIs conectam com o cache regenerado. **Pendente:** renomear `FLUSHALL` e `CONFIG`, e exigir senha forte em produção.*
- [ ] ⚪ PostgreSQL: usuário da aplicação **sem superuser**. *Pendente. A imagem `postgres` cria o `POSTGRES_USER` como superusuário, então o usuário da aplicação em dev é superusuário. Em produção: criar um role dono do próprio banco, sem superuser.*
- [ ] ⚪ Imagens Docker com versão fixada e varredura de vulnerabilidade. *Parcial: nenhuma imagem usa `latest`; `nginx:1.27-alpine` fixa a minor, `postgres:16-alpine`, `redis:7-alpine` e `node:20-alpine` fixam só a major. `trivy` não está instalado, então a varredura **não foi executada**.*
- [ ] ⚪ Nginx: HTTPS obrigatório (TLS 1.2+), redirect de HTTP, HSTS, `X-Content-Type-Options`, `X-Frame-Options` / `frame-ancestors`, `Referrer-Policy`. *Cabeçalhos verificados no nginx de dev: `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Server: nginx` sem versão. **Pendente:** TLS, redirect e HSTS (dependem de certificado e de produção).*
- [x] 🟢 CORS restrito à origem do front (nunca `*` com credenciais). *`gestaofacil-api`: `config/cors.php` com origens por `CORS_ALLOWED_ORIGINS` (testes em `CorsTest`); em execução, a origem do front recebe o próprio cabeçalho e uma origem estranha não recebe nenhum. `nfe-api`: sem origens, por ser só servidor a servidor.*
- [x] 🟢 Limite de tamanho de corpo no Nginx para os uploads. *`client_max_body_size` de 32 MB para 8 MB (maior upload legítimo: 5 MB). Verificado: corpo de 9 MB recebe 413.*
- [x] 🟢 Timeouts de conexão e leitura definidos. *`proxy_connect_timeout 75s`, `proxy_read_timeout 300s`, `fastcgi_read_timeout 300s` (a leitura longa cobre a SEFAZ).*
- [ ] ⚪ Rede de produção separada: API de Vendas, `nfe-api`, bancos e Redis em redes diferentes. *Pendente. Em dev, tudo está em uma rede (`gestaofacil_net`). Não há compose de produção no repositório.*
- [ ] ⚪ Acesso SSH por chave, sem login por senha, e sem acesso root direto. *Fora do repositório: operacional, a conferir no servidor.*
- [ ] ⚪ Firewall (UFW ou equivalente) liberando só 22 (restrito), 80 e 443. *Fora do repositório: operacional, a conferir no servidor.*

---

## Fase 9 — Logs, auditoria e erros

- [x] 🟢 Log estruturado com `request_id`, `empresa_id`, `user_id`, IP, e sem dado sensível. *19/10/2026: `IdentificaRequisicao` (cabeçalho `X-Request-Id`, validado contra quebra de linha) e `Context` com empresa, usuário e IP em `EnscopeToCompany`. Verificado no log: `{"request_id":"..."}`. Dado sensível: os logs da aplicação não recebem corpo de requisição nem token (varredura).*
- [~] 🟡 Eventos auditados: login (sucesso e falha), criação/alteração de usuário (inclui perfil), alteração de configuração fiscal (inclui certificado enviado), emissão, descarte, cancelamento, CC-e, inutilização e acesso negado. *19/10/2026: tabela `auditoria_eventos` com `Auditoria::registrar()` nesses pontos, testada. Troca de senha já tinha histórico próprio (`password_change_history`), não duplicado. Pendente: `nfe-api` não grava trilha própria além de `nfe_logs`, sem a trava de somente acréscimo.*
- [x] 🟢 Tabela de auditoria **somente acréscimo**. *Trigger no Postgres (`auditoria_sem_alteracao`, `auditoria_sem_truncate`) recusa UPDATE, DELETE e TRUNCATE; testado nos três casos. Ressalva: quem tem superusuário no banco remove o trigger; em produção, o usuário da aplicação não pode ser superusuário (Fase 8).*
- [~] 🟡 Logs de falha de autenticação e de tentativa de acesso cruzado (IDOR) com alerta. *Falha de login e acesso negado por perfil ficam na trilha. **Pendente:** alerta (não há canal de alerta no projeto) e registro de 404 de acesso cruzado (hoje é indistinguível de recurso inexistente).*
- [~] 🟡 Retenção de log definida (90 dias) e rotação configurada. *Logs: canal `daily` com 90 dias de retenção, nas duas APIs (testado). **Pendente:** a trilha `auditoria_eventos` não tem purga: é registro fiscal, e a retenção depende de decisão com o contador.*
- [ ] ⚪ Logs enviados para fora do próprio servidor (ou ao menos cópia periódica). *Pendente: infraestrutura de envio (não existe no repositório).*
- [x] 🟢 Sem `dd()`, `var_dump()`, `console.log` de dado real em código de produção (grep no CI). *19/10/2026: varredura de `dd`, `dump`, `var_dump` e `print_r` nas duas APIs sem ocorrência. Front: 5 `console.log` removidos de `ConfigNfeNaturezas.tsx` (dois imprimiam a resposta com a configuração fiscal). O grep no CI está no workflow do front.*

---

## Fase 10 — Dependências, supply chain e CI

- [x] 🟢 `composer audit` e `npm audit` no CI, falhando em vulnerabilidade alta/crítica. *19/10/2026: gate PHP (`scripts/audit-gate.php`, nas duas APIs) reprova advisory alta ou crítica, ou sem severidade, que não esteja em `.audit-aceitas` com prazo. `npm audit --omit=dev --audit-level=high` no front. **Pendente:** a advisory de CRLF do `laravel/framework` (alta) não tem correção dentro do Laravel 11. Está aceita até 31/12/2026 com mitigação (`not_regex` em todo campo de e-mail, testado). Decisão: migrar para Laravel 12.*
- [x] 🟢 Dependabot ativo para Composer, npm, Docker e GitHub Actions. *Arquivos `.github/dependabot.yml` nos três repositórios. Não verificado no GitHub: só entra em ação depois do push.*
- [x] 🟢 `composer.lock` e `package-lock.json` versionados. *`composer.lock` do gestaofacil-api estava no `.gitignore`: removido do ignore e versionado. Havia divergência real entre lock e manifesto (`predis` 3.6 contra `^2.3`): lock alinhado ao manifesto. Redis testado em execução com a versão nova.*
- [x] 🟢 Ações do GitHub Actions fixadas por **SHA**. *`actions/checkout` v4.2.2, `actions/setup-node` v4.4.0 e `shivammathur/setup-php` v2, com SHA resolvido por `git ls-remote`. actionlint sem erros.*
- [x] 🟢 Permissões mínimas no workflow (`permissions: contents: read`). *Nos três workflows.*
- [~] 🟡 SAST básico no CI: `semgrep` com regras de PHP/Laravel e JavaScript/React. *Job no CI com semgrep 1.120.0 (fixado). Controle positivo: detecta execução de comando com entrada do usuário. **Cobertura parcial:** o parser não lê `readonly` em propriedades promovidas (`CertificateService` e `CertificateStorage` do nfe-api, que lidam com certificado) nem `satisfies` em `src/types/index.ts`. Esses arquivos não são analisados.*
- [x] 🟢 Testes de segurança rodando no CI (Fase 11). *Job de testes nos dois serviços de API, com Postgres. Em `gestaofacil-api`, `Seguranca`, `Auth` e `MultitenancyTest`. O workflow antigo apontava para `SecurityTest.php` (inexistente) com `continue-on-error`, e para `scripts/check-security.php`, que não compilava: corrigidos.*
- [ ] ⚪ Branch principal protegida: revisão obrigatória e CI verde antes do merge. *Pendente: configuração no GitHub. Não tenho acesso (o `gh` não está instalado) e não altero configuração de repositório sem você.*

---

## Fase 11 — Testes de segurança

Cada item vira teste automatizado, rodando no CI.

- [ ] ⚪ Testes de isolamento entre empresas (Fase 3) para todo endpoint.
- [ ] ⚪ Testes de autorização por perfil (matriz da Fase 3), negando o que deve ser negado.
- [ ] ⚪ Testes de entrada maliciosa: SQL, XSS armazenado, mass assignment, payload gigante, caracteres de controle, Unicode estranho.
- [ ] ⚪ Testes de XXE e de zip bomb na importação.
- [ ] ⚪ Testes de webhook: assinatura errada, replay, timestamp antigo, duplicidade.
- [ ] ⚪ Testes de rate limit (o bloqueio acontece e volta depois da janela).
- [ ] ⚪ Testes de fronteira fiscal (`SECURITY.md` §Checklist), que já estão previstos e precisam rodar.
- [ ] ⚪ Varredura **dinâmica** (DAST) contra homolog com OWASP ZAP (baseline), pelo menos antes de cada entrega ao cliente.
- [ ] ⚪ Revisão manual dos fluxos críticos: login, reset de senha, emissão, cancelamento, upload de certificado.
- [ ] ⚪ Registro do resultado: data, versão, o que foi testado, o que falhou e o que ficou em aberto.

---

## Fase 12 — Continuidade: backup, recuperação e incidente

- [ ] ⚪ Backup automático diário do PostgreSQL, com **teste de restauração** feito de fato (backup que nunca foi restaurado não conta).
- [ ] ⚪ Backup dos arquivos (`.pfx`, XML emitido, DANFE, dados de inutilização) — esses são obrigatórios por lei; a retenção é mínima de 5 anos para XML/fiscal (confirmar com o contador).
- [ ] ⚪ Backup **criptografado**, com cópia fora do servidor principal.
- [ ] ⚪ RPO e RTO definidos por escrito (quanto dado posso perder, em quanto tempo volto).
- [ ] ⚪ **Plano de resposta a incidente** escrito: quem é avisado, como isolar (revogar tokens, trocar chaves, desligar integração), em quantas horas comunicar o cliente.
- [ ] ⚪ Procedimento de **revogação de todos os tokens** e rotação de segredos, testado em homolog.
- [ ] ⚪ Contato de quem reporta vulnerabilidade (`security.txt` ou e-mail) publicado.

---

## Fase 13 — Preocupações futuras (com gatilho)

Estes itens **não** entram na v1, mas cada um tem um sinal que obriga a tratá-lo. Não implementar antes do gatilho; não esquecer depois dele.

| Preocupação | Gatilho para tratar | Por quê |
|---|---|---|
| **MFA (2FA)** para Admin | Antes do 2º cliente, ou quando houver perfil Admin que mexe em fiscal | Admin comprometido = todas as notas da empresa |
| **MFA obrigatório** para todos | Antes de liberar acesso pelo celular/público | Senha vazada é o caso mais comum |
| **SSO / OAuth** (Google, Microsoft) | Cliente com equipe grande pedir | Reduz gestão de senha, mas exige validar a identidade do provedor |
| **Separação de banco por cliente** | Cliente com exigência contratual de isolamento físico, ou dado muito sensível | O isolamento lógico hoje é suficiente; físico é mais caro de operar |
| **Row Level Security no PostgreSQL** | Antes de 5 clientes, como segunda barreira ao `CompanyScope` | Se o scope falhar em um model, o banco ainda bloqueia |
| **Cofre de segredos** (Vault, AWS/GCP Secrets Manager, Doppler) | Quando passar de 1 servidor ou 3 pessoas com acesso à produção | `.env` em disco não escala para rotação e auditoria |
| **KMS para a chave de criptografia** | Quando o volume de certificados crescer ou houver auditoria externa | Chave mestra fora da aplicação |
| **WAF e proteção DDoS** (Cloudflare etc.) | Ao expor a API à internet pública com cliente pagando | Filtra tráfego ruim e esconde a origem |
| **Monitoramento e alertas** (SIEM, Sentry, uptime) | Antes de 5 clientes | Ver incidente antes do cliente reclamar |
| **Pentest externo** | Antes do 1º contrato com empresa grande, ou a cada 12 meses | Olhar independente acha o que a equipe não vê |
| **Programa de divulgação de vulnerabilidade / bug bounty** | Quando o produto for público | Canal formal para receber relatório |
| **Conformidade LGPD formal** (DPO, RIPD, política de privacidade, base legal por dado) | Antes de coletar dado de pessoa física em escala | Obrigação legal, com multa |
| **Retenção e exclusão de dados** (direito ao esquecimento) | Primeiro pedido de exclusão de cliente, ou antes de 5 clientes | Conflito com obrigação fiscal de guardar XML: precisa regra escrita |
| **Rotação automática de senhas de integração** | Quando houver mais de um `nfe-api` ou integração de terceiros | Rotação manual esquece |
| **Auditoria de acesso do próprio suporte** (quem da equipe viu dado de qual cliente) | Quando alguém além do dev acessar produção | Acesso interno também é ameaça |
| **Isolamento de ambiente de NFC-e/PDV** (CSC e certificado extra) | Quando o PDV (v2) entrar | Novo segredo, nova superfície |
| **Testes de carga com viés de segurança** (abuso de API, enumeração em escala) | Antes de 10 clientes | Limite de taxa precisa ser testado sob carga |
| **Política de senha por perfil** e expiração | Quando a auditoria do cliente pedir | Hoje a política de senha forte é suficiente |
| **Segregação de ambiente de homologação SEFAZ x produção** em nuvem separada | Quando houver cliente em produção real | Evita dado fiscal real em homolog |
| **Revisão periódica de acessos** (trimestral) | Quando houver mais de 3 usuários internos da equipe | Acesso antigo que ninguém removeu |

---

## Como usar este plano

1. Marcar `[x]` só depois de **verificar na prática** (teste, comando, comportamento). Leitura de código não basta.
2. Fase 0 e Fase 1 primeiro: são as mais baratas e as que mais evitam dano real.
3. Fase 3 (isolamento) e Fase 4 (XXE, SSRF, upload) são as que mais importam para o negócio. Não deixar para depois.
4. A cada entrega ao cliente, rodar a Fase 11 inteira e registrar o resultado.
5. Ao concluir um item que altera o comportamento de segurança, registrar a decisão no `PROGRESS.md` (ver `memory/feedback_portao_de_etapa.md`).
6. Itens da Fase 13 entram aqui quando o gatilho acontecer, com a data em que o gatilho foi atingido.
7. **Atualizar este plano ao final de cada tarefa pedida**, com os `[x]` verificados, o commit ou o arquivo alterado e o que ficou pendente. Vale também quando a tarefa foi bloqueada: registrar o bloqueio.

---

## Registro de execução

### 18/10/2026: Fase 0 (itens 1 a 3) e XXE

| Item | Resultado | Evidência |
|---|---|---|
| XML fiscal fora da raiz | ✅ feito | movido para `../nfe-xml-privados/` (fora do repositório) |
| Referência ao XML em `PLAN-IMPORTACAO-XML.md` | ✅ atualizada | texto da seção 3.2 aponta para o novo local |
| Apagar `nfe-api/.env.bak-1789954252` | ⛔ bloqueado | o classificador de ações destrutivas negou a exclusão; o arquivo continua no disco. Aguarda confirmação explícita |
| Trocar credenciais do `.bak` | ⚪ pendente | depende de saber se a pasta foi copiada ou sincronizada |
| XXE na `gestaofacil-api` (`LeitorXmlNfe`) | ✅ já existia | recusa `DOCTYPE`/`ENTITY`, `LIBXML_NONET`, teste em `LeitorXmlNfeTest.php` |
| XXE na `nfe-api` (`ProcessNfeEventoJob`) | ✅ feito | commit `5de69f2` em `origin/master` (push confirmado); teste novo em `NfeEventoXmlTest.php` |

Verificação da `nfe-api`: arquivo de eventos com 26 testes passando. Suíte completa com 385 passando e 4 falhas, todas da baseline pré-existente (`CertificateExpirationTest`, `CircuitBreakerRecoveryTest`, `NaturezaOperacaoCrudTest`, `NfePollingTest`).

Ressalva: o teste de XXE novo protege contra regressão, mas passaria sem o `LIBXML_NONET`, porque o libxml não substitui entidade externa sem `NOENT`.

Pendências desta rodada:
- Confirmar a exclusão do `.env.bak` e decidir sobre a troca de credenciais.
- Fixture anonimizada para o XML de NFC-e (mod 65).
- Testes de "billion laughs" e de zip bomb na importação.
- Versionar os `PLAN-*.md` da raiz: ela não é repositório git, então nenhum desses arquivos tem histórico.
- Verificar o histórico do git com `gitleaks` ou `trufflehog` (o `git ls-files` está limpo para `.env` e `.pfx`, mas não olhou o histórico).

### 18/10/2026: Fases 1, 2 e 3 (implementação e verificação)

Commits enviados para `origin/master`:
- `gestaofacil-api` `c8eb29f`: login sem enumeração, limite por conta e IP, reset em 60 min, tokens Sanctum com expiração de 12 h, `CompanyScope` em `NfeRequest` e `PasswordChangeHistory`, guarda de `APP_DEBUG` em produção, `server_tokens off` no `docker/nginx.conf`.
- `nfe-api` `89e5a49`: guarda de `APP_DEBUG` em produção e testes de configuração (env, Horizon).

Fora do git: `gestaofacil-dev-environment/nginx/default.conf` recebeu `server_tokens off`. Esse diretório não é repositório. O nginx foi reiniciado para recarregar o arquivo montado.

Testes:
- `gestaofacil-api`: suíte completa com 687 passando e 7 falhas. As 7 são a baseline conhecida da memória (`ClienteTest` de CPF/CNPJ, `NaturezaOperacaoTest` e `NfeEmissaoTest`), não regressão.
- `nfe-api`: suíte completa com 389 passando e 4 falhas. As 4 são a baseline conhecida (`CertificateExpirationTest`, `CircuitBreakerRecoveryTest`, `NaturezaOperacaoCrudTest`, `NfePollingTest`).

Ações pendentes para o deploy e para o usuário:
- **Revogar tokens Sanctum antigos** uma vez no deploy: eles não têm `expires_at` e continuam válidos.
- **Confirmar a exclusão do `nfe-api/.env.bak-1789954252`** (bloqueada na rodada anterior).
- **Painel Filament do `nfe-api`** exige login, mas não existe model `User` no projeto. Verificar se o painel está inoperante ou usa algo fora do repositório antes de considerar a Fase 2 de senhas fechada para o `nfe-api`.
- **Decisões de produto pendentes:** abilities por token; permissão própria para exclusões; bloqueio progressivo; falha aberta da checagem de senha vazada.
- **Tempo de resposta do "esqueci a senha"** depende de envio por fila.
- **`X-Powered-By: PHP/8.3`** ainda aparece nas respostas (Fase 8).

### 18/10/2026: Fases 4 e 5 (implementação e verificação)

Commits enviados para `origin/master`:
- `gestaofacil-api` `c0bd918`: busca com curingas literais (`Support\Busca`), teto de itens da NF-e (990), teto de 500 itens no PDV, slug de naturezas restrito, trava de estado final no webhook, rotação do segredo (`API_NFE_TOKEN_SECRET_ANTERIOR`), correção dos testes de CPF/CNPJ.
- `nfe-api` `a844321`: `WebhookUrlSegura` no cadastro do cliente (https e sem rede interna em produção).

Decisões desta rodada (registradas no plano, não implementadas):
- **Anti-replay por timestamp:** não. A trava de estado final já impede o dano de um replay, e o timestamp exigiria mudança coordenada nos dois lados.
- **Restrição de webhook por IP:** não. Segredo por cliente já existe, e os ambientes de container mudam de IP.
- **Preço unitário informado pelo usuário:** mantido (negociação). Se deve exigir permissão própria, é regra de negócio.
- **SSRF por DNS rebinding:** limite conhecido. A regra confere o host digitado.

Testes:
- `gestaofacil-api`: 705 passando e 5 falhas. As 5 são a baseline (`NaturezaOperacaoTest` e `NfeEmissaoTest`). Duas falhas de `ClienteTest` deixaram de existir: o teste usava `toBeDefined`, que não existe no Pest.
- `nfe-api`: 402 passando e 4 falhas, a baseline conhecida.

Pendências:
- Limite de tamanho da resposta HTTP no cliente (Fase 5).
- `FormRequest` em todo endpoint de escrita (refatoração, não correção).
- Teste de valor de venda ignorado no corpo (`valor_total`): verificado por leitura, sem teste.
- Decisões: permissão para preço manual, abilities, anti-replay e IP do webhook (listadas acima).

### 18/10/2026: Fases 7 e 8 (implementação e verificação)

Commits:
- `gestaofacil-fe` `c92f6a3`: sourcemap desligado, `serve.json` com CSP e cabeçalhos, Dockerfile com `npm ci`, `serve` fixo, usuário `node`; decisão do token em `PROGRESS.md`.
- `gestaofacil-api` `9734acb`: `config/cors.php` restrito à origem do front; teste `CorsTest`; varredura de SQL cru case-insensitive.
- `nfe-api` `f7af440`: `config/cors.php` sem origens de navegador; teste `CorsTest`.
- Fora do git (`gestaofacil-dev-environment` não é repositório): `nginx/default.conf` com cabeçalhos de segurança e limite de 8 MB; `docker-compose.yml` com `CORS_ALLOWED_ORIGINS`.

Testes:
- `gestaofacil-api`: 708 passando e 5 falhas da baseline.
- `nfe-api`: 403 passando e 4 falhas da baseline.
- Build do front: passa, sem mapas de código-fonte. `serve` com a CSP verificado com `curl`.

**Achado prioritário (bloqueia parte da Fase 1 e da Fase 8):**
- `gestaofacil-api/config/` tem só `filesystems`, `hashing`, `sanctum`, `services`. **`app.php`, `database.php`, `cache.php`, `logging.php` e os demais nunca foram commitados** (o histórico não tem nenhum deles). Um clone limpo não sobe.
- A aplicação roda de `bootstrap/cache/config.php` (gerado em 22/09). Por isso, mudanças em `config/` (Sanctum, webhook, CORS) **não estão ativas no runtime** até o cache ser regenerado. Os testes passam porque usam outro cache.
- Regenerar o cache agora é arriscado: os arquivos que faltam definem provedores e conexões.
- **Decisão necessária:** restaurar os arquivos a partir do esqueleto do Laravel 11, com os valores vindos de `env()`, e só então regenerar o cache. Depois disso passam a valer: senha no Redis, expiração do Sanctum e CORS.

Pendências desta rodada:
- Restaurar `config/` do `gestaofacil-api` e regenerar o cache.
- Verificar no Firefox que a CSP não bloqueia nada na tela.
- Decisão: migrar `react-router-dom` para a versão 7 (corrige a advertência moderada).
- Imagem de produção das APIs, compose de produção, TLS, HSTS, redes separadas e usuário sem superuser no PostgreSQL.
- Rodar `trivy` nas imagens.

**Resolvido em 18/10/2026 (mesma rodada, após aprovação):**
- `config/` do `gestaofacil-api` e do `nfe-api` restaurado a partir do esqueleto do Laravel 11, com valores de `env()`. Commits `1b5c9bd` e `acb9a18`.
- Conferência contra o cache antigo, chave por chave. Diferenças aceitas: Sanctum com 12 h (estava `null`), CORS restrito, senha do Redis, segredo anterior do webhook e `locale` `pt_BR` (vem do `.env`; o cache antigo tinha `en`, defasado). Tudo isso agora vale em execução.
- Ao reconstruir o `nfe-api`, o disco `local` estava para mudar para `storage/app/private` (padrão novo do Laravel). Corrigido para `storage/app`, porque é onde estão os XMLs e DANFEs.
- Caches regenerados nas duas APIs. Suítes: `gestaofacil-api` 708 passando e 5 da baseline; `nfe-api` 403 e 4 da baseline. Smoke test: API e nfe respondem, CORS correto.
- Pendente: `config:cache` no deploy (ainda não há script de deploy no repositório).

### 19/10/2026: Fases 0 e 1 (implementação e verificação)

Commits (enviados para `origin/master`):
- `gestaofacil-api` `f86585f`: guarda de `APP_DEBUG` para qualquer ambiente que não seja local/testing; `scripts/deploy-config.sh`; hook de pré-commit.
- `nfe-api` `44cc59d`: mesma guarda; `scripts/deploy-config.sh`; hook; `.gitleaks.toml` com a allowlist dos dois placeholders.
- `gestaofacil-fe` `961bd21`: hook de pré-commit.

Removido: `nfe-api/.env.bak-1789954252`.

Permissões: `.env` dos três projetos em `600`; containers continuam lendo (testado).

Correções desta rodada, que valem registrar:
- **Meu primeiro teste do hook estava errado.** O subcomando `git` do gitleaks 8.18.4 não existe; o erro saía com código 1 e eu li como "achado". Também testei com arquivos em `/tmp`, que o container não enxerga (o Docker só monta o projeto). Corrigi o hook para escanear o diff como texto, escrito dentro de `.git`, e refiz os testes: limpo passa (0), segredo bloqueia (1).
- **Guarda de debug:** a regra antiga só bloqueava `production`. Homologação (`staging`) passaria.

Suítes: `gestaofacil-api` 711 passando e 5 da baseline; `nfe-api` 406 passando e 4 da baseline.

Pendências:
- Decisão sua: trocar credenciais do `.env.bak` se a pasta foi copiada (ver Fase 0).
- Processo de publicação que chame `scripts/deploy-config.sh`; `APP_KEY` por ambiente; homologação e produção como ambientes de fato.
- Permissões de `storage/` em produção (dono e grupo).

### 19/10/2026: Fases 9 e 10 (implementação e verificação)

Commits e alterações nesta rodada (ver histórico dos repositórios):
- `gestaofacil-api`: trilha `auditoria_eventos` (somente acréscimo, trigger no Postgres), `Auditoria::registrar()` em login, usuários, configuração fiscal, NF-e, inutilização e acesso negado; `IdentificaRequisicao`; contexto de log; canal `daily` com 90 dias; `scripts/audit-gate.php` e `.audit-aceitas`; `composer.lock` versionado; `predis` alinhado (2.4.1); `symfony/http-foundation` e `league/commonmark` atualizados; regra `not_regex` em todo campo de e-mail; `scripts/check-security.php` corrigido (não compilava); `security.yml` reescrito (SHA, permissões, semgrep, testes de segurança reais); Dependabot.
- `nfe-api`: `not_regex` em e-mail do destinatário; canal `daily`; `scripts/audit-gate.php`; `security.yml` novo; Dependabot; `symfony/http-foundation` e `league/commonmark` atualizados.
- `gestaofacil-fe`: 5 `console.log` removidos; `ci.yml` (npm ci, npm audit, build, semgrep); Dependabot.

Efeito colateral corrigido: o `npm ci --dry-run` da análise anterior removeu o `node_modules` do host. Reinstalado com `npm ci` (mesmo lockfile).

Testes:
- `gestaofacil-api`: 720 passando e 5 da baseline (`NaturezaOperacaoTest`, `NfeEmissaoTest`).
- `nfe-api`: 407 passando e 4 da baseline.
- Runtime: `X-Request-Id` devolvido; evento de login falho gravado; log diário com `request_id`.

Pendências:
- **Decisão: migrar `laravel/framework` para a 12.** Único jeito de remover a advisory alta de CRLF. Hoje está aceita até 31/12/2026 com mitigação.
- Proteção de branch no GitHub (decisão e configuração suas).
- Workflows e Dependabot só são executados no GitHub, depois do push: validados por actionlint e pela execução local dos comandos.
- Cobertura do SAST nos arquivos de certificado (parser).
- Alerta sobre falha de autenticação e IDOR; 404 de acesso cruzado.
- Envio de log para fora do servidor; purga da trilha de auditoria (decisão fiscal).
- Trilha de auditoria do `nfe-api` (trava de somente acréscimo).

### 19/10/2026: cadastro de empresa pela plataforma (PLAN-ADMIN-SISTEMA.md)

Superfície nova: endpoint que cria empresa e usuário admin sem login. Controles:
- [x] Rota desligada por padrão (404) e só existe com `PLATAFORMA_CADASTRO_HABILITADO=true`.
- [x] Chave em `X-Plataforma-Key`, comparada por SHA-256 com `hash_equals`; sem hash configurado recusa tudo; 403 sem dizer se faltou ou errou.
- [x] `throttle:5,1` por IP (429), verificado por teste de API e por E2E.
- [x] Chave entre servidores (`X-Provisionamento-Key`, hash no `nfe-api`, fail-closed); token do `nfe-api` e token de convite nunca voltam na resposta nem vão para log (teste).
- [x] IE, IM, CRT, CNAE e endereço não são gravados no banco local nem no log (teste).
- [x] Senha do admin nunca passa por quem cadastra: convite de 24h, uso único (teste e E2E).
- [x] Auditoria `empresa.cadastrada`.
- [ ] Pendência: a chave é compartilhada e não identifica a pessoa; trocar por login de administrador quando houver a área administrativa.
- [ ] Pendência: manter `PLATAFORMA_CADASTRO_HABILITADO=false` em produção fora do uso.
Commits: `nfe-api` df3fbab, `gestaofacil-api` 47ba5a1, `gestaofacil-fe` fc57655.


### 19/10/2026: distribuição de DF-e (PLAN-DISTDFE, Fase 1 — nfe-api)

Superfície nova: rotas `/certificados/{cnpj}/dfe/*` que falam com a SEFAZ usando o certificado do cliente. Controles:
- [x] Posse: o certificado só é achado por `cnpj` + `client_id` do token; outro cliente recebe 404 (teste).
- [x] Cota da SEFAZ protegida no servidor (cooldown, intervalo mínimo, orçamento por chave, kill switch), não no botão (testes).
- [x] Gateway real desligado fora de produção (`NFE_DFE_REAL_HABILITADO=false`): dev não gasta a cota do CNPJ do cliente (teste).
- [x] `GET` nunca vai à SEFAZ; só `POST` gasta cota.
- [x] Resposta ilegível da SEFAZ não avança o NSU (nenhuma nota é pulada em silêncio).
- [ ] Pendência: sem agendamento de `dfe:verificar-continuidade` (alerta dos 60 dias) até a Fase 5.
Commit: `nfe-api` 0f098ed.

### 19/10/2026: distribuição de DF-e, Fase 2 (gestaofacil-api + FE)

- [x] Multiempresa: `DfeRecebido` tem `CompanyScope`; empresa B recebe 404 ao ignorar/restaurar DF-e da A e não vê a lista (testes).
- [x] Permissão no servidor: vendedor 403; operador não habilita; habilitar só `fiscal` (testes).
- [x] A gravação não confirma o NSU se o banco falhar (teste), então nota não se perde em silêncio.
- [x] XML de terceiros não vai para `nfe_requests`; fica em disco privado `dfe/{empresa}/{chave}.xml`.
- [x] XML lido com recusa de DOCTYPE/ENTITY e `LIBXML_NONET`.
- [ ] Pendência: `Storage::disk('local')` guarda o XML sem criptografia, igual às notas de entrada (política existente).
Commits: `gestaofacil-api` 2cf08dc, `gestaofacil-fe` 37d20e1.

### 19/10/2026: distribuição de DF-e, Fase 3 (manifestação)

Superfície nova: ato fiscal irreversível em nome da empresa (ciência, desconhecimento, não realizada).
- [x] Só `fiscal` (admin) manifesta; operador e vendedor recebem 403 e nada vai à SEFAZ (teste).
- [x] Empresa B não manifesta nota da A (404, teste); ciência em massa ignora ids de outra empresa (teste).
- [x] Duplo clique/duas abas: índice único parcial no banco + lock + regra de transição (testes).
- [x] Cada manifestação grava auditoria (quem, nota, protocolo) em `auditoria_eventos`.
- [x] Justificativa 15–255 validada na API e na tela; só segue na "não realizada" (teste).
- [x] Em massa: teto de 50 por pedido, para ao primeiro 429/503 (teste).
Commits: `nfe-api` 360c234; `gestaofacil-api` e `gestaofacil-fe` desta fase (ver `git log`).

### 19/10/2026: distribuição de DF-e, Fase 4 (importação)

- [x] O XML recebido é conferido contra a chave da linha antes de virar nota (teste).
- [x] Sem ciência, cancelada ou denegada: nada é consultado nem importado (testes).
- [x] A busca por chave não repete antes de 30 min (protege a cota do CNPJ) (teste).
- [x] Importar é idempotente e não cria nota duplicada (testes).
- [x] Multiempresa e permissão: vendedor 403, outra empresa 404 (teste).
- [ ] Pendência: Fase 5 (varredura diária). Sem ela, a regra dos 60 dias da SEFAZ pode perder notas.
Commits: `gestaofacil-api` 6d8f56d, `gestaofacil-fe` d7b939d.

### 19/10/2026: CNPJ alfanumérico (NT Conjunta 2025.001)

- [x] Validação de entrada com o padrão exato do XSD (maiúsculas, 12 `[0-9A-Z]` + 2 dígitos), nas rotas e nos requests: nada de CNPJ com máscara ou minúscula passa para o XML (testes).
- [x] O DV do CNPJ é conferido na `gestaofacil-api` e no front (ASCII − 48); a `nfe-api` segue só com o formato, como antes.
- [x] Pacote de schemas derivado é gerado em `storage/framework` (fora do git) e o vendor nunca é alterado (teste de integridade do arquivo).
- [x] Busca de fornecedor: palavra curta com dígito não vira busca de CNPJ (teste).
- [ ] Pendência: nenhuma chamada real à SEFAZ com CNPJ alfanumérico ainda.
Commits: `nfe-api` 1d033e8, `gestaofacil-api` 110e647, `gestaofacil-fe` dbb5ed9.

### 19/10/2026: distribuição de DF-e — fechamento do dia (controles novos)

- [x] **Só em produção:** com a empresa em homologação, ativar/buscar/consultar/manifestar são recusados no servidor (`409 so_producao`), mesmo com `NFE_DFE_REAL_HABILITADO=true`; evita ciência na SEFAZ errada (testes).
- [x] **Primeiro teste real em produção foi só leitura:** nenhuma manifestação foi enviada; 43 notas reais de terceiros ficaram no banco de dev (dado pessoal/comercial) — o banco será zerado na entrada em operação.
- [x] A reconciliação com as notas de entrada filtra por `empresa_id` nos dois lados (teste de isolamento).
- [x] SQL cru continua proibido: contagem por mês e reconciliação reescritas sem `selectRaw` (o `EntradaESeguraTest` pegou).
- [x] CNPJ/chave com letra validados no formato exato do XSD (maiúsculas); DV conferido na `gestaofacil-api`.
- [ ] Pendência: o intervalo livre e "todo o período" devolvem notas paginadas, mas sem limite de datas; não há teto de histórico além da paginação (aceito: dados da própria empresa).

### 20/10/2026: distribuição de DF-e, Fase 5 (varredura automática)

- [x] Roda só 02:00–06:00 (Brasília), `withoutOverlapping`, pausa entre empresas; nunca para empresa em homologação, com busca desativada, `sefaz_liberada=false` ou `outro_sistema`≠não (testes + mutação).
- [x] Sem usuário logado: usa `sincronizarEmpresa`; o estado vem por GET e o único caminho à SEFAZ segue sendo o `CooldownDaDistribuicao` da nfe-api.
- [x] Kill switch/rejeição da SEFAZ vão ao log como erro; falha de uma empresa não derruba as outras; aviso de CNPJ >45 dias sem varredura.

### 20/10/2026: DF-e, varredura das 04:00 com chave por empresa e lote de XML

- [x] Varredura automática: 1×/dia às 04:00 (Brasília); `busca_automatica` por empresa (padrão ligada) em vez de variável de ambiente; vale com outro sistema na cota porque a coordenação já é exigida ao ativar. Piso de intervalo segue só no `CooldownDaDistribuicao` (20 h com outro sistema).
- [x] `POST /dfe/configurar`: só `fiscal`, auditoria `dfe.configurado`, não chega à SEFAZ (teste: nenhuma chamada ao gateway); mudar para "há outro sistema" sem coordenação é recusado (mutação confere).
- [x] Importação em lote: validação 8 MB alinhada ao nginx; ZIP sem extração em disco, leitura limitada, 100 XMLs / 500 entradas / 60 MB descomprimidos.

### 20/10/2026: fuso horário da aplicação = Brasília (gestaofacil-api)

- [x] `APP_TIMEZONE` padrão `America/Sao_Paulo` e sessão do Postgres no mesmo fuso (igual ao nfe-api, que já era assim). Corrige "hoje" depois das 21h em Recife na lista de notas (teste novo; reverter o padrão para UTC o faz falhar).
- Risco aceito: dado antigo gravado em UTC é lido 3 h adiantado; dev será zerado e a produção ainda não tem dados.
