# PROGRESS.md — GestãoFácil v1 Implementation Roadmap

## PLAN-GRADE — Fase 0: linha de base (28/10/2026)

Branch `feat/grade-variacoes` nos quatro repositórios (`gestaofacil-api`, `-fe`, `-e2e`, `-dev-environment`).

- **Baseline de falhas do gestaofacil-api (antes de qualquer mudança):** 926 passam, 5 falham, 1 pulado
  (`NaturezaOperacaoTest` token não configurado; `NfeEmissaoTest` double emit e modelo 55/65 ×3). Qualquer falha além
  dessas 5 é regressão da grade.
- **Desempenho (§11 do plano), medido no container, 5.000 produtos por empresa × 2 empresas** (`tests/Performance`,
  fora da suíte padrão; `linha-de-base.json` guarda os números): busca por nome p95 36 ms · por EAN p95 21 ms · por SKU
  p95 43 ms (2 queries cada) · checkout do PDV com 10 itens p95 100 ms, 54 queries · emissão de NF-e com 50 itens
  89 ms, 27 queries (não cresce com o nº de itens). A busca usa o índice `(empresa_id, ativo)` e filtra em memória.
- **Ficou de fora:** XML real de compra de confecção (não há; a Fase 6 usa fixture sintética rotulada) e o teto
  absoluto definitivo (os tetos de 100 ms/300 ms do plano passaram com folga).

## Cadastro de empresa pela plataforma (19/10/2026)

- **Fechou:** `PLAN-ADMIN-SISTEMA.md` inteiro. Tela `/plataforma/empresas/nova` (sem login, protegida por chave digitada), `POST /api/v1/plataforma/empresas` com 3 camadas (flag, limite por IP, chave), provisionamento no `nfe-api` (emitente sem certificado, com desfazer), convite por e-mail, `PlanoSeeder`. Commits: nfe-api `df3fbab`, gestaofacil-api `47ba5a1`, gestaofacil-fe `fc57655`.
- **Testes:** 13 (nfe-api) + 25 (gestaofacil-api) novos; E2E 16/16 (chromium e firefox). Baselines inalteradas (4 e 5 falhas antigas).
- **Ficou de fora:** campo de notas para a empresa (decisão); login de admin da plataforma (a chave é compartilhada); `senha.spec.ts` D-MAIL falha por ler `laravel.log` (log agora é diário), anterior a este trabalho.
- **Dev:** migration do `nfe-api` e `PlanoSeeder` aplicados; cadastro desligado (ver seção 8 do plano para ligar).

## Frente de loja: sucesso em modal, NFC-e acompanhada e fila própria (19/10/2026)

Origem: o envio assíncrono deixava o caixa sem saber se a nota saiu. Plano: `PLAN-UI.md` seção 6a.1.

- **gestaofacil-fe:** modal "Venda concluída" (`VendaConcluidaModal`) substitui a faixa de sucesso; hook
  `useAcompanhamentoNfce` consulta a cada 1,5 s; aviso de SEFAZ demorando após 10 s; desiste em 2 min.
- **gestaofacil-api:** `GET /pdv/vendas/{id}/nfce` na área `pdv` (o vendedor não tem `notas`, então `/nfe-emissoes`
  não serve). 7 testes novos.
- **nfe-api:** NFC-e vai para a fila `nfce` (`ProcessNfeJob::FILA_NFCE`), com `supervisor-nfce` no Horizon e alerta
  de espera em 15 s. 3 testes novos. Depois de mexer em `config/horizon.php`: `make cache-clear-nfe` e
  `horizon:terminate` (feito no dev; **produção precisa do mesmo no deploy**).
- **E2E:** PDV 32/32 (Chromium e Firefox); fiscal `nfce-pdv` + `regime-naturezas` 10/10 (2 testes novos de
  SEFAZ demorando e rejeitada).
- **Suítes completas:** nfe-api 410 passam, as mesmas 4 falhas de sempre; gestaofacil-api 727 passam, 5 falhas
  (NaturezaOperacao e NfeEmissao, todas já listadas como pré-existentes).
- **Impressão (19/10/2026, PLAN-UI 6a.2):** com NFC-e autorizada o caixa imprime o **cupom fiscal (DANFCE)**; o
  comprovante sem valor fiscal ficou só para venda sem nota ou nota que não saiu. Endpoint `GET /pdv/vendas/{id}/danfe`.
  Imprimir **sem a janela de confirmação não é possível pela página**: configurar o navegador do caixa (Firefox
  `print.always_print_silent`; Chrome `--kiosk-printing`). Não testado em impressora real. **Achado:** não havia teste
  do DANFCE; adicionado `DanfceTest`. Nunca gerado a partir de nota autorizada na SEFAZ real: conferir na primeira
  emissão em homologação. Testes: gestaofacil-api 730 (mesmas 5 falhas), nfe-api 412 (mesmas 4), E2E PDV 32/32, fiscal 11/11.
- **Lista de pedidos (19/10/2026, PLAN-UI 6a.3):** coluna *Nota fiscal* (situação + número, ou "Sem nota"); `GET /vendas`
  manda `nfe_emissao`. 2 testes Pest, 1 E2E normal e 1 trecho no E2E fiscal.
- **Não feito (decisão fiscal):** fluxo quando a SEFAZ passa de muito tempo / contingência offline da NFC-e.
- **Conferência visual pendente com o Firefox** (só o usuário confere a tela).

## Prontidão para produção — C1, C2 e C4 corrigidos (18/10/2026)

Origem: `gestaofacil-e2e/docs/REVISAO-EMISSAO-NF.md` (três bloqueadores restantes). Cada item lá agora traz o status.

- **C1 (timeout gerava nota duplicada):** `nfe-api` aceita `id_externo` e devolve a nota existente na repetição;
  `gestaofacil-api` deixa a emissão `pendente` sem protocolo quando a resposta se perde (antes: `rejeitada`) e a
  reenvia com a mesma chave. Não cobre o reenvio de rejeitada (`reenviar`).
- **C2 (pendente esquecida):** comando `nfe:reconciliar-pendentes` a cada 5 min; serviço `gestaofacil_scheduler` no
  compose de dev. **Produção precisa de agendador** (`schedule:run` no cron) — deploy ainda não definido.
- **C4 (XML sem protocolo):** aviso `sem_protocolo` na importação.
- **Textos errados corrigidos:** "RealSefazGateway nunca rodou contra a SEFAZ real" (`nfe-api/CLAUDE.md`, comentário
  da classe, `PLAN.md`). O gateway real tem 10 notas em homologação de PE; falta produção e outras UFs.
- **Testes:** nfe-api 4 novos (as 4 falhas de sempre continuam); gestaofacil-api 15 novos (as 7 falhas de sempre
  continuam: ClienteTest x2, NaturezaOperacaoTest, NfeEmissaoTest x4).
- **Falta para a primeira nota real:** emissão-piloto em produção (cancelar e CC-e), com o contador.

## Reforma tributária (IBS/CBS) — layout PL_010 (14–15/10/2026)

Plano: [`PLAN-REFORMA-PL010.md`](./PLAN-REFORMA-PL010.md). Branch `feat/reforma-pl010` em nfe-api,
gestaofacil-api e gestaofacil-fe.

- **F0 (baseline nfe-api):** 4 falhas pré-existentes (CertificateExpiration, CircuitBreakerRecovery,
  NaturezaOperacaoCrud, NfePolling), 357 passam, 23 puladas.
- **PoC:** XML PL_010 com grupo IBS/CBS por item valida no XSD `PL_010_V1.30` (sped-nfe 5.2.8, já a
  mais nova). Não enviado à SEFAZ.
- **F1 (nfe-api, commit `a1e4f99`):** `assinarEValidar` aceita a pasta de schemas; testes NF-e e NFC-e em
  PL_010 e padrão PL_009 inalterado. Suíte: 360 passam, mesmas 4 falhas da baseline.
- **F2 (nfe-api, `eb84bfb`):** bloco `ibs_cbs` opcional por item, só formato. 7 testes novos.
- **F3 (nfe-api, `cc2a587`):** builder monta `IBSCBS` por item em PL_010; PL_009 com bloco é recusado. IBSCBSTot
  da lib soma certo (teste de 2 itens). 5 testes novos. Suíte: 372 passam, mesmas 4 falhas.
- **F4 (nfe-api, `1299a50`):** `docs/API_ENDPOINTS.md` e `CLAUDE.md` atualizados.
- **F5 (gestaofacil-api, `5823931`):** nota avulsa repassa o bloco quando preenchido; sem coluna nova. 4 testes
  novos. Suíte: 623 passam, mesmas 7 falhas da baseline.
- **F6 (gestaofacil-fe, `ce0f2ed`):** bloco recolhido por item com ⓘ por campo. `type-check` e build ok; regras
  puras conferidas com esbuild (11 casos). Conferência visual pendente.
- **Achado:** sped-nfe calcula `vItem`/`vNFTot` com IBS/CBS só quando `date('Y') > 2026`. Hoje não soma. Decisão D8.
- **Decisões pendentes:** D1–D3, D5–D9 em `PLAN-REFORMA-PL010.md` (seção 5).
- **Publicação:** branch `feat/reforma-pl010` enviada aos três `origin`. PRs em draft ainda não abertos (sem `gh`/token).
  Nos dois gestaofacil, a base `feat/importacao-xml` também subiu sem estar publicada antes (D10). Próximos passos e
  dúvidas em `PLAN-REFORMA-PL010.md` (seções 8 e 9).

## E2E fiscal — Fases 7 e 8 (14–15/10/2026)

- **Feito:** stack de NF-e com gateway fake por overlay (`nfe_e2e_db`, delta de env no `nfe_api` e
  `nfe_worker`); configuração fiscal pelo fluxo real; webhook testado sem consulta manual. 19 testes
  fiscais passam em 2 execuções do zero; a suíte normal (89) continua verde. Plano: `gestaofacil-e2e/PLAN-E2E.md`.
- **Integração corrigida:** URL do nfe-api sem `/v1` (toda chamada 404); cabeçalho do webhook;
  CST de PIS/COFINS da natureza; inutilização (caminho e campo). Todos com teste.
- **Defeitos conhecidos, com teste marcado `test.fail`:** D-CANC (cancelamento vira `cancelada`
  antes da SEFAZ), D-CCE (CC-e marca `carta_correcao_emitida` antes da SEFAZ) e D-INUT (inutilização
  aparece como concluída antes da SEFAZ). **Decisão pendente:** exige estado intermediário; o
  padrão é o mesmo nos três.
- **Regime e naturezas (15/10/2026, feito):** ordem de cadastro certificado → emitente → naturezas →
  numeração; troca de grupo tributário zera a tributação e pede revisão; só a natureza pendente
  bloqueia a emissão. Testes: nfe-api 12 novos, gestaofácil 3, E2E 6. Ver `PLAN-E2E.md`.
- **Itens 1 a 3 (16/10/2026, feito):** cancelamento, CC-e e inutilização passam a ter estado de
  andamento (`cancelando`, `enviada`) e só mudam com a resposta da SEFAZ; D-CANC, D-CCE e D-INUT
  deixam de ser defeitos conhecidos. Numeração não volta mais (409). Tabela `failed_jobs` criada.
- **Itens 4 a 10 (16/10/2026, feito):**
  - **SEFAZ fora do ar:** a nota fica na fila sem limite de tentativas (antes ia para `failed_jobs` e
    ficava presa). A lista e o detalhe mostram o aviso enquanto a SEFAZ não responde; o aviso não é gravado.
  - **Inutilização de NFC-e:** a inutilização grava o modelo (55 ou 65) e a tela permite escolher.
  - **Emitente:** a tela não grava mais a carga repetida do StrictMode e só libera salvar depois da carga.
  - **Configuração fiscal:** removida `ConfiguracaoFiscal.tsx`, órfã desde a separação das telas.
  - **E2E:** NF-e 55 e rascunho pela tela; SEFAZ fora do ar; naturezas sem emitente; fornecedor por empresa;
    guarda de gateway verificada ao vivo. Fiscal 36 passam, normal 91 passam (5 pulados). Plano em `PLAN-E2E.md`.
  - **Pendências de decisão:** login por alias (CT-073b, decidido e não implementado) e reativação de
    fornecedor inativo (CT-091).
- **Abertos no nfe-api:** nenhum da lista de 15/10 (numeração recusada em 16/10; tabela `failed_jobs` criada).

## Defeitos abertos — auditoria da suíte E2E (05/10/2026)

> **RESUMO DA LEVA (05–09/10/2026).** Dos 21 defeitos da auditoria: **18 corrigidos**, **1 fechado
> por decisão** (D-08 — login por alias cobre o multiempresa), **0 abertos**. Planos relacionados:
> impostos por item e emissão em [`PLAN-IMPOSTOS.md`](./PLAN-IMPOSTOS.md) (6 fases ✅).
>
> **Pendências que atravessam a sessão e NÃO são defeitos do registro:**
> 1. ~~`gestaofacil-api/bootstrap/app.php` (WIP): renderer que virava 422/404/401 em 500~~ —
>    **removido em 14/10/2026**; nunca tinha sido commitado. As **7 falhas de baseline** da
>    gestaofácil-api são de HEAD (`ClienteTest` cpf/cnpj, `NaturezaOperacaoTest`, `NfeEmissaoTest`)
>    e não têm relação com esse renderer.
> 2. Conferência visual (360/390/768/1280 px, Firefox) das telas tocadas na leva — manual.
> 3. DIFAL na **nota avulsa** (`FormularioNotaAvulsa`): o caminho de venda está completo; a avulsa
>    ficou como follow-up do D-09.

## Defeitos abertos — auditoria da suíte E2E (05/10/2026)

Levantados ao revisar os casos de teste E2E **contra o código** dos três repositórios
(`gestaofacil-fe`, `gestaofacil-api`, `nfe-api`). Nenhum item aqui é hipótese: cada um tem
arquivo, linha e o caso de teste que o cobre.

**Análise completa:** [`gestaofacil-e2e/docs/CASOS-DE-TESTE-E2E.md`](../../gestaofacil-e2e/docs/CASOS-DE-TESTE-E2E.md)
(Parte 1 = gaps com evidência, Parte 2 = 117 casos, Parte 3 = auditoria de cobertura).
O número entre parênteses no fim de cada item é a seção daquele documento.

### 🔴 Crítico

- [x] **D-01 — Venda em dinheiro com troco não emite NFC-e.** ✅ **corrigido em 06/10/2026.**
  A frente de loja mandava o valor **entregue** como `valor` do pagamento; a venda ficava com
  pagamentos somando mais que o próprio total e a emissão repassava essa soma sem informar o
  troco. A SEFAZ exige `soma(vPag) − vTroco == vNF`, o Serviço de NF-e devolvia 422 e o
  `checkout` engolia o erro — a venda fechava, o estoque baixava e a nota não saía.

  **Causa de fundo:** havia **uma** coluna para dois papéis. O registro da venda quer a parte que
  cobre a compra (R$ 20); o documento fiscal quer o valor entregue (R$ 25) mais o troco (R$ 5).

  **Correção (na raiz, como decidido):** `venda_pagamentos.valor_recebido` (migração
  `2026_10_06_000001`), o frontend manda os dois valores, o checkout tira o troco da diferença
  entre eles e a emissão manda `valor_recebido ?? valor` com o `troco` calculado. Venda gravada
  antes da migração continua emitindo certo — a mesma conta cobre os dois formatos.
  **Testes:** `tests/Feature/Pdv/TrocoNaVendaENaNfceTest.php`.
  **E2E:** `CT-E2E-010`, `CT-E2E-046`, `CT-E2E-053`.

### 🟠 Alta

- [x] **D-21 — A emissão inventava dado fiscal quando o cadastro estava incompleto.** ✅
  **corrigido em 06/10/2026.** Oito chutes varridos (UF do emitente e do cliente, CFOP, CST de
  ICMS, CST de PIS/COFINS, forma de pagamento, unidade, CEP), mais dois iguais no frontend. Cada
  um virou recusa com mensagem dizendo o que falta e onde configurar
  (`ConfiguracaoFiscalIncompletaException`). Apareceu junto que o `ErrorTranslationService`
  engolia a mensagem detalhada e que as fixtures de teste escondiam natureza incompleta.
  **Fases 1 a 6 do** [`PLAN-IMPOSTOS.md`](./PLAN-IMPOSTOS.md).

- [x] **D-02 — Simples Nacional com CSOSN 101 não emitia nenhuma nota.** ✅ **corrigido em
  06/10/2026.** O `pCredSN` passou a morar no produto (varia por produto) e a emissão o manda
  quando o CSOSN é 101; sem ele cadastrado, recusa nomeando o produto.
  **E2E:** `CT-E2E-062`.

- [x] **D-03 — Não havia onde configurar a alíquota de ICMS.** ✅ **corrigido em 06/10/2026.**
  `produtos` ganhou `icms_aliquota` (e as de PIS/COFINS/IPI); `empresas` guarda os valores usuais
  **só como auxílio de cadastro**, e a emissão nunca os lê — há teste garantindo. CST 00 sem
  alíquota recusa em vez de autorizar com ICMS zero. **E2E:** `CT-E2E-061`.

  A primeira versão deste item dizia só "sai sempre com alíquota 0", o que descrevia apenas o
  segundo caminho. **Raiz:** não existe lugar para guardar a alíquota.
  **Plano:** [`PLAN-IMPOSTOS.md`](./PLAN-IMPOSTOS.md), Fases 2 e 3. **E2E:** `CT-E2E-061`.

- [x] **D-06 — RBAC existia só na interface.** ✅ **corrigido em 07/10/2026.** A permissão por
  perfil valia só na tela; com um token de vendedor dava para reconfigurar o fiscal e emitir
  notas pela API. Novo `app/Support/Permissoes.php` (matriz espelho do `permissoes.ts`) e
  middleware `RequireArea`, aplicado por grupo de rota — produtos/fornecedores/notas-entrada =
  produtos, clientes, vendas/pdv, nfe-emissoes = notas, configuracoes-fiscal/empresas = fiscal,
  users = usuarios. A factory de teste passou a nascer admin (quem testa perfil usa os estados).
  **Testes:** `tests/Feature/Auth/RbacApiTest.php`. **E2E:** `CT-E2E-027`, `CT-E2E-028`. (1.3.8)

- [x] **D-07 — Prazo de cancelamento alinhado em 24 h.** ✅ **corrigido em 06/10/2026.**
  O número errado estava em três níveis: a tela (`PRAZO_CANCELAMENTO_DIAS = 30`), a
  `gestaofacil-api` (também 30 dias, com **dois testes fixando o número errado**) e o Serviço de
  NF-e, que recusa em 24 h e é quem decide. Nota de três dias oferecia o cancelamento, prometia
  27 dias e levava 422 depois da justificativa digitada.
  **Correção:** `services.nfe_api.cancelamento_prazo_horas` (padrão 24, mesma variável do
  nfe-api), contagem em horas na API e na tela, e os dois testes corrigidos. 24 h é o prazo legal
  na maioria das UFs. **E2E:** `CT-E2E-064`.

  **Fica aberto no `nfe-api`:** o corte lá usa `updated_at`, não a data de autorização, então
  consultar o status da nota empurra a janela para frente.

- [x] **D-08 — E-mail repetido em empresas diferentes.** ✅ **Corrigido em 17/10/2026** por decisão do Allan:
  o e-mail é **único no sistema inteiro** (migração `2026_10_17_000001`, `UNIQUE(email)`). O cadastro recusa e-mail
  de qualquer empresa, com mensagem neutra. Supera a decisão de 07/10 (login por alias). (1.3.17)

### 🟡 Média

- [x] **D-09 — `consumidor_final`/`presenca` fixos e DIFAL ausente.** ✅ **corrigido em
  07/10/2026.** Era mais barato do que parecia: a `sped-nfe` já tinha `tagICMSUFDest` e já
  totalizava o `vICMSUFDest` no `vNF` (como o IPI). Três camadas:
  - **nfe-api:** `StoreNfeRequest` aceita `itens.*.difal` e `NfeXmlBuilder::difal()` monta o
    grupo ICMSUFDest (partilha 100% ao destino desde 2019). Validado contra o XSD.
  - **gestaofacil-api:** `consumidor_final` deixou de ser fixo — vem do cliente (contribuinte do
    ICMS comprando para revenda não é consumidor final). `RegrasFiscais::aliquotaInterestadual()`
    calcula a interestadual (4/7/12, regra federal); `difal()` monta a partilha na NF-e
    interestadual a consumidor final, exigindo a alíquota interna do destino (informada, varia
    por estado) e recusando quando falta, nomeando o produto.
  - **gestaofacil-fe:** a tela de emissão mostra os campos de DIFAL por item (interna do destino
    + FCP) só quando a partilha se aplica.

  **Fora do escopo (segue aberto):** DIFAL na **nota avulsa** — o `FormularioNotaAvulsa` ainda não
  chama `difal()`. O caminho de venda (o citado no defeito) está completo.
  **Testes:** `nfe-api/DifalPorItemTest` (4), `gestaofacil-api/DifalNaVendaTest` (8).
  **E2E:** `CT-E2E-056`, `CT-E2E-057`. (1.3.10)

- [x] **D-10 — Produto com ST sai sem CEST → Rejeição 806.** ✅ **corrigido em 07/10/2026.**
  `produtos` ganhou a coluna `cest` (migração `2026_10_07_000001`); a emissão manda o CEST quando
  existe, e **recusa antes de enviar** produto com ST sem CEST, nomeando o produto — em vez de
  deixar a SEFAZ rejeitar (806). A importação de XML de compra passou a **herdar** o CEST do
  fornecedor para o produto (criar e atualizar), que é de onde o dado já vinha.
  **Testes:** `tests/Feature/Nfe/CestTest.php`. **E2E:** `CT-E2E-063`. (1.1.2)

- [x] **D-11 — Produto sem NCM emitia `00000000` e era rejeitado pela SEFAZ.** ✅ **corrigido em
  06/10/2026.** `validarDadosDaNota()` recusa antes de enviar, dizendo **o nome do produto** e que
  o NCM tem 8 dígitos. Antes a nota era criada, o número gasto e a rejeição (777/778) voltava da
  SEFAZ. **E2E:** `CT-E2E-083`.

- [x] **D-12 — Código de barras que não é GTIN derrubava a nota inteira.** ✅ **corrigido em
  06/10/2026.** `RegrasFiscais::gtin()` só manda 8, 12, 13 ou 14 dígitos; o resto vira `null` e o
  Serviço de NF-e escreve "SEM GTIN". Código interno curto em produto a granel não impede mais a
  emissão. **E2E:** `CT-E2E-030`.

- [x] **D-13 — Cliente sem código do município não recebia NF-e.** ✅ **corrigido em
  06/10/2026.** Recusado antes de enviar, com **o nome do cliente** e a orientação de informar o
  CEP. Só vale para NF-e: a NFC-e não leva endereço. Apareceu junto que a `ClienteFactory` não
  preenchia o campo — os testes de emissão passavam mandando `codigo_municipio: 0`, payload que o
  Serviço de NF-e recusa em produção. **E2E:** `CT-E2E-054`.

- [x] **D-14 — Tela de naturezas não dizia qual campo vale para o CRT.** ✅ **corrigido em
  08/10/2026.** `ConfigNfeNaturezas` lê o CRT do emitente e aponta: Simples/MEI (CRT 1/4)
  preenche CSOSN; Regime Normal (CRT 2/3) preenche CST. O campo que não se aplica fica esmaecido;
  sem CRT cadastrado, orienta a cadastrá-lo. (1.3.12)

- [x] **D-15 — Informações complementares saíam com o slug da natureza.** ✅ **corrigido em
  06/10/2026.** A nota de venda ia com `infCpl` = "venda", impresso no quadro do DANFE que o
  cliente lê — está no XML de fixture `venda-propria-65.xml`. O campo deixou de ser preenchido na
  emissão por venda; na nota avulsa já era usado certo. **E2E:** `CT-E2E-055`.

- [x] **D-16 — Município/UF do destinatário readOnly, presos ao ViaCEP.** ✅ **corrigido em
  08/10/2026.** UF virou select, município virou input e o código IBGE (cMun, 7 dígitos) virou
  campo editável — o CEP ainda preenche os três no caminho feliz, mas dá para digitar quando o
  ViaCEP cai ou não conhece o CEP. A validação separou "município" de "código IBGE", cada um no
  seu campo. (1.3.2)

- [x] **D-17 — Convite de usuário engolia a falha de envio.** ✅ **corrigido em 09/10/2026.**
  `store` devolve `convite_enviado`; quando o e-mail não sai, a tela de usuários avisa o admin
  (azul, não erro — o usuário foi criado) e orienta a pessoa a usar "Esqueci a senha". **Sem
  reenvio, por decisão:** o sistema é usado por quem trabalha perto, o admin resolve na hora.
  **Teste:** `tests/Feature/Users/UserManagementTest.php`. (Parte 3)

- [x] **D-20 — SKU e endereço do destinatário acima do limite do layout.** ✅ **corrigido em
  06/10/2026.** Achado ao consertar D-04 e D-05, mesma classe: o SKU tem 100 caracteres no
  cadastro e o `cProd` aceita 60; rua, bairro, cidade e complemento têm 255 e os campos de
  endereço aceitam 60. O `cProd` sai de `RegrasFiscais::codigoProduto()`, único ponto por onde os
  **dois** caminhos de emissão passam — cortar ali consertou venda e nota avulsa de uma vez. A
  nota avulsa não tem campo de SKU na tela, então este era invisível até a emissão falhar.
  **E2E:** `CT-E2E-082` (passos de código e de endereço).

### 🟢 Baixa

- [x] **D-18 — Produtos sem SKU saíam todos com `cProd` = `SEM_SKU`.** ✅ **corrigido em
  06/10/2026.** Produto sem SKU recebe `PROD-{id}`. Dois produtos sem SKU na mesma nota ficavam
  com o mesmo código de item — a chave de conferência do destinatário e do contador.
  **E2E:** `CT-E2E-084`.

- [x] **D-19 — Venda vinda do PDV mostra pagamentos acima do total.** ✅ **corrigido em
  06/10/2026**, junto com o D-01, como previsto: os pagamentos gravados passaram a somar
  exatamente o total da venda e o dinheiro entregue foi para a coluna própria.
  **E2E:** `CT-E2E-053`.

### Limites de escopo conhecidos (não são defeitos de implementação)

- [ ] **Contingência offline da NFC-e** (`tpEmis = 9`): não existe. Com a SEFAZ fora, a venda
  fecha sem nota e sem fila de transmissão diferida em 24 h. (1.1.3)
- [ ] **SPED Fiscal / Sintegra / exportação mensal de XMLs:** não há rota em lote; o contador
  baixa nota por nota. (1.1.5)
- [ ] **DIFAL:** ver D-09.
- [ ] **Limites da NFC-e não são parametrizáveis por UF.** R$ 5.000/item, R$ 500.000 no total e
  120 itens estão fixos em código, nos dois serviços. Estado com teto menor para consumidor não
  identificado passa batido. (1.1.4)
- [ ] **Retry com backoff na SEFAZ:** vive na fila do `nfe-api`; avaliar lá, não é E2E. (1.4)

### Já conferido — **não** é defeito (não reabrir)

Cinco suspeitas levantadas na primeira análise foram refutadas no código. Ficam registradas para
ninguém gastar tempo de novo:

| Suspeita | Por que não procede |
|---|---|
| Desconto global sem rateio → Rejeição 602 | `Services\Nfe\Rateio` rateia em centavos e põe a sobra no item de maior valor; o frontend repete a conta |
| Race condition na numeração → Rejeição 204 | `nfe-api/NfeNumbering::reserveNext()` usa `lockForUpdate` dentro da transação, por CNPJ/série/ambiente/modelo |
| Falta validação de limite na NFC-e | Três limites validados nos dois serviços (ver "Limites de escopo") |
| ViaCEP sem fallback em cliente/fornecedor | Cidade é input e UF é select; só a tela de nota trava (D-16) |
| Ausência de estrutura de PIS/COFINS/ICMS | `RegrasFiscais::pisCofins()` e `icms()` existem e o serviço valida; faltam dois campos — D-02 e D-03 |

### Correção com maior retorno

**D-01, D-04, D-05, D-11, D-12, D-13 e D-18 têm a mesma causa:** o payload da emissão **a partir
de venda** é montado sem conferir o layout da NF-e. A nota avulsa (`FormularioNotaAvulsa`) faz
certo o que o `NfeEmissaoService` faz errado — troco, truncamento, validação por campo. Quatro
linhas de truncamento, o `troco` no payload e duas validações de tela fecham sete dos dezenove
itens desta lista.

---

> O roadmap abaixo é o plano original da v1 (14/09/2026). O status real de implementação da API
> está em [`gestaofacil-api/PROGRESS.md`](../../gestaofacil-api/PROGRESS.md), com entradas por data.


## Overview

14 concrete implementation steps, aligned with PLAN-API.md, PLAN-UI.md, and DATA-MODEL.md.

Each step corresponds to a git commit and closes with full test coverage (Pest).

**Master Phases Reference:**
- **Bloco 1:** Fase 0 — Project Setup
- **Bloco 2:** Fase 1 — Authentication & Multitenancy
- **Bloco 3:** Fase 2 — Fiscal Configuration
- **Bloco 4:** Fase 3 — Products & Stock
- **Bloco 5:** Fase 4 — Clients
- **Bloco 6:** Fase 5 — Vendas (PDV + Pedido)
- **Bloco 7:** Fase 6 — NFe Emission

---

## BLOCO 1: Setup & Security (Fase 0)

### Step 1: Docker Compose + Laravel 11 Skeleton
- [ ] Laravel 11 com Docker Compose (app, PostgreSQL, Redis)
- [ ] `.env.example` com variáveis necessárias
- [ ] Seeders básicos (2 empresas de teste)
- **Commit:** `chore: Docker + Laravel 11 skeleton`
- **Time:** ~30 min

### Step 2: Argon2ID Configuration + CI/CD Validation
- [ ] Copy `config/hashing.php.example` → `config/hashing.php` (driver: argon2id, memory: 65536, time: 4, threads: 4)
- [ ] Copy `scripts/check-security.php.example` → `scripts/check-security.php`
- [ ] Create `.github/workflows/security.yml` (runs `check-security.php` before deploy)
- [ ] Test: `php scripts/check-security.php` → ✅ Valid
- **Commit:** `chore: Argon2ID config + security CI validation`
- **Time:** ~20 min

### Step 3: Pest PHP Setup
- [ ] Install Pest + configure `phpunit.xml` or `pest.xml`
- [ ] Create `tests/` structure (Feature, Unit)
- [ ] First test: verify Docker/DB connection
- **Commit:** `chore: Pest PHP configured`
- **Time:** ~15 min

---

## BLOCO 2: Autenticação & Multitenancy (Fase 1)

### Step 4: Models + Migrations (Empresa, User, CompanyScope)
- [ ] Migration `2024_01_01_000001_create_empresas_table.php` (id, razao_social, nome_fantasia, cnpj UNIQUE, plano_id, ativo, timestamps)
- [ ] Migration `2024_01_01_000002_create_users_table.php` (id, empresa_id FK, nome, email, alias, password, perfil ENUM, ativo, timestamps) — UNIQUE(empresa_id, email), UNIQUE(empresa_id, alias)
- [ ] Model `Empresa` with `hasMany(User::class)`
- [ ] Model `User` with `belongsTo(Empresa::class)`, `belongsTo(Perfil::class)` (stub for now)
- [ ] Class `app/Models/Scopes/CompanyScope.php` extends `Scope` — auto-filter by `empresa_id`
- [ ] Add `CompanyScope` to BOTH `Empresa` and `User` models
- [ ] Test: Create 2 empresas with users, verify `User::all()` returns only current user's empresa
- **Commit:** `feat: Empresa + User models com CompanyScope`
- **Time:** ~45 min

### Step 5: Middleware `EnscopeToCompany`
- [ ] Create `app/Http/Middleware/EnscopeToCompany.php`
- [ ] In `handle()`: extract `empresa_id` from `Auth::user()->empresa_id`, add global where clause
- [ ] Register in `app/Http/Kernel.php` → `api` route group
- [ ] Test: Empresa A's token can't access Empresa B's data (404 or scope filters it out)
- [ ] Test: Verify SQL shows `.where('empresa_id', ?)`
- **Commit:** `feat: Multitenancy middleware EnscopeToCompany`
- **Time:** ~30 min

### Step 6: Endpoint `POST /login` + Rate Limiting
- [ ] Create `LoginController` or use resource route `POST /login`
- [ ] Receive: email, password
- [ ] Validate: email exists, password matches (use `Hash::check()` with Argon2ID), empresa is ativo
- [ ] Return: token (Sanctum), empresa_id, perfil
- [ ] Rate limit: 5 attempts per minute (use `RateLimit` middleware)
- [ ] Test: Valid login → 200 + token; Invalid password → 401; Empresa inativo → 403; 6th attempt in 60s → 429
- [ ] Test: User of Empresa A logs in, can't access Empresa B data
- **Commit:** `feat: Login endpoint com rate limiting e multitenancy`
- **Time:** ~50 min

### Step 7: Endpoint `POST /password/forgot` + Email
- [ ] Migration `2024_01_01_000003_create_password_reset_tokens_table.php` (email PK, token, created_at)
- [ ] Receive: email
- [ ] Generate: token (bin2hex(random_bytes(32))), hash it (SHA256)
- [ ] Store: email, hash(token), created_at
- [ ] Send: email with link `/password/reset?token=[plaintext_token]`
- [ ] Use Laravel Mailables or simple Mail::send()
- [ ] Test: Token stored as SHA256; Email sent; Plaintext token in link is correct hash
- **Commit:** `feat: Password forgot endpoint com token generation e email`
- **Time:** ~50 min

### Step 8: Endpoint `POST /password/reset`
- [ ] Receive: token (plaintext), password_new, password_confirmation
- [ ] Validate: 
  - Token hash matches stored token in DB
  - Token not expired (< 24h)
  - password_new: 8+ chars, maiúscula, minúscula, número, símbolo
  - password_new != password_current (get from User model via email in token)
  - password_new == password_confirmation
  - NOT in haveibeenpwned (API call or pre-loaded list)
- [ ] On success:
  - Update User.password with `Hash::make(password_new)` (Argon2ID)
  - Delete token row
  - Invalidate all Sanctum tokens for user (force re-login)
- [ ] Test: Weak password (< 8) → 422; Compromised password → 422; Valid → 200; Token used twice → 401; Token expired → 401
- **Commit:** `feat: Password reset com validação de força de senha`
- **Time:** ~60 min

---

## BLOCO 3: Configuração Fiscal (Fase 2)

### Step 9: ConfiguracaoFiscal Model + NfeApiClient Service
- [ ] Migration `2024_01_01_000004_create_configuracoes_fiscais_table.php` (id, empresa_id UNIQUE FK, ambiente TINYINT, status_certificado, cnpj_certificado, certificado_validade, numero_inicial_nfe, numero_inicial_nfce, nfe_api_token_id ENCRYPTED, timestamps)
- [ ] Model `ConfiguracaoFiscal` with `belongsTo(Empresa::class)`, `CompanyScope`
- [ ] Cache: `rememberForever("empresa:{empresa_id}:fiscal", ...)`
- [ ] Class `app/Services/NfeApiClient.php`:
  - Constructor: inject token (decrypted from ConfiguracaoFiscal)
  - Methods: `emitir(venda)`, `consultarStatus(protocolo_id)`, `cancelar(protocolo_id, justificativa)`, `cartaCorrecao(protocolo_id, campo, valor)`, `inutilizar(cnpj, serie, numero_inicial, numero_final, motivo)`
  - Logging: all requests to `nfe_requests` table
- [ ] Migration `2024_01_01_000005_create_nfe_requests_table.php` (id, empresa_id FK, venda_id FK, protocolo_id, tipo_requisicao ENUM, payload JSON, response JSON, http_status, erro_mensagem, created_at)
- [ ] Test: NfeApiClient methods exist (use `Http::fake()` to mock API responses)
- **Commit:** `feat: ConfiguracaoFiscal model + NfeApiClient service`
- **Time:** ~60 min

---

## BLOCO 4: Produtos & Estoque (Fase 3)

### Step 10: Produtos + EstoqueService
- [ ] Migration `2024_01_01_000006_create_produtos_table.php` (id, empresa_id FK, nome, sku, codigo_barras, preco_compra, preco_venda, ncm, unidade, estoque_atual, ativo, timestamps) — UNIQUE(empresa_id, sku)
- [ ] Migration `2024_01_01_000007_create_estoque_movimentacoes_table.php` (id, empresa_id FK, produto_id FK, tipo ENUM[entrada|saida|ajuste], quantidade, motivo, venda_id FK, usuario_id FK, created_at)
- [ ] Model `Produto` with `CompanyScope`, `hasMany(EstoqueMovimentacao::class)`
- [ ] Model `EstoqueMovimentacao` with `belongsTo(Produto::class)`, `belongsTo(Venda::class)` (stub)
- [ ] Class `app/Services/EstoqueService`:
  - `lancar(produto_id, quantidade, tipo, motivo, venda_id?)`: creates row in estoque_movimentacoes, updates produtos.estoque_atual, invalidates cache
  - `estornar(venda_id)`: reverses all movimentações for venda (for cancellation)
- [ ] **CRITICAL:** Never update `estoque_atual` directly — only via EstoqueService
- [ ] CRUD endpoints: `POST /produtos`, `GET /produtos`, `GET /produtos/{id}`, `PATCH /produtos/{id}` (including toggle `ativo`), `DELETE /produtos/{id}`
- [ ] Cache: `remember("empresa:{empresa_id}:produtos", 3600, ...)` — invalidate on CRUD
- [ ] Test: Create produto → appears in list; Inativar → doesn't appear in default list; Lançar entrada → estoque_atual increments; Lançar saida → decrements; EstoqueService is only point of update
- **Commit:** `feat: Produtos and Estoque with movement audit trail`
- **Time:** ~70 min

---

## BLOCO 5: Clientes (Fase 4)

### Step 11: Clientes CRUD
- [ ] Migration `2024_01_01_000008_create_clientes_table.php` (id, empresa_id FK, nome, cpf_cnpj, telefone, email, endereco, timestamps) — UNIQUE(empresa_id, cpf_cnpj)
- [ ] Model `Cliente` with `CompanyScope`, `hasMany(Venda::class)` (stub)
- [ ] CRUD endpoints: `POST /clientes`, `GET /clientes`, `GET /clientes/{id}`, `PATCH /clientes/{id}`, `DELETE /clientes/{id}`
- [ ] Cache: `remember("empresa:{empresa_id}:clientes", 1800, ...)` — invalidate on CRU
- [ ] Test: Create cliente → appears in list; Cliente from Empresa A hidden from Empresa B; Multitenancy test
- **Commit:** `feat: Clientes CRUD`
- **Time:** ~40 min

---

## BLOCO 6: Vendas — Pedido Only (Fase 5)

### Step 12: Vendas Models + Business Logic
- [ ] Migration `2024_01_01_000009_create_vendas_table.php` (id, empresa_id FK, cliente_id FK, usuario_id FK, origem ENUM[pdv|pedido], tipo_documento ENUM[nfe|nfce|nenhum], situacao ENUM[em_aberto|atendido|cancelado], total, estoque_lancado_em, + 8 NFe fields: nf_protocolo_id, nf_chave_acesso, nf_chave_acesso_anterior, nf_environment, nf_status, nf_contingencia_ativa, nf_xml_url, nf_danfe_url, timestamps)
- [ ] Migration `2024_01_01_000010_create_venda_itens_table.php` (id, venda_id FK, produto_id FK, quantidade, preco_unitario, desconto)
- [ ] Migration `2024_01_01_000011_create_venda_pagamentos_table.php` (id, venda_id FK, forma_pagamento VARCHAR, valor, created_at)
- [ ] Models: `Venda`, `VendaItem`, `VendaPagamento` with relationships + `CompanyScope`
- [ ] Migration `2024_01_01_000012_create_password_change_history_table.php` (id, user_id FK, empresa_id FK, tipo ENUM[criacao|alteracao|reset], ip_address, user_agent, sucesso BOOLEAN, motivo_falha, created_at)
- [ ] **LOGIC (Fase 5 — Only Pedido for now, PDV comes in Step 14):**
  - `VendaService::criar()`: creates venda with `origem='pedido'`, `tipo_documento='nfe'` (default), `situacao='em_aberto'`
  - Validation: Σ(venda_pagamentos.valor) == total (exact match)
  - `PATCH /vendas/{id}/situacao`: change `em_aberto` → `atendido` or → `cancelado`
  - On cancel: if `estoque_lancado_em` is set, call `EstoqueService::estornar()`
  - Separate endpoint `POST /vendas/{id}/estoque/lancar` to explicitly launch stock
- [ ] Test: Create pedido → em_aberto; Payment sum mismatch → 422; Cancel → storno called if stock launched; Multitenancy
- **Commit:** `feat: Vendas (pedido only) with payment validation + estorno`
- **Time:** ~80 min

---

## BLOCO 7: NFe Emission Integration (Fase 6 — The BIG One)

### Step 13: Pedido — Endpoint `POST /vendas/{id}/emitir-nfe` + Webhook + Polling
- [ ] **Endpoint `POST /vendas/{id}/emitir-nfe`:**
  - For Pedido (`origem='pedido'`): Accept `tipo_comprovante` (nfe | cupom_nao_fiscal | nenhum)
  - Validate: venda is `atendido`, empresa has valid certificate (if tipo_comprovante=nfe)
  - If nfe: Call `NfeApiClient::emitir(venda)` → get `protocolo_id`, store in venda, set `nf_status=queued`
  - If cupom_nao_fiscal or nenhum: just mark tipo_documento, no API call
  - Return 202 (accepted, processing)
- [ ] **Webhook Receiver `POST /webhook/nfe`:**
  - Validate: HMAC signature matches (shared secret with nfe-api)
  - Extract: protocolo_id, nf_status, nf_chave_acesso, nf_danfe_url, etc.
  - Update venda: set nf_status, nf_chave_acesso, nf_danfe_url
  - If nf_chave_acesso differs from nf_chave_acesso_anterior: set `nf_contingencia_ativa=true`
  - Send notification to user (toast + email optional)
- [ ] **Job `SyncNfeStatusJob`:**
  - Runs every 30s (use Laravel scheduler)
  - Query all vendas with nf_status in [queued, processing]
  - For each: call `NfeApiClient::consultarStatus(protocolo_id)`
  - Update nf_status if changed
  - Stop when reaching authorized/rejected
- [ ] **Endpoint `GET /vendas/{id}/nfe-status`:**
  - Return current nf_status for manual polling fallback
- [ ] **Logging:** All requests logged to `nfe_requests` table
- [ ] Test (with `Http::fake()`): 
  - Emissão válida → 202 + protocolo_id + queued
  - Webhook atualiza status
  - Polling traz mudanças
  - Contingência marca flag
  - API erro (403, 422, 500) → handled correctly
- **Commit:** `feat: NFe emission with webhook + polling (pedido only)`
- **Time:** ~120 min

### Step 14: PDV — Automatic NFC-e Emission (modelo 65)
- [ ] **Endpoint `POST /vendas/pdv`** (create + auto-emit):
  - Receive: cliente (optional, defaults to "Consumidor Final"), itens, pagamento(s)
  - Create venda: `origem='pdv'`, `tipo_documento='nfce'` (FORCED), `situacao='em_aberto'`
  - IMMEDIATELY call `NfeApiClient::emitir(venda)` (no wait for user confirmation)
  - Return 202 + venda + nf_status (for frontend polling)
- [ ] **Same webhook + polling as Step 13** (reuse job)
- [ ] **UI shows status in real-time:**
  - After "confirmar venda": spinner "Processando..."
  - On webhook/polling update: "✅ Autorizada" or "❌ Rejeitada"
  - If rejected: [Reenviar] or [Voltar para carrinho]
- [ ] **CRITICAL DIFFERENCE from Pedido:**
  - PDV: origin=pdv, tipo_documento=nfce ALWAYS (no option)
  - PDV: emit automatic (no manual `POST /emitir-nfe` call)
  - Pedido: origin=pedido, tipo_documento has options, manual emit
- [ ] Test: Create PDV venda → nfc-e emitted immediately → status updates via webhook
- **Commit:** `feat: PDV with automatic NFC-e emission (modelo 65)`
- **Time:** ~80 min

---

## Summary Table

| Step | Phase | Component | Estimated Time |
|------|-------|-----------|-----------------|
| 1 | 0 | Docker + Laravel | 30 min |
| 2 | 0 | Argon2ID + CI/CD | 20 min |
| 3 | 0 | Pest | 15 min |
| 4 | 1 | Empresa, User, Scope | 45 min |
| 5 | 1 | Middleware | 30 min |
| 6 | 1 | Login + Rate Limit | 50 min |
| 7 | 1 | Password Forgot | 50 min |
| 8 | 1 | Password Reset | 60 min |
| 9 | 2 | Fiscal Config + NfeApiClient | 60 min |
| 10 | 3 | Produtos + Estoque | 70 min |
| 11 | 4 | Clientes | 40 min |
| 12 | 5 | Vendas (Pedido) | 80 min |
| 13 | 6 | Emission Integration + Polling | 120 min |
| 14 | 6 | PDV Auto NFC-e | 80 min |
| **Total** | | | **~790 min (~13 hours)** |

---

## Checkpoints & Blockers

**Critical Dependencies:**
- nfe-api must support NFC-e (modelo 65) before Step 14
- nfe-api webhook endpoint must be documented (HMAC secret, payload shape)
- PostgreSQL + Redis must be running (Docker Compose in Step 1)

**Blockers to Release:**
- [ ] All 14 steps completed
- [ ] Full test coverage (Pest)
- [ ] Multitenancy tests for EACH endpoint
- [ ] CI/CD security validation passing
- [ ] Manual testing of PDV + Pedido flows

---

## Next Steps After v1

- Fase 7: Cancelamento + CC-e
- Fase 8: Dashboard + Certificate monitoring
- Fase 9: User password change area
- Fase 10: User management (admin)
- Fase 11: Permissions (roles)
- Fase 12: Plans

See `PLAN-API.md` Fases 7-12 for details.


---

## 2026-10-19 — Distribuição de DF-e (PLAN-DISTDFE), Fase 1 fechada

`nfe-api` (commit `0f098ed`): `distNSU`/`consChNFe` no gateway, parser do docZip, buffer `dfe_documentos` com ack
(o NSU só avança quando a gestaofacil-api confirma), `CooldownDaDistribuicao` como único ponto de saída (1 h + 5 min,
12 h entre varreduras, 24 h com outro sistema na cota, orçamento de consultas por chave, kill switch em 3 bloqueios),
gateway real desligado fora de produção. 60 testes novos; suíte com as mesmas 4 falhas do baseline.
Fora: migrations não aplicadas no banco de dev; CNPJ alfanumérico no resto do código (PLAN-DISTDFE §14.2).

### Fase 2 fechada (mesmo dia)

`gestaofacil-api` (`2cf08dc`): `dfe_recebidos` (só resumo), sincronização que grava e só então confirma o NSU, cancelamento do fornecedor
vira marca + aviso (nunca estorno), lista por mês, totais "recebidas" x "lançadas", habilitar na área fiscal. 28 testes novos.
`gestaofacil-fe` (`37d20e1`): tela Notas na SEFAZ com seletor de mês e botão com contagem regressiva.
Fora: conferência visual no Firefox (sua) e E2E.

### Fase 3 fechada (mesmo dia)

Manifestação do destinatário: `nfe-api` `360c234` (tabela `manifestacoes` com índice único parcial, regras de transição, orçamento próprio, 21 testes),
`gestaofacil-api` (ato do administrador, ciência em massa até 50, auditoria, 19 testes), `gestaofacil-fe` (Dar ciência, Recusar, seleção em massa).
Fora: Confirmação da Operação na tela (aguarda o contador); conferência visual no Firefox (sua).

### Fase 4 fechada (mesmo dia) — Fases 1 a 4 do PLAN-DISTDFE concluídas

`gestaofacil-api` `6d8f56d`: importar nota da SEFAZ (XML guardado ou uma busca por chave com espera de 30 min; "ainda não liberou" é estado), 27 testes incluindo o ponta a ponta
resumo → ciência → procNFe → nota em rascunho. `gestaofacil-fe` `d7b939d`: Importar itens com contagem. Fase 5 (varredura diária) NÃO feita; sem ela, 60 dias sem clicar perdem notas.
Pendente com você: Firefox, migrations no dev, decisões do PLAN-DISTDFE §14.3.

### 2026-10-19 — CNPJ alfanumérico em todo o sistema + Confirmação da Operação

`nfe-api` `1d033e8`, `gestaofacil-api` `110e647`, `gestaofacil-fe` `dbb5ed9`: `Support\Cnpj` nas duas APIs e `normalizarDocumento` no front (DV módulo 11 com ASCII − 48, confere com o exemplo da Receita),
rotas/requests/certificado/XML/importação de compra/busca/formulários aceitam letras; schemas derivados do PL_010 para a validação local. 21 + 19 testes e 28 verificações no front.
Confirmação da Operação na tela (`gestaofacil-fe` `f745c89`). Fora: SEFAZ real (nunca testada com CNPJ alfanumérico), E2E com CNPJ alfanumérico.

### 2026-10-20 — Fase 5 do PLAN-DISTDFE (varredura automática)

`gestaofacil-api` `20febf6`: `dfe:sincronizar` no agendador (02:00–06:00 Brasília, sem sobrepor), 17 testes. Só empresas com busca ativada, em produção, sem outro sistema na cota; aviso no log perto dos 60 dias.
Não empurrado ao remoto. Próxima: Fase 6 (XML em lote/ZIP).

### 2026-10-20 — Fase 6 do PLAN-DISTDFE (XML em lote/ZIP)

`POST /notas-entrada/importar-lote` (`ImportacaoEmLote`) e tela de importação com vários XMLs/ZIP e resultado por arquivo. Um só XML segue para a conferência como antes. Falta: conferência no Firefox (sua) e E2E do lote.

### 2026-10-20 — Varredura às 04:00 com chave por empresa; configurar busca; limite do lote

`nfe-api`: coluna `busca_automatica`, `POST /dfe/configurar`, intervalo compartilhado 20 h (7 testes novos/ajustados). `gestaofacil-api`: agenda `dailyAt('04:00')`, comando sem intervalo próprio nem env, rota `dfe/configurar`, lote com 8 MB.
`gestaofacil-fe`: painel "Configurar a busca" em *Notas na SEFAZ* (liga/desliga e muda "outro sistema"), lote confere 8 MB. Decisões em PLAN-DISTDFE §14.6. Falta: sua conferência no Firefox.

### 2026-10-20 — PLAN-DISTDFE encerrado

Fases 1 a 6 concluídas e no remoto. Pendências (Firefox, contador, CNPJ alfanumérico real, virada para produção) em PLAN-DISTDFE §14.7.

### 2026-10-20 — Fuso da aplicação passa a ser Brasília

`gestaofacil-api`: `APP_TIMEZONE=America/Sao_Paulo` (padrão) e timezone da conexão pgsql. Resolve o filtro de data da lista Notas fiscais. 925 testes passam (5 falhas antigas); E2E não reexecutado.
