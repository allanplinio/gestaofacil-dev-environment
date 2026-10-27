# PLAN-IMPOSTOS.md — Impostos por item (ICMS, IPI, PIS/COFINS)

**Aberto em 06/10/2026.** Plano para tirar a tributação do chute e colocá-la no cadastro, com
ajuste por item na emissão.

**Documentos relacionados:** [`PROGRESS.md`](./PROGRESS.md) (registro de defeitos — fecha D-02,
D-03 e D-21) · [`PLAN-API.md`](./PLAN-API.md) · [`PLAN-UI.md`](./PLAN-UI.md) ·
[`gestaofacil-e2e/docs/CASOS-DE-TESTE-E2E.md`](../../gestaofacil-e2e/docs/CASOS-DE-TESTE-E2E.md)

---

## Princípio que guia tudo

> O sistema é multiempresa, com segmentos diferentes e configurações diferentes. **Nenhum valor
> fiscal pode ser inventado pelo código.** O que vai no XML é o que está na tela; o que não estiver
> configurado impede a emissão, com mensagem dizendo onde configurar.

Decidido em 06/10/2026. É o princípio que transforma "imposto errado em nota válida" (o defeito
que não falha) em "erro de configuração visível" (o defeito que falha alto).

**Corolário:** a decisão de alterar é do usuário. Nenhum campo é travado por perfil — num sistema
multiempresa, amarrar quem pode mudar o quê cria mais problema do que resolve. O sistema mostra,
avisa e registra; quem decide é quem emite.

---

## Decisões tomadas

| # | Decisão | Motivo |
|---|---|---|
| 1 | Alíquota de ICMS mora no **produto** | A alíquota é dirigida pelo produto (essencialidade/NCM), não pela operação |
| 2 | `pCredSN` mora no **produto** | Confirmado: varia por produto |
| 3 | A **natureza** guarda CST/CSOSN, não alíquota | A natureza responde "é tributado e como"; a alíquota responde "quanto" |
| 4 | A **empresa** guarda valores usuais só como **auxílio de cadastro** | Pré-preenche o produto novo e é gravado nele. A emissão **nunca** lê o valor da empresa |
| 5 | Ajuste **por item**, na emissão | Nota com arroz (7%) e refrigerante (18%) não cabe num campo por nota |
| 6 | Ajuste vale **só para aquela nota** | Não reescreve o catálogo. Mesmo comportamento que o destinatário já tem na nota avulsa |
| 7 | Empresa nova **configura naturezas** antes de emitir | Já era assim; reforçado pelo princípio |
| 8 | IPI entra no escopo | A `sped-nfe` já suporta; falta só o `nfe-api` expor |
| 9 | Os impostos são **editáveis no pedido**, não só na emissão | O fluxo real é criar o pedido e emitir a NF na mesma hora, ou poucas horas depois. "Emitir NF direto" é a exceção. O usuário monta o pedido já com a tributação que precisa |
| 10 | O item da venda guarda a tributação **sempre**, mexida ou não | É registro, não configuração: olhando um pedido de seis meses atrás tem de dar para saber como ele foi feito. O sistema já faz isso com preço (`preco_unitario`, `desconto`, `subtotal` são gravados no item, não lidos do produto). E pedido que nunca virou NF não deixaria rastro nenhum da tributação |
| 11 | Divergência entre o gravado e o cadastro **avisa, não recalcula** | Se a alíquota do produto mudar entre o pedido e a emissão, o item mostra "cadastro mudou: 18% → 12%" com um clique para adotar. Quem decide é o usuário |
| 12 | Nulo no item significa **"o produto não tinha configuração naquele momento"** | Único significado possível depois da decisão nº 10. Não bloqueia criar o pedido — documento comercial não para por falta de dado fiscal —, mas a emissão recusa enquanto estiver vazio |

### O que foi considerado e descartado

- **Alíquota na natureza.** Mesma natureza "venda" vende arroz a 7% e refrigerante a 18%; e o
  mesmo produto sai a 18% dentro do estado e 12% para fora. A natureza não conhece nem o produto
  nem o destino. Seria uma terceira camada que quase sempre duplica ou contradiz a do produto.
- **Herança empresa → produto na emissão.** Produto que alguém esqueceu de configurar sairia com
  a alíquota de outro segmento, em silêncio. A herança acontece no **cadastro** (visível e
  editável), não na emissão (invisível).
- **Aba só de leitura no pedido.** Foi a primeira proposta, pelo risco de o imposto congelado no
  pedido ficar velho. Descartada: o fluxo real emite a NF na mesma hora, e o usuário precisa
  montar o pedido já com a tributação dele. O risco residual virou a decisão nº 11 — avisar da
  divergência em vez de recalcular por conta própria.
- **Gravar no item só o que foi ajustado** (nulo = "ninguém mexeu, resolve do produto na emissão).
  Descartada pela decisão nº 10: sem o registro completo, o pedido não conta a própria história e
  o imposto só existiria na NF. A distinção "o usuário digitou" × "veio do cadastro" também não
  tinha consequência nenhuma no comportamento — como nunca se recalcula sozinho (nº 11), o aviso
  de divergência funciona igual nos dois casos.
- **Travar CST/CSOSN por perfil.** Ver o corolário acima.

---

## O que o código mostra hoje (revisão de 06/10/2026)

### Os chutes (D-21)

Oito valores fiscais que a emissão inventa quando o cadastro está incompleto:

| Arquivo | Linha | Inventa | Consequência |
|---|---|---|---|
| `RegrasFiscais` | 33 | UF do emitente = `SP` | decide CFOP 5xxx × 6xxx |
| `RegrasFiscais` | 56-57 | CFOP `5102` / `6102` | o código fiscal mais consequente do item |
| `RegrasFiscais` | 82 | CST `00` (tributada integralmente) | caminho do D-03 |
| `RegrasFiscais` | 94-95 | PIS/COFINS CST `49` | "outras operações" para quem pode estar no não cumulativo |
| `RegrasFiscais` | 101 | forma de pagamento = dinheiro | pagamento desconhecido vira espécie |
| `NfeEmissaoService` | 828 | unidade = `UN` | baixo risco, mas é chute |
| `NfeEmissaoService` | 882 | UF do cliente = `SP` | mesmo erro do emitente, mais rejeição 274 |
| `NfeEmissaoService` | 883 | CEP `00000000` | falha alto, menos grave |

**E o frontend repete dois deles:** `notaFiscal.ts:283` (`cfopPrevisto`) tem o mesmo
`?? '5102'` / `?? '6102'`. A tela mostra um CFOP que pode não ser o que sairá.

Os de NCM (`:826`) e código do município (`:880`) ficaram inalcançáveis depois da validação de
06/10 e saem junto, como código morto.

### O caminho do ICMS hoje

```php
if ($csosn)   { $icms['csosn'] = $csosn; }                       // Simples
elseif ($cst) { $icms['cst']   = $cst;   }                       // regime normal — SEM alíquota
else          { $icms['cst']='00'; $icms['aliquota'] = $produto->icms_aliquota ?? 0; }
```

- O seeder do `nfe-api` grava `icms_cst_padrao = '00'` para regime normal → cai no `elseif` →
  manda `cst: "00"` **sem alíquota** → o serviço recusa com 422 (`required_if`). **É o caminho
  comum de uma empresa CRT 2/3: não emite.**
- O `else` (natureza sem CSOSN e sem CST, possível depois de editar na tela) manda alíquota 0 →
  **nota autorizada com ICMS zero**. Mais raro e mais perigoso.
- `$produto->icms_aliquota` **nunca existiu** como coluna.

### O que o serviço já aceita

| Imposto | `StoreNfeRequest` | `NfeXmlBuilder` | Falta |
|---|---|---|---|
| ICMS | `icms.aliquota` (required_if CST 00), `icms.aliquota_credito` (required_if CSOSN 101) | `tagICMS` / `tagICMSSN` com `pICMS`, `vICMS`, `pCredSN`, `vCredICMSSN` | só a `gestaofacil-api` mandar |
| PIS/COFINS | `pis.aliquota`, `cofins.aliquota` | calcula `vBC`/`pPIS`/`vPIS`, e omite nos CST não tributados (04–09) | só a `gestaofacil-api` mandar |
| **IPI** | — | — | **expor**: regras de request + `ipi()` chamando `tagIPI` |

A `sped-nfe` em uso tem `TraitTagDetIPI` e acumula `stdTot->vIPI`, somando no `vNF`
(`Make.php:891-910`). O total vem de graça.

---

## Modelo de dados

### `produtos` (gestaofacil-api)

| Coluna | Tipo | Obrigatória quando |
|---|---|---|
| `icms_aliquota` | decimal(5,2) nullable | natureza usa CST `00` |
| `icms_credito_sn_percentual` | decimal(5,2) nullable | natureza usa CSOSN `101` |
| `pis_aliquota` | decimal(5,2) nullable | CST de PIS tributado (fora de 04–09) |
| `cofins_aliquota` | decimal(5,2) nullable | CST de COFINS tributado |
| `ipi_cst` | string(2) nullable | nunca; sem CST não sai grupo IPI |
| `ipi_aliquota` | decimal(5,2) nullable | CST de IPI tributado (00, 49, 50, 99) |
| `ipi_enquadramento` | string(3) nullable | com grupo IPI (`cEnq`; `999` = tributação normal) |

**Obrigatoriedade é condicional**, e isso importa: empresa do Simples em CSOSN 102 com PIS/COFINS
49 não precisa preencher **nada**. A exigência bate só em quem usa CST 00, CSOSN 101 ou IPI.

### `venda_itens` — a tributação daquele pedido

As mesmas 7 colunas, **preenchidas sempre**: ao incluir o item, copia-se do cadastro do produto;
ao editar na aba, grava-se o que o usuário pôs. Vale para o pedido, para a venda da frente de
loja e para a nota avulsa.

É registro histórico, igual a `preco_unitario` e `desconto`, que já são gravados no item e nunca
relidos do produto. Sem isso, pedido cancelado ou venda sem nota não deixam rastro da tributação.

**Nulo tem um significado só:** o produto não tinha aquela configuração quando o item entrou.
Não impede criar o pedido — documento comercial não para por falta de dado fiscal —, mas a
emissão recusa enquanto estiver vazio, oferecendo **preencher a partir do cadastro** se o produto
já tiver sido configurado desde então.

### `configuracoes_fiscais` (auxílio de cadastro)

As mesmas colunas, com sufixo `_padrao`. **Lidas só pelo formulário de produto**, nunca pela
emissão. Um teste garante isso.

---

## Fases

### Fase 1 — Varrer os chutes (D-21) ✅ (06/10/2026)

- [x] `RegrasFiscais::ufEmitente()` sem fallback `SP`
- [x] `RegrasFiscais::cfop()` sem `?? '5102'/'6102'` — recusa nomeando a natureza
- [x] `RegrasFiscais::icms()` sem o `else` que inventava CST 00
- [x] `RegrasFiscais::pisCofins()` sem `?? '49'`, um erro por tributo
- [x] `RegrasFiscais::formaPagamento()` sem `?? '01'`
- [x] `construirDestinatario()` sem `?? 'SP'`, `?? '00000000'` e `?? '0000000'`
- [x] `construirItens()` sem `?? 'UN'` e sem o NCM morto
- [x] `notaFiscal.ts` (`cfopPrevisto`) sem os mesmos fallbacks — mostra "—"
- [x] `validarDadosDaNota()` ganhou unidade, UF e CEP do cliente
- [x] Nova `ConfiguracaoFiscalIncompletaException`, com uma fábrica por caso

**Duas coisas apareceram no caminho:**

1. **O tradutor de erros engolia a mensagem.** `ErrorTranslationService::translateError()` casava
   "ICMS" e devolvia "Configuração de ICMS obrigatória", jogando fora justamente a parte que diz
   o que falta e onde configurar. A exceção nova passa **sem tradução**; na nota avulsa vai como
   erro de campo em `natureza_slug`, para o alerta da tela levar a quem configura.
2. **As fixtures escondiam a falta.** Nem `Pest.php` nem `NfeFase0CorrecoesTest` preenchiam
   `pis_cst_padrao`/`cofins_cst_padrao` na natureza — o fallback `49` fazia os testes passarem
   com natureza incompleta. Mesmo padrão do `codigo_municipio` na `ClienteFactory`, encontrado
   na leva anterior. Virou o helper `naturezaCompleta()`, usado pelos dois.

**Testes:** `tests/Feature/Nfe/NaoInventaDadoFiscalTest.php` (11), um por chute, todos conferindo
que **nada foi enviado** (`avulsaNaoEnviou()`), mais um caminho feliz provando que nota com
cadastro completo sai igual a antes. Suíte **566 passando**, 7 da baseline.

**Commit:** `fix: emissão não inventa mais dado fiscal quando o cadastro está incompleto`

### Fases 2 e 3 — Campos no cadastro, resolução e recusa ✅ (06/10/2026)

Fechadas num commit só: coluna que ninguém lê não é entrega.

- [x] Migração: 7 colunas em `produtos` e as `_padrao` de auxílio de cadastro
- [x] `Produto`, `Empresa` (fillable, casts, `tributacaoPadrao()`)
- [x] Validação no cadastro de produto (0–100) e na configuração fiscal
- [x] `RegrasFiscais::icms()` lê alíquota (CST 00) e crédito do Simples (CSOSN 101) do produto
- [x] `pisCofins()` manda alíquota quando o CST é tributado
- [x] Novo `ipi()`, só quando o produto tem CST de IPI
- [x] Recusa condicional, nomeando o produto
- [x] **Teste de que a emissão não lê o valor da empresa** (decisão nº 4 virando trava)

**As preferências não foram para `configuracoes_fiscais`.** Existe teste garantindo a lista de
colunas daquela tabela — "configuracoes_fiscais so pode ter a credencial da integracao" — porque
ela guarda só a credencial da integração e o dado fiscal pertence ao Serviço de NF-e. A trava
pegou a adição distraída; as preferências foram para `empresas`, que é onde dado da empresa mora.
O motivo está escrito na migração, para ninguém desfazer.

**Obrigatoriedade condicional, como previsto:** CSOSN 102 com PIS/COFINS 49 — o varejo no Simples
— não exige **nenhuma** alíquota cadastrada. A exigência bate em CST 00, CSOSN 101, CST de
PIS/COFINS tributado e IPI tributado.

**Testes:** `tests/Feature/Nfe/TributacaoDoProdutoTest.php` (16), cobrindo a matriz CST/CSOSN ×
configurado/não configurado, IPI tributado/isento/ausente e o cadastro. Suíte **582 passando**,
7 da baseline.

**Commit:** `feat: tributação por produto, com a emissão recusando o que falta`

### Fase 4 — IPI no `nfe-api` ✅ (06/10/2026)

- [x] `StoreNfeRequest`: `itens.*.ipi` (`cst`, `aliquota`, `enquadramento`), alíquota obrigatória
      nos CST tributados (conferida no `withValidator`: `required_if` não cobre lista)
- [x] `NfeXmlBuilder::ipi()` chamando `tagIPI`
- [x] `CST_IPI_TRIBUTADO` e `CST_IPI_SUPORTADOS` — a lista de tributados é a mesma que a
      `sped-nfe` usa internamente, para os dois não divergirem
- [x] `vIPI` no total e no `vNF`, conferido no XSD

**Mais barato do que a estimativa inicial:** a `sped-nfe` já tinha `TraitTagDetIPI` e já
acumulava `stdTot->vIPI` no `vNF`. O que parecia projeto foi um método e um bloco de regras.

**Testes:** `tests/Feature/Nfe/IpiPorItemTest.php` (7), assinando e validando contra o **XSD
oficial** — a mesma checagem que o `RealSefazGateway` faz antes de enviar. Suíte do `nfe-api`:
135 passando contra 127 da baseline, sem falha nova (aquela suíte tem 213 falhas de ambiente).

**Commit:** `feat: grupo IPI por item na emissão`

### Fase 5 — Aba de impostos no item ✅ (06/10/2026)

**Um componente, três telas** — era o requisito do reaproveitamento.

- [x] `components/nota/ImpostosDoItem.tsx`: ICMS (CSOSN/CST da natureza + alíquota + crédito SN),
      PIS/COFINS (CST + alíquotas) e IPI (CST + alíquota + enquadramento). Tudo editável
- [x] `ItemNota` ganhou `tributacao` e `tributacaoDoCadastro`; `itemDoProduto()` pré-preenche
- [x] `ItensNota`: bloco recolhido por item no computador, dentro do "Detalhes do item" no celular
- [x] `EmitirNfe`: ganhou a seção de itens, **reaproveitando o mesmo componente**
- [x] `VendaDetalhe`: a mesma aba, editável com o pedido aberto
- [x] `validarNota()` valida os campos novos, com as mesmas regras condicionais do backend
- [x] Marcador de divergência com **usar a atual** (decisão nº 11)
- [x] Percentual que distingue **vazio** ("não configurado") de **zero** (alíquota zero, válida) —
      o `PercentInput` existente não faz essa distinção, então a aba tem o seu

**Apareceu no caminho:** editar imposto no pedido exigia endpoint que não existia. Entrou o
`PATCH /vendas/{venda}/itens/{item}`, só com o pedido aberto — fechado, o ajuste é na emissão.

**Testes:** 3 acrescentados ao `AjusteDeImpostoPorItemTest` (alterar com pedido aberto, recusa com
pedido finalizado, item de outra venda → 404). Suíte **595 passando**, 7 da baseline.
`type-check` e `build` limpos.

> **Conferência visual pendente** — 360, 390, 768 e 1280 px, no Firefox, como manda o
> `CLAUDE.md` do frontend. É manual e não foi feita.

**Commit:** `feat: aba de impostos por item, compartilhada entre pedido e nota`

**Completado em 06/10/2026 (2 furos que ficaram da primeira passada):**
- A tela de **novo pedido** (`/vendas/nova`) não mostrava a aba — o dado era gravado, mas o
  usuário só o via depois de salvar. Agora a aba é **editável** ali: `useCarrinho` carrega a
  tributação do produto no item e `POST /vendas/{id}/itens` passou a aceitar as alíquotas.
- A tela de **emissão por venda** (`EmitirNfe`) não pré-validava (`invalido={() => false}`) —
  o usuário só via o erro no 422 do backend. Agora valida antes, com `problemasDeImposto`,
  extraído do `validarNota` e compartilhado entre as duas telas; o alerta lista o que falta,
  por item, e marca os campos.

### Fase 6 — Tributação no item e ajuste por nota ✅ (06/10/2026)

- [x] Migração: as 7 colunas em `venda_itens`
- [x] Novo `Services\Nfe\TributacaoDoItem`: nasce do produto (`deProduto`) ou do que está
      gravado com o ajuste por cima (`deRegistro`), e devolve o que gravar (`paraItem`)
- [x] Cópia ao criar o item: `VendaService::adicionarItem`, `PdvVendaService::checkout` e o
      segundo ponto do `finalizarComNfce`
- [x] `RegrasFiscais` lê da `TributacaoDoItem`, não mais do produto
- [x] `POST /vendas/{venda}/emitir-nfe` aceita `itens[]` com os impostos ajustados
- [x] `FormularioNotaAvulsa`: o item nasce do produto com o ajuste da tela por cima
- [x] Ajuste **não** reescreve o cadastro nem o item — teste garantindo

**Testes:** `tests/Feature/Nfe/AjusteDeImpostoPorItemTest.php` (10), incluindo o registro
histórico (alterar o produto depois **não** muda o item), o ajuste valendo só para a nota e o
item vazio sendo barrado mesmo com o produto já configurado. Suíte **592 passando**, 7 da
baseline.

**Commit:** `feat: tributação gravada no item da venda e ajustável por nota`

## Testes — o que não pode faltar

| Camada | O quê |
|---|---|
| Unidade | resolução (override → produto → recusa); cálculo de `vICMS`, `vPIS`, `vCOFINS`, `vIPI` |
| Feature | matriz CRT × CST/CSOSN × configurado/não configurado, conferindo **o payload enviado** |
| Feature | a emissão **não** lê valor da empresa (decisão nº 4) |
| Feature | ajuste por item não altera o cadastro do produto (decisão nº 6) |
| `nfe-api` | XML com IPI validado contra o XSD; `vIPI` somado no `vNF` |
| E2E | `CT-E2E-061` e `CT-E2E-062` viram regressão; casos novos para a aba |

Todo teste de payload confere **o corpo da requisição**, não só o status: foi assim que D-01,
D-04 e D-05 apareceram.

---

## Riscos

| Risco | Mitigação |
|---|---|
| Empresa já em produção para de emitir por falta de configuração | A Fase 1 recusa com mensagem clara e link; avisar antes de subir |
| Operação interestadual: o produto tem uma alíquota só | O ajuste por item (Fase 6) é a saída; alíquota por UF fica fora do escopo |
| Imposto gravado no pedido fica velho se o cadastro mudar antes de emitir | Janela curta no fluxo real; o marcador de divergência cobre o caso sem recalcular escondido |
| Produto sem configuração na data do pedido deixa o item vazio | A emissão barra e oferece preencher do cadastro; o pedido em si não trava (decisão nº 12) |
| `vNF` com IPI muda o total da nota | Fase 4 testa o total contra o XSD antes de qualquer emissão real |
| Aba de impostos deixa a tela de nota pesada | Fica recolhida por item; o caminho feliz não encosta nela |
| Mexer no `nfe-api` afeta outros clientes | IPI é aditivo (`itens.*.ipi` opcional); nada muda para quem não manda |

## Fora de escopo

- **Alíquota por UF de destino** (interestadual 7%/12%): resolve-se no ajuste por item.
- **DIFAL** (D-09): projeto próprio.
- **ST / CEST** (D-10): o CEST tem plano próprio; a ST entra depois do ICMS básico.
- **Seeder de naturezas do `nfe-api`**: parar de preencher CST/CSOSN por CRT é o mais alinhado
  ao princípio, mas afeta todos os clientes do serviço. Decisão pendente.
