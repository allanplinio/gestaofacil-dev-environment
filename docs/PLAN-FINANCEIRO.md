# PLAN-FINANCEIRO.md — Módulo Financeiro do GestãoFácil (multiempresa)

**Status:** **PLANO — nada implementado.** Nenhuma migration, nenhum código. Escrito em 2026-10-19 a
partir do esboço do usuário (§1) e conferido contra o código atual de `gestaofacil-api` e
`gestaofacil-fe`. As decisões **D1 a D18** (§9) estão abertas; a ordem das fases (§8) depende delas.

**Documentos relacionados:** [`REQUISITOS.md`](./REQUISITOS.md) (§12 hoje lista Financeiro, Controle de
Caixa e Parcelamento como *fora de escopo* — **este plano os traz para dentro; o REQUISITOS.md só
é atualizado depois da aprovação, não agora**) · [`DATA-MODEL.md`](./DATA-MODEL.md) ·
[`PLAN-UI.md`](./PLAN-UI.md) · [`PLAN-SEGURANCA.md`](./PLAN-SEGURANCA.md) ·
[`PLAN-IMPORTACAO-XML.md`](./PLAN-IMPORTACAO-XML.md) · [`PLAN-DISTDFE.md`](./PLAN-DISTDFE.md)

---

## 1. Objetivo (do esboço, com ajustes)

Dar a PMEs uma gestão financeira **simples, previsível e automatizada**: visibilidade do fluxo de
caixa **realizado vs. projetado**, menos inadimplência e rotina operacional automatizada, sem a
complexidade de um ERP tradicional.

**Princípio de desenho:** o financeiro **nasce do que o sistema já faz** (venda, PDV, nota de entrada),
não de digitação dupla. Se a venda foi finalizada e a nota de compra foi lançada, o financeiro já
sabe. Lançamento manual é exceção (aluguel, energia, salário), não a regra.

---

## 2. Revisão do esboço

### 2.1 O que está bom e fica

| Item do esboço | Veredito |
|---|---|
| A — abertura, sangria, suprimento, fechamento cego | **Fica, é o coração do v1.** Encaixa no PDV existente. |
| A — múltiplos caixas e contas | **Fica**, mas como "contas financeiras" (§5.1). |
| B — contas a pagar/receber, parcelas, recorrência | **Fica.** |
| B — plano de contas + centro de custo (dois níveis) | **Fica.** Ver §2.3 sobre "filial". |
| D — fluxo de caixa (caixa) e DRE (competência) | **Fica**, em fases separadas: fluxo antes, DRE depois. |

### 2.2 Item C (Conciliação/Integrações) — **concordo: vira futuro, mas dividido em duas metades**

O instinto está certo, e por razões concretas do nosso contexto:

1. **Open Finance não é "ler um arquivo".** É consentimento do cliente final, instituição
   participante ou agregador pago (Pluggy, Belvo etc.), contrato, custo por conexão e renovação de
   consentimento. Em multiempresa isso vira **credencial por empresa**, com o mesmo cuidado que já
   temos com o certificado A1 (criptografia, rotação, auditoria).
2. **Baixa automática por PIX/boleto/cartão exige um PSP** (Efí, Asaas, Pagar.me…): contrato, webhook
   autenticado, conciliação de taxas, e **boleto registrado** exige convênio com banco. É um produto
   dentro do produto. Cada empresa teria o próprio contrato ou usaríamos subconta — decisão
   comercial, não técnica.
3. **O v1 nem tem ainda a base** que a conciliação consome (títulos, contas, movimentações). Fazer C
   antes é construir o telhado sem parede.
4. Já temos um precedente do custo de integração externa: o DistDFe levou seis fases e só foi
   validado na SEFAZ real depois de pronto (testado em produção em 20/10/2026). Integração com
   banco/PSP tem o mesmo caminho de validação e mais dinheiro envolvido.

**Divisão proposta:**

| Parte | Conteúdo | Quando |
|---|---|---|
| **C1 — Conciliação por arquivo** | Importar **OFX/CSV** do banco, casar linha do extrato com baixa/título (valor + data + regras), marcar como conciliado. Sem terceiros, sem custo, sem credencial. | **Fase 10 (opcional, após o núcleo estável)** — é a parte barata e útil. |
| **C2 — Integrações vivas** | Open Finance, PIX dinâmico, boleto registrado, baixa por webhook. | **Futuro (v3)**, com gatilho: cliente real pedindo e PSP escolhido. |

**O que fazemos agora para C2 não custar refatoração (sem implementar nada dele):** o modelo de dados
(§5) já tem `origem` na baixa, `conciliado_em` na movimentação e `conta_financeira_id` em tudo.
Nada além disso.

### 2.3 Pontos do esboço que precisam de correção ou decisão

- **"Filial Recife" como exemplo de centro de custo** mistura duas coisas. No GestãoFácil,
  **empresa = CNPJ = tenant** (`empresas.cnpj` é único; não existe tabela de filial). Centro de custo
  é uma etiqueta **dentro** de uma empresa (departamento, projeto, loja). **Consolidar vários CNPJs de
  um mesmo grupo** (visão de matriz + filiais) é outra feature (grupo econômico) e **fica fora**
  (registrado em §10). Ver D4.
- **WhatsApp na régua de cobrança:** exige API oficial (Meta/BSP), templates aprovados, custo por
  mensagem e consentimento. **E-mail primeiro** (já existe `Mail` e `QUEUE_CONNECTION=redis`; em dev
  o `MAIL_MAILER=log`, ou seja, **envio real nunca foi verificado**). WhatsApp entra como canal
  futuro da mesma régua.
- **"Reenvio de PIX/boleto"** na régua depende de C2. Sem PSP, a régua envia **lembrete com valor,
  vencimento e a chave PIX estática da empresa** (campo em texto) — útil e sem integração.
- **EBITDA simplificado:** só faz sentido se houver depreciação/amortização e juros separados no plano
  de contas. Para PME comum, sai como **"Resultado operacional"**; EBITDA só com as categorias
  marcadas (campo `grupo_dre`). Não prometer EBITDA com plano de contas padrão.
- **DRE por competência exige CMV.** O sistema sabe o custo do produto hoje (`preco_compra`, custo
  calculado na nota de entrada, `produto_preco_historico`), mas **a venda não guarda o custo no
  momento da venda**. Sem isso, o CMV muda retroativamente quando o custo muda. Ver D7.
- **"Turno de Recebimento"** (título do item D) não está definido no texto; assumo "análise por forma
  de recebimento/turno de caixa". Confirmar.
- **PME (Prazo Médio de Estocagem)** entra no esboço como "Estocagem" junto de PMP/PMR. Estoque existe
  (`estoque_movimentacoes`), então é calculável, mas é a última coisa da fila (Fase 9).
- **Erros de digitação** no esboço ("Operational", "regras de regras") corrigidos neste texto.

---

## 3. O que o sistema já tem e o financeiro reaproveita

Levantado no código em 2026-10-19:

| Existe | Onde | Uso no financeiro |
|---|---|---|
| Isolamento por empresa | `Models/Scopes/CompanyScope` (filtra por `Auth::user()->empresa_id`) | Todo model novo usa. **Atenção ao ponto de falha em §4.3.** |
| Perfis e áreas | `Support\Permissoes` (admin, operador, vendedor × áreas) + `RequireArea` | Nova área `financeiro`. Espelhar em `gestaofacil-fe/src/contexts/permissoes.ts`. |
| Auditoria só-inserção | `Services\Auditoria::registrar()` | Abertura/fechamento de caixa, baixa, estorno, cancelamento. |
| Planos com `features` e limites | `Plano` (`features` jsonb, limites que **avisam e não bloqueiam**) | **A coluna existe, mas nenhum código a consulta** (conferido: só `PlanoController` a lista). O mecanismo de "feature por plano" **precisa ser criado** na Fase 1 (D13). |
| Vendas com pagamentos | `Venda`, `VendaPagamento` (`dinheiro`, `credito`, `debito`, `pix`; `valor_recebido` para troco) | Origem das entradas à vista. **Não existe "a prazo/fiado/boleto".** |
| PDV | `PdvVenda`, `PdvSecao` (hoje só `nome`/`descricao`/`ativo`), `PdvVendaService::checkout` | Ponto de ligação do caixa. `PdvSecao` **não é terminal nem sessão de caixa**. |
| Nota de entrada | `NotaEntrada` (`valor_total`, `dh_emissao`, `fornecedor_id`, status `rascunho/lancado/cancelado`), `LancamentoNotaService::lancar` | Origem das contas a pagar. **Conferido: `LeitorXmlNfe` e o DTO não leem `<cobr><dup>`** (parcelas/vencimentos). A Fase 4 inclui ampliar o leitor, o DTO e guardar as duplicatas (D14). |
| Cancelamento de venda | **Dois caminhos:** `VendaService::cancelar` (`POST /vendas/{id}/cancelar`, já devolve estoque) e `PdvVendaService::cancelar` (`POST /pdv-vendas/{id}/cancelar`) | Os dois precisam estornar o financeiro. |
| Finalização de venda | **Dois caminhos:** `PdvVendaService::checkout` (PDV, cria venda interna e pagamentos de uma vez) e `VendaService::finalizar` (tela Vendas, pagamentos adicionados antes) | O gancho financeiro tem de existir nos dois, num ponto comum (D15). |
| Scheduler | `routes/console.php` (`nfe:reconciliar-pendentes` a cada 5 min) | Recorrências, geração de vencidos, régua. |
| Fila Redis | `QUEUE_CONNECTION=redis` | Envio de e-mail da régua. |
| E-mail | `Mail\*` (convite, reset) | Base do template de cobrança. |
| Fornecedores / Clientes | `Fornecedor`, `Cliente` (com `consumidor_final`) | Contraparte do título. |

---

## 4. Multiempresa — regras que valem para o módulo inteiro

### 4.1 Regras

1. **Toda tabela nova tem `empresa_id` NOT NULL** com FK e **índice composto começando por
   `empresa_id`**. Todo unique inclui `empresa_id` (ex.: nome de categoria único *por empresa*).
2. **`empresa_id` nunca vem do request.** Vem de `Auth::user()`, como já é em `VendaService`.
3. **Todo model usa `CompanyScope`.** Route model binding sob o scope devolve 404 para registro de
   outra empresa — **cada rota nova tem teste disso**.
4. **Referências cruzadas validam a empresa:** `categoria_id`, `centro_custo_id`, `conta_financeira_id`,
   `cliente_id`, `fornecedor_id` informados no request precisam pertencer à mesma empresa. O scope
   protege a *leitura*; uma FK solta não. Usar `Rules\` (já existe a pasta) com `exists` escopado.
5. **Plano de contas e contas financeiras padrão são criados por empresa** (seeder chamado por
   `CadastroDeEmpresa`) **e há migração de preenchimento (backfill) para as empresas existentes.**
6. **Feature por plano:** `financeiro` em `planos.features`. **O mecanismo não existe** (§3): criar um
   `RequireFeature` análogo ao `RequireArea` e expor as features em `/me` para o menu. Sem a feature, a API responde 403 e o
   menu some. Limite de lançamentos/mês só **avisa** (regra do REQUISITOS §11).
7. **Auditoria com `empresa_id`** em todo evento financeiro (o `Auditoria` já preenche).

### 4.2 Fuso horário

`config/app.php` usa `APP_TIMEZONE` com padrão **UTC**. "Fechamento do dia", "vencido hoje" e a
competência da venda seriam calculados em UTC: uma venda às 22h em Recife cai no dia seguinte. Antes
da Fase 2, definir o fuso do negócio e **testar a virada do dia**; sem isso, fluxo de caixa e
fechamento saem errados à noite (D17).

### 4.3 Risco específico: jobs e comandos agendados não passam pelo `CompanyScope`

`CompanyScope::apply` faz `if (!Auth::check()) return;` — **sem usuário autenticado o filtro não
existe**. No scheduler, na fila e em comandos artisan **não há usuário**. Logo, uma recorrência ou
régua escrita com `Titulo::where('status','aberto')->get()` varre **todas as empresas misturadas**.

Regra do módulo: **todo job/comando financeiro itera empresa por empresa** (`Empresa::where('ativo', true)` (não existe
scope `ativas()` em `Empresa`) + `withoutGlobalScopes()->where('empresa_id', …)`), com a empresa passada explicitamente como
parâmetro do job. Teste obrigatório: duas empresas, rodar o comando, conferir que nada de uma
aparece na outra.

---

## 5. Modelo de dados proposto

> **Rascunho para discutir, não migration.** Valores em `decimal(15,2)`; datas de vencimento e
> competência em `date`; instantes em `timestampTz` (como `notas_entrada`). Nenhum campo é criado em
> tabela existente sem aprovação (D1, D7).

### 5.1 Cadastros

- **`contas_financeiras`** — onde o dinheiro está: `tipo` = `caixa` | `banco` | `carteira_digital` |
  `operadora_cartao`. `saldo_inicial`, `data_saldo_inicial`, `ativa`. `pdv_secao_id` opcional (caixa
  físico ligado a um ponto de venda). *Saldo nunca é coluna: é `saldo_inicial + Σ movimentações`.*
- **`categorias_financeiras`** — plano de contas em árvore (`pai_id`): `tipo` = `receita` | `despesa`,
  `grupo_dre` (receita bruta, deduções, CMV, despesa operacional, despesa financeira, outras…),
  `sistema` (bool: as semeadas não se apagam, só se inativam).
- **`centros_custo`** — `nome`, `ativo`. Etiqueta dentro da empresa (D4).

### 5.2 Títulos e baixas

- **`titulos`** — um registro por **parcela**: `tipo` (`pagar` | `receber`), `cliente_id` ou
  `fornecedor_id` (um só), `descricao`, `valor`, `vencimento`, `competencia` (date), `categoria_id`,
  `centro_custo_id`, `parcela_numero`/`parcela_total`, `grupo_parcelamento` (uuid), `status`
  (`aberto` | `parcial` | `pago` | `cancelado`), `valor_baixado`, **`origem_tipo`/`origem_id`**
  (`venda`, `nota_entrada`, `manual`, `recorrencia`), `recorrencia_id`.
- **`baixas`** — pagamento/recebimento de um título: `titulo_id`, `conta_financeira_id`, `valor`,
  `juros`, `multa`, `desconto`, `data`, `forma`, `usuario_id`, `estorno_de_id`, `origem`
  (`manual` hoje; `ofx`/`psp` no futuro — é o gancho de C2).
- *Status "vencido" não é gravado:* é derivado (`aberto`/`parcial` com `vencimento < hoje`); gravar exigiria job diário e ficaria errado na virada do dia.
- **Concorrência:** baixa e estorno fazem `lockForUpdate` no título dentro da transação (como `LancamentoNotaService`); sem isso, duas baixas simultâneas passam do valor.
- **Índices:** `titulos (empresa_id, tipo, status, vencimento)`, `titulos (empresa_id, cliente_id)`, `movimentacoes (empresa_id, conta_financeira_id, data)`; unique `(empresa_id, origem_tipo, origem_id, parcela_numero)` evita gerar o mesmo título duas vezes.
- **`recorrencias`** — modelo de lançamento fixo: periodicidade, dia, valor (fixo ou "variável: pede
  valor na geração"), próxima geração, `ativa`. Gera títulos **com antecedência curta (ex.: 60
  dias)**, idempotente por `(recorrencia_id, competencia)` unique.

### 5.3 Livro do dinheiro

- **`movimentacoes`** — **única fonte do saldo**. Sangria e suprimento são **transferências de duas pernas** (caixa ⇄ cofre/banco) ligadas por `transferencia_id`; lançamento solto muda o saldo total da empresa sem explicação. Venda em dinheiro entra pelo **`valor`** do pagamento, nunca por `valor_recebido` (troco não é entrada): `conta_financeira_id`, `data`, `valor` com sinal,
  `tipo` (`baixa`, `venda`, `sangria`, `suprimento`, `transferencia`, `ajuste`, `abertura`),
  `baixa_id` / `venda_pagamento_id` / `caixa_sessao_id` conforme a origem, `conciliado_em` (gancho de
  C1). **Imutável:** correção é movimentação de estorno, nunca UPDATE/DELETE — garantido por **trigger no
  Postgres** como em `auditoria_eventos`, não só por convenção.

### 5.4 Caixa operacional

- **`caixa_sessoes`** — `pdv_secao_id`, `conta_financeira_id`, `operador_id`, `aberta_em`,
  `saldo_abertura`, `fechada_em`, `fechada_por`, `status` (`aberta` | `fechada_aguardando_conferencia`
  | `conferida`), `conferida_por/em`, `justificativa`. **Unique parcial: uma sessão `aberta` por
  `(empresa_id, conta_financeira_id)`** (mesmo padrão do índice parcial de `notas_entrada`). *Não por
  `pdv_secao_id`: o PDV hoje envia `pdv_secao_id: null` e o checkout aceita `null`; unique sobre coluna
  nula não impede nada. A sessão é do caixa (conta); a seção é vínculo opcional.* Qual sessão uma
  venda usa: D16.
- **`caixa_sessao_fechamento`** — uma linha por forma de pagamento: `declarado` (operador),
  `esperado` (calculado **e gravado só no fechamento**), `diferenca`.

### 5.5 Futuro (não criar agora)

`regua_cobranca`, `cobranca_envios` (Fase 8); `extratos_importados`, `extrato_linhas` (Fase 10 / C1);
credenciais de PSP/Open Finance (C2).

---

## 6. Como o financeiro se liga ao que já existe

| Evento existente | Efeito financeiro | Observação |
|---|---|---|
| Venda/PDV finalizada, pagamento **dinheiro** | `movimentacao` (+) na conta do caixa da sessão aberta | Sem título: à vista não precisa de contas a receber (D3). |
| Pagamento **PIX / débito** | `movimentacao` (+) na conta bancária padrão da forma | Conta destino configurada por empresa. |
| Pagamento **crédito** | `titulo` a receber na conta `operadora_cartao`, vencimento = hoje + prazo (default 30 d), taxa configurável | Baixa manual até existir C1/C2. Entrada na Fase 7 (D5). |
| Venda **a prazo / fiado** (nova forma) | `titulo(s)` a receber do cliente | **Exige nova forma em `VendaPagamento::FORMAS_VALIDAS` e cliente identificado** — mexe no PDV (D2). |
| Nota de entrada **lançada** | `titulo(s)` a pagar do fornecedor, parcelas do `<cobr><dup>`; sem duplicatas → 1 título à vista | Usa o gancho de `LancamentoNotaService::lancar` na mesma transação. |
| Nota de entrada **cancelada** | cancela os títulos *abertos*; se já houve baixa, **bloqueia e avisa** | Estorno de dinheiro já pago é decisão humana. |
| Venda **cancelada** | estorna movimentações / cancela títulos | Hoje `VendaService::cancelar` só devolve estoque. |
| **NFC-e/NF-e cancelada** | **Não** altera o financeiro por si | O cancelamento fiscal é registrado antes da SEFAZ confirmar (memória "Decisões fiscais pendentes"). O estorno financeiro segue o cancelamento da **venda**, não o pedido à SEFAZ. |

**Regra de ouro:** o vínculo é sempre **na mesma transação** do evento de origem (`DB::transaction`,
como em `LancamentoNotaService`) — ou os dois acontecem ou nenhum.

---

## 7. Permissões e segurança

- **Nova área `financeiro`** em `Permissoes`: `admin` sim; `operador` e `vendedor` **não**.
- **Caixa é operação de PDV, não de financeiro:** abrir, sangrar, suprimir e **declarar o
  fechamento** ficam sob a área `pdv` (o vendedor opera o caixa — ver PLAN-UI §6a). **Conferir
  divergência, ver saldo esperado e contas a pagar/receber/DRE** ficam sob `financeiro`.
- **Fechamento cego precisa ser cego na API, não só na tela.** O endpoint que o operador usa para
  fechar **não devolve** o `esperado` nem a `diferenca` — devolve só "recebido". O frontend esconder
  o número não basta (é a mesma lição do D-06 de `Permissoes`).
- **Sangria e suprimento** exigem justificativa obrigatória e geram `Auditoria`.
- **Sessão fechada é imutável**; reabrir é ação do `admin`, com motivo, auditada.
- **Baixa não se edita, se estorna.** Título com baixa não pode ter valor/empresa/contraparte alterados.
- **Dinheiro em centavos:** parcelamento distribui o resto na última parcela (ex.: R$ 100,00 em 3 =
  33,33 + 33,33 + 33,34), validado em centavos como já é feito em `PdvVendaService`.
- **Atualizar `PLAN-SEGURANCA.md`** ao fim de cada fase (checks e registro), conforme combinado.

---

## 8. Fases

Cada fase fecha pelo **portão de etapa**: revisar → testar (nos containers, `docker exec -e`) →
commitar → atualizar `PROGRESS.md` e `PLAN-SEGURANCA.md` → só então a próxima. Nada é marcado como
pronto sem teste executado. Toda fase com tela fecha com conferência visual no Firefox, feita pelo
usuário.

| Fase | Entrega | Depende de |
|---|---|---|
| **0 — Decisões** | Fechar D1–D18 (§9). Sem isso não há migration. | — |
| **1 — Fundação** | Área `financeiro`, mecanismo de feature por plano (D13), `contas_financeiras`, `categorias_financeiras` + seed padrão por empresa + backfill, `centros_custo`. Testes de isolamento entre empresas. Sem tela de lançamento ainda. | Fase 0 |
| **2 — Livro e títulos manuais** (antes: fixar o fuso, §4.2) | `titulos`, `baixas`, `movimentacoes`; criar título (à vista, parcelado), baixar, baixar parcial, estornar, cancelar; telas de Contas a Pagar e a Receber; extrato da conta. | Fase 1 |
| **3 — Caixa operacional** | `caixa_sessoes`, abertura, sangria, suprimento, fechamento cego, tela de conferência do gerente, divergência. Ligação PDV → movimentação (dinheiro/PIX/débito). Config "exigir caixa aberto" **desligada por padrão** (D6). | Fase 2 + D1, D15, D16 |
| **4 — Compras → Contas a pagar** | Ampliar `LeitorXmlNfe`/DTO para ler `<cobr><dup>`, guardar duplicatas, `lancar()` cria os títulos; sem duplicata → 1 título à vista; cancelamento coerente. Testar com o XML real (Roma Aviamentos, 313 itens). | Fase 2 + D14 |
| **5 — Vendas a prazo e inadimplência** | Forma a prazo/fiado, título a receber do cliente, cancelamento de venda estorna, aviso ao vender para cliente inadimplente (avisa, não trava). | Fase 2 + D2 |
| **6 — Fluxo de caixa** | Realizado (movimentações) × projetado (títulos abertos), visão diária/semanal/mensal, saldo por conta. | Fases 2–5 |
| **7 — Recorrências e cartão** | Recorrências (scheduler, por empresa, §4.3); crédito como recebível da operadora. | Fase 2 + D5 |
| **8 — Régua de cobrança (e-mail)** | Regras antes/depois do vencimento, fila, descarte/limite, opt-out, log de envios. **Só e-mail**; antes, validar envio real (hoje `MAIL_MAILER=log`). | Fase 5 |
| **9 — DRE e indicadores** | DRE por competência (precisa de D7 para CMV), análise de inadimplência, PMR/PMP; PME por último. | Fases 5–7 + D7 |
| **10 — C1: conciliação por OFX/CSV** *(opcional)* | Importar extrato, casar com baixas, regras ("tarifa bancária"), marcar conciliado. | Fase 6 |
| **Futuro — C2** | Open Finance, PIX dinâmico, boleto registrado, baixa por webhook. | Gatilho: cliente real + PSP escolhido (D11) |

**Recomendação de corte para a primeira entrega utilizável:** Fases 1 a 4 e 6. Dá caixa, pagar,
receber e fluxo de caixa, que é o que a PME percebe no dia seguinte. DRE e régua vêm depois.

---

## 9. Decisões abertas

Cada uma tem recomendação; **nenhuma é aplicada sem confirmação** (inclusive o *como*).

| # | Decisão | Recomendação |
|---|---|---|
| **D1** | Ligar o caixa ao PDV exige coluna `caixa_sessao_id` em `venda_pagamentos` (ou em `pdv_vendas`). É alterar tabela existente. | Aprovar a coluna **nullable**; vendas antigas ficam sem sessão. |
| **D2** | Venda a prazo/fiado: adicionar forma nova ao PDV e à venda? Envolve cliente identificado e limite. | Sim, na Fase 5, só com cliente identificado; limite de crédito vira **aviso**, não bloqueio. |
| **D3** | Venda à vista gera só `movimentacao` (sem título) ou sempre título + baixa? | Só `movimentacao`. Título para tudo dobra os registros do PDV sem ganho para PME. |
| **D4** | "Filial/unidade" = centro de custo dentro de **uma** empresa, e consolidação entre CNPJs fica fora? | Sim. Grupo econômico é outra feature (§10). |
| **D5** | Cartão de crédito como recebível: entra na Fase 7 ou antes? Taxa e prazo por empresa. | Fase 7. Antes disso crédito cai direto como entrada na conta padrão da forma. |
| **D6** | Exigir caixa aberto para vender? | Configuração por empresa, **desligada por padrão** (quem migra de outro sistema precisa de liberdade — princípio "avisar, não travar"). Ligada = PDV pede abertura. |
| **D7** | Gravar o **custo do item no momento da venda** (`venda_itens.custo_unitario`) para CMV fiel. | Sim, mas é decisão de dados: aprovar antes da Fase 9; vendas antigas ficam sem CMV (marcadas como "sem custo"). |
| **D8** | Saldo inicial das contas: informado manualmente na implantação. | Sim, com data; nada de importar histórico bancário. |
| **D9** | Quem concilia a divergência do caixa: só `admin`? | Sim. Divergência abaixo de um limite configurável é "aceita com justificativa". |
| **D10** | Régua: canal e limites (e-mail apenas, quantos envios por título). | E-mail apenas, máx. 1 por regra por título, com opt-out por cliente. `clientes.email` é opcional: cliente sem e-mail não recebe régua e a tela deve mostrar isso. |
| **D11** | C2: PSP único da plataforma (subcontas) ou contrato por empresa? | Adiar; decisão comercial antes de qualquer código. |
| **D12** | Competência de venda = data de finalização; de compra = data de emissão da nota. | Sim, editável no título manual. |
| **D13** | Mecanismo de feature por plano (hoje inexistente). | `RequireFeature` + features em `/me`; limites só avisam. |
| **D14** | Guardar as duplicatas do XML da compra: tabela `nota_entrada_duplicatas` ou jsonb em `notas_entrada`. | Tabela; permite ajustar vencimento na conferência antes de lançar. |
| **D15** | Onde fica o gancho financeiro, já que há dois caminhos de finalizar e dois de cancelar. | Um `FinanceiroDaVendaService` chamado pelos quatro, na mesma transação. |
| **D16** | Qual sessão de caixa recebe a venda. | A aberta do caixa do operador; sem sessão e D6 desligada → venda segue sem sessão, com aviso. |
| **D17** | Fuso horário do negócio (~~hoje UTC~~ **feito em 20/10/2026**: `APP_TIMEZONE=America/Sao_Paulo` e sessão do Postgres no mesmo fuso). | `America/Sao_Paulo` fixo no v1; por empresa só se houver cliente fora dele. |
| **D18** | Devolução/troca e cancelamento parcial de venda. | Fora do v1: cancela-se a venda inteira (§10). |

---

## 10. Fora de escopo (registrado)

- Open Finance, PIX dinâmico, boleto registrado, baixa por webhook (C2).
- WhatsApp na régua (canal futuro da mesma régua).
- Consolidação de vários CNPJs de um grupo.
- Cálculo/guia de impostos (DAS, DARF) — entra como título a pagar **manual**.
- Emissão de boleto/cobrança pelo próprio sistema.
- NFS-e e comissão de vendedores.
- Devolução/troca e cancelamento parcial de venda (D18).
- Contabilidade formal (balanço, partida dobrada). A DRE aqui é gerencial.

---

## 11. Riscos e armadilhas já conhecidos

1. **Jobs sem `CompanyScope`** (§4.3): o maior risco de vazamento do módulo.
2. **Dinheiro duplicado:** venda à vista registrada no PDV *e* digitada em Contas a Receber. Evitado
   por D3 e por título com `origem_tipo/origem_id` único.
3. **Fechamento cego vazando o esperado** por resposta de API ou cache de tela (§7).
4. **Cancelamento fiscal x financeiro** (§6): amarrar ao cancelamento da venda, não ao pedido à SEFAZ.
5. **Backfill de empresas existentes:** esquecer de semear plano de contas deixa a tela vazia e as
   categorias obrigatórias dando erro.
6. **E-mail nunca testado de verdade** (`MAIL_MAILER=log`): a Fase 8 começa validando o envio.
7. **Config do `gestaofacil-api` não versionada** (memória): conferir `config/` e o cache congelado
   antes de culpar o código quando um agendamento novo não disparar.
8. **Dois caminhos de finalizar e de cancelar venda** (§3): ligar só o PDV deixa as vendas da tela Vendas fora do caixa. Os testes cobrem os quatro.
9. **UTC** (§4.2): fechamento e vencimento errados à noite.
10. **Teste de ponta a ponta:** o E2E (`gestaofacil-e2e`) usa overlay de banco e guarda de NFC-e;
   cenários de caixa devem seguir o mesmo padrão.

---

## 12. Registro de execução

| Fase | Estado | Data | Evidência |
|---|---|---|---|
| 0 — Decisões | ⏳ aguardando | — | — |
| 1 a 10 | ⏳ não iniciadas | — | — |
