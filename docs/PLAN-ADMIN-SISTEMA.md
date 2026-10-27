# PLAN-ADMIN-SISTEMA — Cadastro de empresa pelo dono da plataforma

Status: **implementado e validado em 2026-10-19** (ver seção 8). Revisado contra o código em 2026-10-19.

## 1. Objetivo

Fechou a venda: o dono da plataforma cadastra a empresa e ela já entra no sistema com os dados
básicos e fiscais preenchidos (razão social, IE, IM, regime, endereço), só faltando o
certificado. É o **fluxo principal de entrada de cliente**, não um quebra-galho.

**Como:** uma tela simples, fora do layout da empresa, que chama um endpoint de plataforma. A
área de administração futura reaproveita o mesmo serviço.

**Fora deste plano:** certificado, CSC, numeração e naturezas (a empresa configura depois, na
Configuração Fiscal); produtos, clientes, vendas, notas; editar ou inativar empresa; listagem
de empresas; campo de notas/orientações para a empresa (decidido deixar de fora).

## 2. Decisões

| # | Decisão | Motivo |
|---|---|---|
| D1 | O cadastro grava nos dois sistemas. **API de Vendas:** `empresas` (com plano; dados fiscais e endereço não, ver D2), `configuracoes_fiscais` com o token, `users`. **`nfe-api`:** cliente, token e emitente (IE, IM, CRT, CNAE, endereço), **sem certificado**. | IE, IM e regime só podem morar no `nfe-api` (`SECURITY.md`). |
| D2 | Endereço, IE, IM, CRT e CNAE ficam **só no `nfe-api`**. A API de Vendas guarda razão social, nome fantasia, CNPJ e plano, como hoje. | Evita criar colunas e espelho que depois divergem. A Configuração Fiscal já lê o emitente de lá. |
| D3 | Plano é **obrigatório** e escolhido entre os 3 planos padrão, criados por seeder. | Pedido explícito. |
| D4 | CNPJ travado desde a criação. Empresa nasce **ativa**. | O `nfe-api` indexa por CNPJ. Login não depende do certificado. |
| D5 | Admin inicial recebe convite por e-mail para definir a senha; ela nunca passa por quem cadastra. Link expirado (24h): "esqueci minha senha". | Mesmo mecanismo do `UserController::store`. |
| D6 | Ordem: valida tudo, chama o `nfe-api`, depois grava local numa transação. Se o local falhar depois do `nfe-api`, desfaz o que foi criado lá (ver 4.2). | Dois sistemas não têm transação comum; assim nunca sobra cliente órfão. |
| D7 | Acesso à tela: **chave de plataforma** digitada na própria tela, enviada em header. Não identifica a pessoa; trocar por login quando houver área de administração. Três camadas simples: rota desligada por padrão, chave comparada por hash em tempo constante e limite de tentativas por IP (ver 4.3). | Simples, sem criar tipo novo de usuário, mas um usuário indevido não cria empresa. |
| D8 | Entre os dois serviços: chave de provisionamento própria, em header `X-Provisionamento-Key`, só entre servidores. O `nfe-api` guarda o SHA-256 (`PROVISIONAMENTO_CHAVE_HASH`) e a API de Vendas a chave em texto (`NFE_API_PROVISIONAMENTO_CHAVE`). Sem hash configurado, o `nfe-api` recusa tudo. | O `nfe-api` hoje só autentica por token de cliente, que ainda não existe aqui. |

## 3. O que já existe e será reaproveitado

- **E-mail único no sistema**: `unique` global em `users.email` e o `UserController::store` já valida assim.
- **CNPJ**: regra `ValidCpfCnpj('juridica')`; normalizar para dígitos antes do `unique`.
- **Regras do emitente**: `UpdateEmitenteRequest` do `nfe-api` (IE `\d{2,14}` ou `ISENTO`, CRT 1–4, endereço completo com IBGE de 7 dígitos). O serviço de provisionamento reusa essa classe.
- **Convite**: `User::generatePasswordResetToken` (24h) e `PasswordResetController`.
- **Token do `nfe-api`**: `NfeApiClient::forEmpresa` já lê `configuracoes_fiscais.nfe_api_token_id` criptografado com `Crypt`.
- **Auditoria**: `Auditoria::registrar` (sem usuário grava empresa e usuário nulos).
- **Planos**: `GET /api/v1/planos` público, só `ativo`.
- **Front**: `EnderecoFields.tsx` e `services/cep.ts` (CEP e código IBGE).

## 4. O que fazer

### 4.1 `nfe-api`: emitente sem certificado

Hoje o emitente é coluna de `client_certificates`, que exige `password_encrypted` e `expires_at`
(`NOT NULL`), e o `PUT .../emitente` responde 404 sem ela.

- Migration: `password_encrypted` e `expires_at` passam a aceitar nulo. Registro sem certificado
  = "emitente cadastrado, certificado pendente".
- Endpoint `POST /provisionamento/empresas` (chave de provisionamento, D8): cria `SystemClient`
  (`ApiClientService::create`), token (`createToken`) e `ClientCertificate` sem certificado com o
  emitente. Devolve o token **uma única vez**. CNPJ já vinculado a outro cliente: 409.
- Endpoint `DELETE /provisionamento/empresas/{cnpj}`: só funciona enquanto não há certificado
  nem nota. Serve à compensação do D6.
- O envio do certificado depois já preenche o mesmo registro (`updateOrCreate`) e mantém o emitente.
- Tratar "sem certificado" em todo ponto que lê o registro. Mapeado no código:
  `NfeIngestController` (já recusa com 403 por `activeCertificateForCnpj`; a mensagem passa a
  dizer "certificado pendente"), `SystemClient::activeCertificateForCnpj` (NULL não passa em
  `expires_at > now()`), `CheckCertificateExpiration` e o widget do dashboard (NULL não casa,
  sem mudança), `ClientCertificate::isExpired`/`daysUntilExpiration` e as telas Filament que as
  chamam (viram null-safe), `CertificateService::decryptedPassword` (recusa com erro claro),
  `CertificateController::resource` (devolve `certificado_pendente`) e o estado da Configuração
  Fiscal (ausente, nunca "válido").
- Provisionar também cria as naturezas padrão (`aoAlterarEmitente`), como o `PUT .../emitente`.

### 4.2 API de Vendas: serviço `CadastroDeEmpresa`

1. Valida: CNPJ (válido, não existe local), plano (obrigatório, existe, ativo), admin (nome,
   e-mail único no sistema) e emitente (mesmas regras do `UpdateEmitenteRequest`).
2. Chama `POST /provisionamento/empresas`. Erro aqui: nada foi criado local, devolve a mensagem.
3. Transação local: `empresas` (ativa, com plano), `configuracoes_fiscais` com o token
   criptografado e `users` admin (`perfil = admin`, `ativo = true`, senha aleatória inutilizável).
4. Se a transação falhar, chama `DELETE /provisionamento/empresas/{cnpj}` e devolve erro.
5. Depois do commit: gera o token de convite, envia o e-mail e registra
   `Auditoria::registrar('empresa.cadastrada', 'empresa', $id)`. Falha no e-mail **não desfaz** o
   cadastro: responde `convite_enviado: false`.

Se o `nfe-api` criou o cliente mas a resposta se perdeu (timeout), repetir o cadastro dá 409
no CNPJ; nesse caso a mensagem manda chamar o suporte (limpeza manual no `nfe-api`). Aceito para
a v1.

Nunca grava IE, IM, CRT, CNAE ou endereço no banco local, nem no log (só os nomes dos campos),
como o `updateEmitente` já faz.

### 4.3 Endpoint de plataforma

`POST /api/v1/plataforma/empresas`, fora do grupo `auth:sanctum`. Resposta 201: id, razão
social, CNPJ, plano, `convite_enviado`. Nunca devolve senha, token do `nfe-api` ou token de convite.
Proteção (D7), três camadas, todas simples:

1. **Flag:** a rota responde 404 sem `PLATAFORMA_CADASTRO_HABILITADO=true`. Em produção, manter
   desligada fora do uso.
2. **Chave:** guardada como SHA-256 em `PLATAFORMA_CHAVE_HASH` (a chave é aleatória e longa,
   então o hash simples basta; argon2id fica para quando houver login de admin). Enviada em
   `X-Plataforma-Key`, nunca em query string ou corpo, e comparada com `hash_equals`. Chave
   ausente ou errada: 403, sem dizer qual dos dois.
3. **Limite:** `throttle:5,1` por IP (429 depois de 5 tentativas por minuto).

**Config:** as três variáveis novas entram em `config/services.php` (`plataforma.*`,
`nfe_api.provisionamento_chave`), nunca lidas por `env()` fora do config. Como o runtime lê
`bootstrap/cache/config.php`, depois de mudar o `.env` é preciso regenerar o cache
(`config:cache`), em dev e no deploy.

### 4.4 Planos

Seeder idempotente (`updateOrCreate` por `nome`) com 3 planos provisórios: `Plano 1`, `Plano 2` e
`Plano 3`, todos com `preco_mensal = 0`, `limite_vendas_por_mes = 0` e `ativo = true`. Hoje não
existe seeder nem migration que crie planos. Nenhum código lê os limites (só a listagem pública
os devolve), então o valor 0 não bloqueia nada. Quando os planos reais forem definidos, basta
trocar os valores no seeder e rodá-lo de novo. O diretório `database/seeders` não existe: criar
`PlanoSeeder` nele. Em produção roda com `php artisan db:seed --class=PlanoSeeder --force`
(passo do deploy, antes do primeiro cadastro). `limite_usuarios` fica nulo.

### 4.5 E-mail de convite

`ConviteEmpresaMail` com view de boas-vindas, apontando para `/password-reset?token=…` (usar
`markdown:` como o `PasswordResetMail`, pelo namespace `mail::`). Hoje o convite sai com texto
de "Recuperação de Senha".

### 4.6 Tela

Rota `/plataforma/empresas/nova`, fora do `Layout` e do `ProtectedRoute`, sem entrada no menu.
Campo da chave no topo (só em memória, nunca em `localStorage`). Seções: **Empresa** (CNPJ,
razão social, nome fantasia, plano em lista), **Dados fiscais** (IE com opção "Isento", IM,
CNAE, regime tributário), **Endereço** (reusa `EnderecoFields` e `services/cep.ts`, com
telefone), **Administrador** (nome, e-mail). Erros por campo vindos do 422. Em sucesso mostra o
resumo, o aviso de convite (enviado ou não) e botão "Cadastrar outra". Não mostra senha nem token.

## 5. Testes

Pest, nos containers (`make test-api`; `nfe-api` com o equivalente). Chamadas ao `nfe-api`
com `Http::fake`.

**`nfe-api`**
- Provisionar cria cliente, token (devolvido uma vez) e registro com emitente e sem certificado.
- Sem chave de provisionamento ou chave errada: 403. CNPJ de outro cliente: 409.
- `DELETE` remove tudo se não há certificado; recusa se já há certificado ou nota.
- Emitente inválido (IE, CRT, IBGE, CEP): 422.
- Registro sem certificado: emissão recusa com mensagem clara, `CheckCertificateExpiration` não quebra, `resource`/`show` mostram certificado ausente.
- Enviar o certificado depois preenche o mesmo registro e mantém o emitente.

**API de Vendas**
- Sucesso: empresa ativa com plano, `configuracoes_fiscais` com token que o `NfeApiClient::forEmpresa` consegue ler, admin com `perfil = admin`, evento de auditoria.
- Banco local sem IE, IM, CRT, CNAE ou endereço; log sem esses valores, sem senha, sem token.
- 422: CNPJ inválido ou duplicado, plano ausente, inexistente ou inativo, e-mail já usado (inclusive em outra empresa), IE/CRT/IBGE/CEP inválidos.
- Falha do `nfe-api`: nada criado local. Falha da transação local: chamada de `DELETE` feita, nada local.
- Falha no envio do e-mail: empresa criada, `convite_enviado: false`.
- Convite: link define a senha e permite login; link reutilizado é recusado.
- Chave ausente ou errada: 403; excesso de tentativas: 429; flag desligada: 404.
- Empresa recém-criada: `GET /configuracoes/fiscal` responde 200 com integração configurada e certificado ausente; `GET /empresas/me` responde 200 com o plano; não aparece para usuário de outra empresa.
- Seeder: cria `Plano 1`, `Plano 2` e `Plano 3` (preço 0, limite 0, ativos) e rodar duas vezes não duplica.

**Front**
- Validação dos campos da tela (IE ou "Isento", IBGE, CEP, e-mail); plano obrigatório; erro 422 aparece no campo; sucesso mostra o aviso de convite; chave não vai para `localStorage`.

**E2E** (`gestaofacil-e2e`, Playwright): cadastrar empresa pela tela, abrir o e-mail de convite, definir a senha, entrar e ver, na Configuração Fiscal, o emitente já preenchido e o certificado pendente.

Validação manual: cadastrar uma empresa real de teste e conferir o e-mail de convite.

## 6. Ordem e fechamento

1. `nfe-api`: migration, endpoints de provisionamento e tratamento de "sem certificado", com testes.
2. Seeder de planos. 3. Mailable de convite.
4. API de Vendas: serviço, endpoint e proteção, com testes.
5. Tela e E2E. 6. Revisão e teste manual.

Portão de etapa: revisar, testar, commitar e atualizar `PROGRESS.md` antes da próxima. O item 1
mexe na emissão, então roda a suíte inteira do `nfe-api`, não só os testes novos.

## 7. Pontos em aberto

Sem pontos em aberto de escopo. Definidos: planos provisórios (4.4) e chave digitada na tela a
cada cadastro (D7).

**Observação, fora do plano:** `ConfiguracaoFiscalController::update` grava as preferências
   de tributação antes de checar a integração. Com este plano toda empresa nova passa a ter
   integração, então o problema deixa de aparecer no cadastro. Só mexo se você mandar.

## 8. Como usar e o que foi entregue

**Qual é a senha da tela?** A "chave de plataforma" é você quem escolhe: gere um texto aleatório
(`openssl rand -base64 32`), guarde num gerenciador de senhas e configure só o hash dele. A tela pede
o texto, nunca o hash, a cada cadastro. Ela não está em nenhum arquivo do projeto; se esquecer, gere
outra e troque o hash. Descrito também no `README.md` do front.

**Ligar o cadastro (dev ou produção)**, na API de Vendas e no `nfe-api`:

```
# gerar as duas chaves (guarde o texto; só o hash vai para o servidor)
php -r "echo hash('sha256', 'CHAVE-DE-PLATAFORMA');"      # -> PLATAFORMA_CHAVE_HASH
php -r "echo hash('sha256', 'CHAVE-ENTRE-SERVIDORES');"   # -> PROVISIONAMENTO_CHAVE_HASH (nfe-api)

gestaofacil-api: PLATAFORMA_CADASTRO_HABILITADO=true, PLATAFORMA_CHAVE_HASH=<hash 1>,
                 NFE_API_PROVISIONAMENTO_CHAVE=CHAVE-ENTRE-SERVIDORES
nfe-api:         PROVISIONAMENTO_CHAVE_HASH=<hash 2>
```

Depois: `config:cache` nos dois (`make cache-clear` no dev) e abrir `/plataforma/empresas/nova`. No dev as
variáveis passam pelo `.env` do `gestaofacil-dev-environment` (o compose já repassa, desligado por
padrão). **Desligar de novo** (`PLATAFORMA_CADASTRO_HABILITADO=false`) quando terminar os cadastros.

**Passos de deploy** (antes do primeiro cadastro): `php artisan migrate --force` no `nfe-api` (certificado
opcional) e `php artisan db:seed --class=PlanoSeeder --force` na API de Vendas.

**Atenção, fora do plano:** o link do convite usa `config('app.url')` (mesmo comportamento do convite de
usuário). Em produção `APP_URL` da API de Vendas precisa apontar para o endereço do front, que é quem
tem a rota `/password-reset`. No dev, `APP_URL` é o host da API, então o link do e-mail não abre a tela.

**Entregue:** `nfe-api` (commit `df3fbab`): migration, `POST/DELETE /provisionamento/empresas`, certificado
pendente tratado. `gestaofacil-api` (`47ba5a1`): serviço `CadastroDeEmpresa`, rota com 3 camadas,
`ConviteEmpresaMail`, `PlanoSeeder`. `gestaofacil-fe` (`fc57655`): tela. E2E: `gestaofacil-e2e/tests/e2e/plataforma-empresa.spec.ts`.

**Testes:** `nfe-api` 425 passam, as mesmas 4 da baseline falham (13 novos testes passam). `gestaofacil-api`
757 passam, as mesmas 5 da baseline falham (25 novos passam). E2E: 8 casos × chromium e firefox,
16/16; a jornada completa repetida 15 vezes sem falha. Suíte E2E inteira: 175 passam, 13 pulados, 2 falham
(a jornada, por um bug do próprio helper de leitura do e-mail, já corrigido e revalidado; e
`senha.spec.ts` D-MAIL, que lê `storage/logs/laravel.log` mas o log agora é diário: anterior a este trabalho).

**Fora do escopo, por decisão:** campo de notas/orientações para a empresa.
