# PLAN-GRADE.md — Produtos com variações e atributos abertos — detalhamento da F1

**Status:** **PLANO — nada implementado.** Escrito em 2026-10-22; **reescrito em 2026-10-27** para
atributos abertos (estilo WooCommerce) e com os riscos de emissão de NF-e reavaliados contra o
código de `gestaofacil-api` e `nfe-api` nesta data. Em 27/10 você escolheu incluir o **snapshot fiscal no item como fase própria antes da grade** (Fase 0b). As decisões da §8 marcadas como *aberta* ainda
precisam da sua resposta; as marcadas como *adotada* entram no desenho como recomendação e podem
ser revogadas antes da Fase 1 (nada de campo novo, tabela nova ou duplicação de dado além do que
está descrito aqui).

**Documentos relacionados:** [`PLAN-PRE-BETA.md`](./PLAN-PRE-BETA.md) §7 (F1, que este plano
detalha) · [`PLAN-LANCAMENTO.md`](./PLAN-LANCAMENTO.md) · [`PLAN-IMPORTACAO-XML.md`](./PLAN-IMPORTACAO-XML.md) ·
[`PLAN-IMPOSTOS.md`](./PLAN-IMPOSTOS.md) · [`PLAN-SEGURANCA.md`](./PLAN-SEGURANCA.md) ·
[`gestaofacil-e2e/PLAN-E2E.md`](../../gestaofacil-e2e/PLAN-E2E.md) · [`DATA-MODEL.md`](./DATA-MODEL.md)

Cada fase termina com **revisar → testar → commitar → PROGRESS** e com a atualização do
`PLAN-SEGURANCA.md`, nessa ordem, antes de a seguinte começar.

---

## 1. Resumo

**Problema.** A loja vende o mesmo modelo em várias cores e tamanhos (e, em outros segmentos,
celular em memória e cor, computador em processador e RAM). Hoje o sistema só tem "produto"
plano: seria preciso cadastrar "Camiseta Azul M", "Camiseta Azul G"… como produtos soltos, sem
saber o total do modelo, sem cadastro em lote, sem escolher a variação no caixa.

**Recomendação.** **Variação = produto (linha em `produtos`) ligada a um *modelo* (tabela nova
`produto_modelos`)**, descrita por **atributos abertos**: o usuário cria qualquer atributo
("Cor", "Tamanho", "Memória", "Marca", "Garantia") e qualquer valor, com autocompletar sobre o que
a empresa já usou. Em cada modelo, cada atributo é **eixo de variação** (gera uma variação por
valor, até 3 eixos) ou **informativo** (guarda valores para filtro e exibição, sem gerar
variação). O modelo guarda o que é comum (nome-base, impostos, preço padrão); cada variação guarda
o que é próprio (código de barras, SKU, estoque, preço se for diferente).

**Por quê.** A NF-e não conhece "variação": só item (`det`), com `cProd`, `cEAN`, `NCM`, `CEST` e
tributação por item. Estoque, venda, NF-e, NFC-e, nota de entrada, de-para de fornecedor,
movimentação e CC-e/cancelamento trabalham com `produto_id`. Se a variação *é* um produto,
**nenhum desses fluxos precisa ser reescrito**; o que muda é o cadastro, a busca no caixa, a
importação de XML e **dois pontos pequenos da emissão** (§6.1). A alternativa de tabela própria de
variações com estoque próprio obriga a tocar em todos eles (§4).

**Mudança em relação à versão de 22/10:** `cor` e `tamanho` fixos (G2) deram lugar a atributos
abertos. Isso não muda a solução A; muda como a variação é descrita (§5.1) e acrescenta riscos que
só existem com texto livre na descrição e no SKU da nota (§6.1, riscos E1–E4).

**Tamanho:** G. Cabe na janela Dez/2026–Jan/2027 do PLAN-PRE-BETA somente se o escopo da §3
(v1 da grade) for respeitado; o que ficou fora está na §3.2.

---

## 2. O que existe hoje (conferido no código)

| Peça | Estado hoje | Onde |
|---|---|---|
| Produto | linha única; `sku` único por empresa (nullable, até 100 caracteres), `codigo_barras` **não** único (texto até 50), `estoque_atual` decimal(…,4) no próprio produto | `app/Models/Produto.php`, migration `…000007` |
| Campos fiscais no produto | `ncm`, `cest`, `unidade`, `origem_fabricacao`, `tem_substituicao_tributaria`, `origem_icms`, `icms_aliquota`, `icms_credito_sn_percentual`, `pis_aliquota`, `cofins_aliquota`, `ipi_cst`, `ipi_aliquota`, `ipi_enquadramento` (`$fillable`); a lista final dos herdáveis se confere na Fase 1 contra `TributacaoDoItem::CAMPOS` | `Produto.php:18-40` |
| Estoque | `EstoqueService`: entrada/ajuste/saída manuais gravam `estoque_movimentacoes`; venda baixa direto em `estoque_atual`; entrada de nota em lote | `app/Services/EstoqueService.php` |
| Itens de venda | `venda_itens` e `pdv_venda_itens` apontam `produto_id` (FK `restrict`). **Gravadas no item de venda desde 06/10 (PLAN-IMPOSTOS, decisão nº 10):** as 7 alíquotas de `TributacaoDoItem::CAMPOS` (ICMS, crédito SN, PIS, COFINS, IPI) — só em `venda_itens`; o `pdv_venda_itens` não recebeu a migration (como o PDV chega à nota: a conferir). **Não gravados, relidos do produto a cada emissão ou reenvio:** nome (`xProd`), SKU (`cProd`), GTIN, NCM, CEST, unidade, origem, flag de ST e os dados de que o CFOP depende | `PdvVendaService`, `VendaService`, `2026_10_06_000003_add_tributacao_a_venda_itens.php`, `NfeEmissaoService.php:1030-1066` |
| NF-e/NFC-e (venda) | `codigo` = `sku` ou `PROD-{id}` cortado em 60; `descricao` = `produtos.nome` cortado em 120 **pelo fim**; `gtin` = `codigo_barras` só dígitos, aceito se tiver 8/12/13/14 | `NfeEmissaoService.php:1057-1066`, `RegrasFiscais.php:357,372`, `LimitesDoLayout.php:41` |
| NF-e (nota avulsa) | `descricao` vem **do formulário** (o usuário digita/ajusta) e é cortada em 120; `codigo` e `gtin` saem do produto como acima; NCM do item vem do formulário | `FormularioNotaAvulsa.php:157-171` |
| Contrato com `nfe-api` | `itens.*.codigo` string ≤60 · `descricao` string ≤120 · `gtin` `^(\d{8}\|\d{12,14}\|SEM GTIN)$` · sem GTIN o builder escreve `SEM GTIN` em `cEAN` e `cEANTrib` · **não existe `infAdProd`** em `nfe-api/app` | `StoreNfeRequest.php:94-102`, `NfeXmlBuilder.php:234-248` |
| Entrada de XML | `ResolvedorDeProdutos` casa na ordem: de-para por `cProd` → de-para por descrição → EAN → `cProd`=EAN-13 → `cProd`=SKU → criar. Ambíguo não vincula. De-para único por `(empresa, fornecedor, cProd)` | `app/Services/Compras/*` |
| Cadastro/lista/busca (FE) | `ProdutoForm`, `Produtos`, `ProdutoBusca` (até 10 sugestões; Enter com leitor), `MovimentacaoProduto`; tipo `Produto` em `types/index.ts` | `gestaofacil-fe/src` |
| Grade/variação/atributos | **não existe** em código nem em tela. Só planejada em PLAN-PRE-BETA §7 (F1) e PLAN-LANCAMENTO | — |
| Planos/feature flag | coluna `planos.features` (array) existe; **não há `PlanoService::permite()`** — é o F5 | `app/Models/Plano.php` |

Tudo acima é leitura de código; nada foi executado nesta sessão. O que depende de comportamento
real (SEFAZ, XML de confecção) está na §10.

---

## 3. Escopo

### 3.1 Entra na v1 da grade

1. **Atributos abertos com autocompletar:** o usuário cria atributo e valor ao digitar; valor
   existente é reaproveitado (comparação sem acento, caixa ou espaço sobrando); sem tela
   obrigatória de pré-cadastro.
2. Cadastro de **modelo** com até 3 atributos-eixo → gera as variações (produto cartesiano),
   idempotente. Atributos informativos opcionais, sem limite de quantidade além de um teto sensato.
3. Variação herda impostos, unidade e preço do modelo; edição por exceção.
4. Lista de produtos **agrupada** por modelo (total de estoque, faixa de preço, nº de variações).
5. Estoque por variação, com **entrada/ajuste em matriz** (2 eixos = tabela; 3 eixos = lista de
   combinações) e saldo do modelo.
6. **PDV, pedido e nota avulsa:** leitor acha a variação; busca por nome abre a matriz.
7. **Nota fiscal:** `cProd`, `xProd`, `cEAN` por variação; descrição "Modelo - valores dos eixos"
   que **não perde os valores no corte de 120**; SKU gerado que **não colide depois do corte de 60**.
8. **Nota de entrada:** variação casa por de-para/EAN; ação "criar grade" na conferência.
9. Grades prontas (P–GG, 34–46, 33–44, infantil) como atalhos que preenchem o atributo "Tamanho".
10. Tela opcional de manutenção do catálogo: renomear, mesclar duplicatas, apagar valor sem uso.
11. Testes Pest, tipo/regra pura no FE e E2E (fase final).

### 3.2 Fica fora (de propósito)

| Fora | Motivo / onde vai |
|---|---|
| Atributos informativos na NF-e (`infAdProd`) | decidido em 28/10 (G15): fora da nota; o `nfe-api` não tem o campo e seria mudança nos dois serviços |
| Atributo informativo em **produto simples** (sem modelo) | G17, aberta; recomendação: depois da v1 |
| Mais de 3 eixos de variação | o produto cartesiano explode (3 eixos × 6 valores = 216) |
| Relatórios por grade ("peças paradas", curva por modelo) | F9 do PLAN-LANCAMENTO; esta entrega só expõe os campos |
| Etiqueta com atributos | F2; aqui só garantimos que os dados existem |
| Troca de tamanho (devolução + nova venda) | F3; a variação já é produto, então a troca vira movimento entre produtos |
| Gating por plano (`grade` só no Loja) | depende do F5; ver G9 |
| Preencher valores por XML automaticamente (parse de texto livre) | heurística errada vincula errado no meio de centenas de itens; só **sugere** (Fase 6) |

---

## 4. Soluções avaliadas

### A. Variação = produto + modelo + atributos abertos (**recomendada**)
`produto_modelos` + catálogo de atributos/valores + `produtos.modelo_id`.
- **Prós:** estoque, venda, nota e importação continuam em `produto_id`; leitor de código de
  barras e de-para já funcionam por variação; cada variação tem `cProd`/`cEAN` próprios (o que a
  SEFAZ e o fornecedor já esperam); nenhuma FK nova em item de venda; atributos servem a qualquer
  segmento sem mudar a estrutura.
- **Contras:** mais linhas em `produtos` (200 modelos × 5 cores × 6 tamanhos = 6.000 linhas:
  irrelevante para o Postgres, mas a lista precisa agrupar); dados fiscais aparecem em cada
  variação (G3); renomear atributo/valor reescreve o nome das variações; seis tabelas novas.

### B. Tabela `produto_variacoes` com estoque próprio, e item de venda apontando `variacao_id`
- **Prós:** modelo relacional "puro", produto continua sendo um só.
- **Contras:** toca `venda_itens`, `pdv_venda_itens`, `EstoqueService`, `EstoqueDaNota`,
  `PdvVendaService`, `VendaService`, `FormularioNotaAvulsa`, `NfeEmissaoService`,
  `TributacaoDoItem`, `LancamentoNotaService`, `ResolvedorDeProdutos`, de-para, movimentação,
  FE inteiro de carrinho/busca, **e** as migrações de dado de quem já usa. É reescrever os
  caminhos que o PLAN-SEGURANCA e a suíte E2E já cobriram. Risco fiscal alto sem ganho: a NF-e
  não tem conceito de "variação", só de item.

### C. Atributos livres em JSON (sem catálogo, sem tabela de valores)
- **Prós:** quase nenhuma tabela.
- **Contras:** sem autocompletar confiável, "Azul" e "azul" duplicam, filtro em JSON é pior,
  chave de unicidade da variação fica frágil. **Superada por A** (que já traz atributos abertos,
  mas com catálogo normalizado).

### D. Não construir: convenção de nome ("Camiseta Azul M") + criação em lote por CSV
- **Prós:** quase zero código.
- **Contras:** sem saldo do modelo, sem escolha de tamanho no caixa, sem agrupar na lista. É o
  que o concorrente de moda anuncia como "grade" e o PLAN-LANCAMENTO trata como pergunta número 1
  de loja de moda. Descartada, mas é o **plano B de corte** se a data apertar (só Fases 1–2).

### Comparação

| Critério | A (produto + modelo + atributos) | B (tabela de variações) | C (JSON) | D (convenção) |
|---|---|---|---|---|
| Fluxos existentes reescritos | **nenhum** (2 pontos pequenos na emissão) | ~10 serviços + FE | ~3 | nenhum |
| Risco fiscal | baixo, com E1–E4 tratados | alto | médio | nenhum |
| Estoque por variação | sim | sim | sim | sim (sem soma) |
| Saldo do modelo | soma em consulta | soma em consulta | soma em consulta | **não** |
| Atributos abertos | **sim** | sim | sim, frágil | não |
| Importação de XML | casa por variação | reescrever | reescrever | igual a hoje |
| Migração de quem já usa | nenhuma (produto simples segue) | obrigatória | obrigatória | nenhuma |
| Esforço | **G** | GG | G | P |

**Decisão proposta: A.** Mesma do PLAN-PRE-BETA (D7), com um refinamento: o PLAN-PRE-BETA admitia
`produto_pai_id`. Aqui recomendo **tabela `produto_modelos` separada**, porque um "produto pai"
seria uma linha em `produtos` sem estoque e sem preço próprio que aparece em lista, busca, PDV e
relatório e **pode ser vendido por engano**.

---

## 5. Desenho (solução A)

### 5.1 Dados

```
atributos                               (novo — CompanyScope)
  id, empresa_id
  nome               varchar(60)        -- "Cor", "Tamanho", "Memória", "Marca"
  nome_normalizado   varchar(60)        -- minúsculas, sem acento, espaços colapsados
  unique (empresa_id, nome_normalizado)

atributo_valores                        (novo — CompanyScope)
  id, empresa_id, atributo_id
  valor              varchar(60)        -- "Branco", "GG", "128 GB", "12 meses"
  valor_normalizado  varchar(60)
  unique (atributo_id, valor_normalizado)

produto_modelos                         (novo — CompanyScope)
  id, empresa_id
  nome            varchar(200)          -- nome-base: "Camiseta Básica"
  referencia      varchar(60) null      -- código do modelo: "CAM001" (base do SKU)
  unidade         varchar(10)
  preco_venda     decimal(12,2)         -- padrão das variações
  padroes         jsonb                 -- só os campos de Produto::CAMPOS_HERDADOS (§2)
  ativo           boolean
  timestamps
  unique (empresa_id, referencia) quando preenchida

modelo_atributos                        (novo) — quais atributos o modelo usa
  modelo_id, atributo_id
  usado_em_variacao boolean             -- true = eixo (máx. 3 por modelo); false = informativo
  ordem smallint
  PK (modelo_id, atributo_id)

modelo_atributo_valores                 (novo) — valores escolhidos no modelo
  modelo_id, atributo_id, valor_id, ordem
  PK (modelo_id, atributo_id, valor_id)

produtos                                (colunas novas)
  modelo_id        bigint null  FK produto_modelos (restrict)
  chave_variacao   varchar(120) null    -- "atributoId:valorId|atributoId:valorId", ordenado por atributoId
  variacao_rotulo  varchar(120) null    -- "Azul - GG", na ordem dos eixos
  unique (modelo_id, chave_variacao) where modelo_id is not null
  index (empresa_id, modelo_id)

produto_atributo_valores                (novo) — a combinação de cada variação
  produto_id, atributo_id, valor_id
  PK (produto_id, atributo_id)
```

- **Produto simples** continua com `modelo_id = null`: nada muda para quem não usa grade.
- `produtos.nome` da variação guarda `"{modelo.nome} - {variacao_rotulo}"`, mantido pelo sistema
  (G5). Lista, PDV, comprovante, nota de entrada e nota fiscal mostram o nome certo sem lógica
  nova de composição em cada tela.
- `chave_variacao` e `variacao_rotulo` são **derivados** (recalculados pelo `ModeloService` na
  mesma transação em que a combinação muda) e existem por dois motivos que não têm outra solução
  barata: unicidade da combinação no banco (índice único sobre conjunto de pares não se expressa
  em tabela de ligação) e corte seguro do `xProd` (§6.1, E2). Ver G12.
- Valores **informativos** moram só no modelo (`modelo_atributo_valores`); a variação não os copia.
- Estoque, preço, `sku`, `codigo_barras`, `preco_compra` e tributação **ficam em `produtos`**
  (inalterados) — por isso `TributacaoDoItem::deProduto`, `RegrasFiscais` e as validações de
  NCM/CEST da emissão não mudam.
- **Normalização** (`nome_normalizado`/`valor_normalizado`) é feita em PHP (`mb_strtolower`,
  remoção de acento por `Normalizer`/`transliterator`, trim, espaços colapsados), sem extensão
  `unaccent` no Postgres. O texto digitado fica em `nome`/`valor` como o usuário escreveu na
  primeira vez.
- **Limites de tamanho:** valor de atributo-eixo ≤ **25 caracteres** (validação); atributo
  informativo ≤ 60. Motivo na §6.1 (E2).

### 5.2 Regras

1. **Autocompletar:** `GET /atributos?busca=` e `GET /atributos/{id}/valores?busca=` devolvem até
   10 sugestões da própria empresa. Digitar texto sem escolher sugestão cria o registro se o
   normalizado ainda não existe; se existe, reaproveita o existente (e mantém a grafia original).
2. **Criação em matriz** (`ModeloService::criarComVariacoes`): para cada combinação do produto
   cartesiano dos eixos, cria a variação se a `chave_variacao` não existir; devolve criadas e já
   existentes. **Idempotente**: repetir a chamada não duplica nem sobrescreve edição manual.
3. **Adicionar valor de eixo depois** = nova chamada de matriz; só cria o que falta. **Remover
   valor de eixo** não apaga variação (pode ter estoque e histórico): só some da matriz de criação;
   a variação pode ser inativada.
4. **Herança:** na criação a variação recebe uma cópia de `padroes`, unidade e `preco_venda`.
   Editar o modelo (impostos/unidade/preço padrão) **não mexe sozinho** nas variações: a tela
   oferece "aplicar a todas as variações" com contagem e confirmação. Variação com preço ou
   imposto editado à mão continua editável, com aviso "faz parte do modelo X", nunca travada.
5. **Renomear modelo/atributo/valor** recompõe `produtos.nome` e `variacao_rotulo` das variações
   afetadas, na mesma transação, **com confirmação mostrando a contagem**. **Mesclar valores**
   (corrigir duplicata) é recusado se duas variações do mesmo modelo passariam a ter a mesma
   `chave_variacao`; a tela lista os conflitos.
6. **Inativar modelo** inativa as variações; inativar uma variação não afeta o modelo. Excluir
   segue a regra atual (produto com histórico não exclui; o modelo só exclui sem variações).
   Apagar valor de catálogo só se nenhum modelo/variação o usa.
7. **SKU da variação:** `referencia-VALOR1-VALOR2` gerado (G4), em maiúsculas, sem acento nem
   espaço, **com no máximo 60 caracteres** (o `cProd` corta em 60 e dois SKUs que só diferem depois
   da posição 60 sairiam com o mesmo `cProd`: §6.1, E1); colisão recebe sufixo numérico
   **dentro dos 60**. Editável; a validação de SKU manual também recusa o que colidiria após o
   corte de 60 (§6.1, E1).
8. **Limites:** no máximo 3 eixos por modelo e 200 variações por chamada de matriz, com erro
   claro. Atributos informativos: até 10 por modelo.
9. **Multi-tenant:** `Atributo`, `AtributoValor` e `ProdutoModelo` com `CompanyScope`; toda
   validação `exists:` carrega `empresa_id` (padrão do `FormularioNotaAvulsa`); o autocompletar
   nunca devolve registro de outra empresa. `Auditoria` em criação de matriz, "aplicar ao modelo",
   renomeação/mesclagem e inativação em massa.

### 5.2.1 Adicionar, editar e remover variação (o usuário faz os três, a qualquer tempo)

**Adicionar**
- *Valor novo em eixo existente* (mais um tamanho, mais uma cor): `POST /produto-modelos/{id}/variacoes`
  cria só as combinações que faltam. Variação avulsa (uma combinação só) usa o mesmo endpoint.
- *Eixo novo em modelo que já tem variações:* exige informar **qual valor as variações atuais
  recebem** nesse eixo (ex.: todas viram "Preto"); recompõe chave, rótulo e nome de todas na mesma
  transação, com confirmação e contagem. Sem o valor, 422.

**Editar** (a variação continua sendo um produto; `produtos.update` serve, com guardas)
- Livre: preço, SKU, código de barras, preço de compra, impostos, ativo, estoque via movimentação.
- **`nome` não é editável** em variação (é composto pelo sistema, G5): `produtos.update` com `nome`
  numa variação responde 422 e diz onde mudar (renomear o modelo ou o valor).
- **Trocar o valor de um eixo da variação** (era "Azul", é "Marinho"): permitido por
  `PATCH /produto-modelos/{id}/variacoes/{produto}` com os novos valores; recusado se a nova
  combinação já existir no modelo (409 nomeando a variação conflitante). Recompõe chave, rótulo e
  nome; **SKU não muda sozinho** (já pode estar impresso em etiqueta e no de-para do fornecedor);
  o histórico acompanha o `produto_id`, que não muda.
- Editar o **modelo** (nome, referência, unidade, preço padrão, impostos) não toca nas variações;
  "aplicar às variações" propaga com contagem e confirmação (regra 4).
- Tirar um **eixo** de modelo com variações: só se as combinações restantes continuarem únicas
  (senão 409 listando os conflitos); o atributo pode virar informativo.

**Remover**
- *Variação:* `DELETE /produto-modelos/{id}/variacoes/{produto}`. **Sem histórico** (nenhuma venda,
  pedido, movimentação de estoque, nota de entrada nem de-para): exclui de verdade. **Com
  histórico:** 409 com a razão, e a saída é **inativar** (some do PDV, da busca e da matriz de
  criação, continua nos relatórios e no histórico). Reativar volta a oferecer.
- *Valor do modelo* (tirar "GG" do modelo): não apaga variação sozinho. A tela lista as variações
  desse valor (com saldo e histórico) e oferece "inativar essas variações" ou "excluir as sem
  histórico".
- *Modelo:* só exclui sem variações; com variações, inativar o modelo inativa todas (regra 6).
- Última variação ativa inativada: o modelo continua existindo, sem aparecer na busca do PDV.
- Toda alteração acima grava `Auditoria` e roda em transação; nenhuma muda estoque nem histórico.

### 5.3 API (proposta)

| Método | Rota | Função |
|---|---|---|
| GET | `/atributos?busca=` · `/atributos/{id}/valores?busca=` | autocompletar do catálogo (≤10) |
| PATCH/DELETE | `/atributos/{id}` · `/atributo-valores/{id}` · POST `…/mesclar` | manutenção (renomear, mesclar, apagar sem uso) |
| GET | `/produto-modelos` | lista agrupada: nome, nº de variações, estoque total, faixa de preço, ativo |
| POST | `/produto-modelos` | cria modelo (+ atributos + matriz opcional) |
| GET | `/produto-modelos/{id}` | modelo + atributos + variações + matriz de estoque |
| PATCH | `/produto-modelos/{id}` | edita modelo; `aplicar_nas_variacoes: true` propaga padrões |
| POST | `/produto-modelos/{id}/variacoes` | adiciona valores de eixo / combinações (idempotente); com eixo novo, exige o valor das variações atuais |
| PATCH / DELETE | `/produto-modelos/{id}/variacoes/{produto}` | troca valores de uma variação · exclui sem histórico (409 com histórico) |
| POST | `/produto-modelos/{id}/estoque` | entrada/ajuste em lote por variação (`[{produto_id, quantidade}]`) |
| POST | `/produto-modelos/{id}/inativar` / `reativar` | em massa |
| GET | `/produtos?busca=…&agrupar=1` | busca do PDV devolve modelos com as variações e o saldo de cada |

O recurso de produto passa a devolver `descricao_fiscal` (§6.1, E2), para a nota avulsa preencher
o campo de descrição com o mesmo texto que a venda usaria. Permissão: mesma área `produtos`
(`RequireArea:produtos`). Rotas de modelo declaradas **antes** de `/{produto}` onde houver
conflito de segmento.

---

## 6. Impacto por área

### 6.1 Emissão de notas (NF-e 55 e NFC-e 65) — reavaliação de 27/10

**Princípio.** A nota continua sendo montada por item a partir de `produtos`. A grade só altera
**duas funções** de `RegrasFiscais`/`LimitesDoLayout` e **um** ponto do formulário da nota avulsa.
O contrato com o `nfe-api` (`StoreNfeRequest.php:94-102`) **não muda**: `codigo` ≤60, `descricao`
≤120, `gtin` 8/12/13/14 dígitos ou `SEM GTIN`.

| Campo da nota | Como sai com variação | Ação |
|---|---|---|
| `cProd` | `sku` da variação ou `PROD-{id}`, cortado em 60 (`RegrasFiscais::codigoProduto`) | **mudar a geração/validação de SKU** (E1); a função em si não muda |
| `xProd` | nome composto; **limite 120** | **mudar** (E2): `LimitesDoLayout::texto` corta pelo fim, e os valores dos eixos estão no fim |
| `cEAN`/`cEANTrib` | `codigo_barras` da variação | **mudar** (E3): `gtin()` aceita qualquer 13 dígitos, inclusive o EAN interno de prefixo 2 que o F2 vai gerar |
| NCM, CEST, origem, CST/CSOSN, alíquotas | do produto (variação), copiado do modelo | nenhuma; ver E4 sobre divergência |
| `qCom`, `vUnCom`, rateio de desconto/frete | por item, igual | nenhuma |
| Atributos informativos (Marca, Garantia…) | **não vão para a nota** | nenhuma; `infAdProd` não existe no `nfe-api` (G15) |
| Estoque da nota avulsa (`EstoqueDaNota`) | por `produto_id` | nenhuma |
| CC-e / cancelamento / inutilização | independem do produto | nenhuma. Vender o tamanho errado e perceber depois da autorização **não** se corrige por CC-e (mercadoria diferente); é cancelamento ou devolução — confirmar com o contador |
| Contrato com `nfe-api` | nenhuma mudança no payload | teste de contrato na Fase 2 |

**Riscos de emissão e tratamento:**

- **E1 — `cProd` colide depois do corte de 60 (novo, só existe com SKU gerado a partir de texto
  livre).** O SKU aceita 100 caracteres no cadastro e o `cProd` corta em 60
  (`RegrasFiscais.php:357-362`). Dois SKUs que só diferem após a posição 60 saem **iguais** na
  mesma nota: o destinatário e o contador usam `cProd` como chave. Com atributos abertos e valores
  longos isso deixa de ser teórico. *Tratamento:* SKU gerado sempre ≤60 (regra 7); validação de
  SKU (gerado ou manual) recusa o que já existe na empresa com os mesmos 60 primeiros caracteres;
  teste. O buraco é anterior à grade (SKU manual longo), mas a grade o torna provável.
- **E2 — `xProd` perde os valores no corte de 120 (média).** Nome de 150 caracteres cortado pelo
  fim vira "Camiseta Algodão Premium Manga Longa Gola V Linha Verão 2027 …" sem cor nem tamanho: dois
  itens diferentes ficam com a mesma descrição. *Tratamento:* `Produto::descricaoFiscal()` usa
  `variacao_rotulo` (gravado, sem carregar relação, sem N+1): `texto(base, 120 − len(" - " +
  rotulo)) + " - " + rotulo`, em que a base é `nome` sem o sufixo. Como cada valor de eixo tem no
  máximo 25 caracteres e há no máximo 3 eixos, o sufixo tem no máximo ~81 caracteres e sobram ≥39
  para a base. Produto simples (sem rótulo) continua cortando pelo fim, como hoje. O mesmo método
  é usado em `NfeEmissaoService.php:1058` e **exposto ao FE** para pré-preencher a descrição da
  **nota avulsa** (`FormularioNotaAvulsa.php:158` usa o texto digitado pelo usuário; lá o certo é
  avisar, não cortar). Teste de regressão: produto simples com nome longo corta como antes.
- **E3 — GTIN (média).** (a) EAN interno de prefixo 20–29 não é GTIN de mercado: `gtin()` passa a
  devolver `null` (sai `SEM GTIN`); a SEFAZ aceitar ou rejeitar esse código **não foi verificado**
  e excluir é o lado seguro. (b) Dígito verificador: `gtin()` só confere o tamanho, não o DV; um
  EAN digitado errado numa de dezenas de variações pode derrubar a nota inteira (rejeição por GTIN
  inválido — **não verificado em ambiente real**). A grade multiplica a digitação de EAN, então o
  risco cresce. *Proposta, G16 aberta:* validar o DV e, se inválido, avisar no cadastro e emitir
  `SEM GTIN`. (c) `codigo_barras` **não é único**: duas variações com o mesmo EAN fazem o leitor
  do PDV e o casamento por EAN da nota de entrada ficarem ambíguos. *Tratamento:* alerta (não
  bloqueio) na matriz, no mesmo espírito de "avisar, não travar".
- **E4 — Dados fiscais divergentes entre variações e "aplicar ao modelo" (média, antes do snapshot).**
  O modelo guarda padrões e a variação recebe cópia (G3). Uma variação com NCM diferente das irmãs
  é permitida (existe caso real de mesmo modelo com NCM por composição do tecido) e mostrada como
  alerta na tela do modelo. "Aplicar ao modelo" altera N produtos de uma vez. **Conferido em
  27/10:** as 7 alíquotas já ficam gravadas em `venda_itens` (decisão nº 10 do PLAN-IMPOSTOS), mas
  NCM, CEST, unidade, origem, ST, SKU, GTIN e nome são relidos do produto a cada emissão. Na nota
  avulsa, `emitirExistente` remonta o payload a cada envio e reenvio (`NfeEmissaoService.php:311-346`),
  e o `formulario` guardado só tem o que o usuário digitou. Logo, um "aplicar ao modelo" feito entre a
  venda (ou o rascunho) e a emissão muda a nota. *Tratamento decidido em 27/10:* **Fase 0b** (snapshot
  fiscal completo no item, antes da grade). Até ela existir, a confirmação do "aplicar" mostra a
  contagem de variações **e** de vendas/rascunhos/rejeitadas ainda não emitidas que as usam.
- **E5 — Variação ou modelo vendável por engano (baixa).** O modelo não é produto e não entra na
  busca como item; só variações (com combinação completa) são vendáveis. Variação inativa não é
  oferecida no PDV. Teste.
- **E6 — Renomear valor reescreve `xProd` de notas futuras, não das emitidas (baixa).** XML
  autorizado fica gravado; o que muda é a descrição de nota ainda não emitida e a exibição de
  comprovantes antigos. Confirmação com contagem (regra 5).

**Resumo do impacto na emissão:** 2 funções (`gtin`, descrição fiscal), 1 validação (SKU/60), 1
campo derivado exposto ao FE; zero mudança no `nfe-api`; zero mudança em tributação, CFOP, rateio,
pagamento, CC-e, cancelamento ou inutilização.

### 6.2 Entrada de produtos

**Manual (digitando):** `lancarEstoque` por variação continua; ganha entrada **em matriz** no
modelo. `EstoqueService::movimentarEmLote` hoje exige `nota_entrada_id`; ganha variante sem nota.

**Por XML do fornecedor:** onde está o risco maior deste plano fora da emissão.

1. **Segunda nota em diante é automática.** Cada variação tem `cProd`/EAN próprios; o de-para por
   código e o EAN já casam, sem tocar no resolvedor.
2. **`cProd` repetido entre tamanhos.** Alguns fornecedores usam a **referência do modelo** como
   `cProd` em todas as linhas e diferenciam só em `xProd`/EAN. Hoje o passo 1 do resolvedor
   (de-para por `cProd`) vincularia **todos os tamanhos à mesma variação**, silenciosamente, e o
   índice `depara_empresa_forn_codigo_unico` impede guardar mais de um produto por `cProd`.
   **Mudar:** (a) dentro de uma mesma nota, `cProd` repetido ⇒ de-para por código é tratado como
   ambíguo e o item cai para EAN/descrição; (b) o índice único passa a incluir
   `descricao_fornecedor`. Teste obrigatório com esse cenário.
3. **Primeira nota de um modelo novo** (o caso mais doloroso, 40 itens ≈ 8 modelos × 5 tamanhos):
   na conferência, nova ação em massa **"Criar grade com os itens selecionados"**: o usuário
   escolhe/nomeia o modelo e escolhe os atributos-eixo; o sistema **sugere** valores casando o fim
   da descrição com **valores que a empresa já tem no catálogo** (nada de lista fixa de tamanhos
   nem heurística de texto livre), mostra uma tabela editável e só então cria as variações e
   vincula os itens. Nunca vincula sozinho.
4. **Fator de conversão** não muda: continua por (fornecedor, código).
5. **Custo** (`CalculadoraDeCusto`) e histórico de preço continuam por produto = variação.
6. **Não há XML de confecção no projeto.** A única nota real é de aviamentos (313 itens,
   `cProd` = EAN-13 em 309). O comportamento real do fornecedor de moda (repete `cProd`? manda
   EAN? põe tamanho em `xProd` ou em campo próprio?) **não foi observado**; a Fase 0 exige
   pelo menos um XML real antes de congelar a Fase 6.

### 6.3 Estoque

- Saldo continua em `produtos.estoque_atual` (por variação). Saldo do modelo = `SUM` em consulta
  (índice `empresa_id, modelo_id`); **não** se guarda total no modelo.
- Venda continua baixando direto no produto; estoque negativo continua permitido na venda.
- Histórico (`estoque_movimentacoes`) por variação; a tela do modelo mostra a matriz e um link
  para a movimentação de cada célula.

### 6.4 PDV, pedido de venda e nota avulsa

- Leitor de código de barras → variação direta (`ProdutoBusca` já resolve Enter com código
  exato). **Sem mudança.**
- Busca por nome: hoje devolve até 10 produtos; um modelo com 30 variações encheria a lista.
  Passa a agrupar: a sugestão mostra o **modelo**, e ao escolher abre a **matriz** (2 eixos: linhas
  × colunas, com saldo em cada célula; 3 eixos: lista de combinações com saldo). Clicar adiciona a
  variação ao carrinho. Variações sem estoque aparecem esmaecidas mas **vendáveis** (regra atual).
- Carrinho, desconto, pagamento, NFC-e: inalterados (o item é a variação).
- Nota avulsa: ao escolher a variação, a descrição é pré-preenchida com `descricao_fiscal` (E2).

### 6.5 Cadastro e lista

- `ProdutoForm`: escolha no topo "Produto simples" / "Produto com variações" (padrão: simples —
  quem não usa grade não vê diferença). Modo variações: nome, referência, impostos, preço padrão;
  **adicionar atributo** (campo com autocompletar), marcar "gera variação" ou informativo, digitar
  valores com autocompletar; grade pronta como atalho; **pré-visualização das combinações** antes
  de criar, com contador contra o teto de 200.
- `Produtos`: modelos como linha expansível; simples como hoje; filtros ativo/inativo mantidos;
  filtro por valor de atributo informativo (Marca) é possível pelo modelo.
- `MovimentacaoProduto`: uma variação por vez (inalterado) + a matriz no modelo.

### 6.6 Outros pontos tocados

| Ponto | Efeito |
|---|---|
| `distDFe`/notas recebidas | nenhum direto; a importação de XML recebido usa o mesmo resolvedor |
| Dashboard | contagem de produtos passa a contar variações; avaliar se é o desejado |
| `massa:gerar` (comando) | ganhar opção de gerar modelos para testes manuais |
| Planos (F5) | flag `grade` fica pronta para entrar; sem gating nesta entrega (G9) |
| `DATA-MODEL.md`, `REQUISITOS.md`, `MAPA-SISTEMA.md`, `CLAUDE.md` do FE | atualizar na Fase 9 |

---

## 7. Fases

Todas as fases rodam testes **no container** (receita em `reference_running_tests`: env do
container vence o `phpunit.xml`; saída para arquivo, nunca `| head`). Baseline de falhas
pré-existentes do `gestaofacil-api` deve ser registrado na Fase 0 e comparado ao fim de cada fase.

### Fase 0 — Decisões e pré-requisitos
- [ ] Decisões da §8: todas fechadas em 28/10 (G15 e G19 por você; as demais como recomendadas). Falta só G20 (§11), se a medição pedir índice.
- [ ] (Em 28/10 não há XML real de confecção à disposição: a Fase 6 foi implementada com fixture
      **sintética, rotulada como tal**, e o comportamento do fornecedor real segue na §10.)
      Obter **ao menos 1 XML real de compra de confecção** (e idealmente 2 fornecedores) e
      guardar em `tests/Fixtures/nfe-entrada/` (anonimizado se necessário). Conferir: `cProd`
      repete? tem `cEAN`? onde está o tamanho?
- [ ] Rodar a suíte do `gestaofacil-api` e anotar o baseline de falhas.
- [ ] **Linha de base de desempenho (§11):** criar `tests/Performance`, rodar P1–P3, P5 e P6 com
      a massa de 5.000 produtos e guardar os números no `PROGRESS.md` antes de qualquer alteração.
- [ ] Confirmar com o contador: divergência de NCM entre variações; correção de tamanho errado
      pós-autorização (§6.1).
- [ ] Confirmar a lista final de `Produto::CAMPOS_HERDADOS` contra `TributacaoDoItem::CAMPOS`.
- [ ] Portão: nada a commitar além de fixtures e este plano ajustado → PROGRESS.

### Fase 0b — Snapshot fiscal completo no item (pré-requisito da grade; decidido em 27/10)

**Por quê.** Edição em lote de produto ("aplicar ao modelo", renomear valor) passa a ser rotina com
a grade, e hoje só as alíquotas estão congeladas no item. Esta fase estende a decisão nº 10 do
PLAN-IMPOSTOS ("imposto é registro, não configuração") aos demais dados fiscais e de texto da
nota. **Vale para qualquer produto, com ou sem grade**, e pode ser entregue e usada antes dela.

**Campos a congelar (proposta, G18 aberta):** `ncm`, `cest`, `unidade`, `origem_icms`,
`origem_fabricacao`, `tem_substituicao_tributaria` (insumos do CFOP/CST/CSOSN), `codigo_produto`
(o `cProd` já cortado em 60), `gtin` (já resolvido, ou nulo) e `descricao_produto` (o `xProd` já
cortado em 120). As 7 alíquotas já estão lá.

**Escopo e mudanças:**
- [ ] Mapear, em `RegrasFiscais`/`NfeEmissaoService`/`FormularioNotaAvulsa`, **todo** campo de
      `produtos` lido na montagem do payload (lista acima é o que já se viu; confirmar por leitura
      completa) e como o PDV (`pdv_venda_itens`) chega à nota.
- [ ] Migration em `venda_itens` (e `pdv_venda_itens` se o PDV emitir por ele) com as colunas
      novas, todas `nullable`. **Sem backfill** (G19): nenhum item existente é alterado; só o item
      criado depois da fase nasce com snapshot.
- [ ] Novo objeto `DadosFiscaisDoItem` (irmão de `TributacaoDoItem`, **sem alterar** o contrato dele
      nem os `CAMPOS` que o usuário ajusta na tela de emissão): `deProduto()` na criação do item,
      `deRegistro()` na emissão.
- [ ] `NfeEmissaoService::construirItens` e `FormularioNotaAvulsa::montarPayload` leem do item /
      do `formulario`, **não** do produto. No rascunho da nota avulsa, o snapshot é gravado em
      `formulario` na criação, não no envio.
- [ ] **Ação explícita "atualizar dados fiscais a partir do cadastro"** na venda pendente, no
      rascunho e na nota rejeitada, mostrando o que mudaria (campo antes/depois) e só gravando após
      confirmação. Sem ela, quem corrige um NCM errado no produto para reenviar uma nota rejeitada
      não consegue mais fazê-lo por ali (comportamento que hoje funciona por acidente).
- [ ] Itens sem snapshot (nulos, isto é, todos os anteriores à fase) continuam emitindo como hoje,
      relendo o produto, e a emissão recusa só o que já recusa (decisão nº 12 do PLAN-IMPOSTOS). A
      ação "atualizar a partir do cadastro" fica indisponível para eles (não há o que comparar).
- **Testes:** (1) editar NCM/CEST/unidade/nome/SKU/GTIN do produto **depois** da venda não muda o
  payload; (2) reenvio de nota rejeitada usa os mesmos dados da primeira tentativa; (3) rascunho de
  nota avulsa congela na criação; (4) a ação "atualizar a partir do cadastro" mostra o diff e só
  então aplica; (5) item sem snapshot (venda antiga, colunas nulas) emite exatamente como antes, relendo o produto, e a migration não altera nenhuma linha existente; (6) alíquotas
  continuam sendo ajustáveis na tela de emissão e o ajuste prevalece só naquela nota; (7) PDV/NFC-e
  segue a mesma regra; (8) regressão da suíte `Nfe*`, `Pdv*` e `Vendas` inteira; (9) migration
  `down()` testado em banco com vendas emitidas e não emitidas, conferindo que as linhas antigas ficam idênticas.
- [ ] Emissão em **homologação** de uma nota de produto comum depois do snapshot, **somente com
      sua autorização**, e confronto do XML com o de antes da mudança (devem ser idênticos).
- [ ] Desempenho (§11): repetir P5 e P6; nº de queries igual ao da linha de base.
- [ ] Portão completo; registrar a mudança em `PLAN-IMPOSTOS.md` (decisão nº 10 ampliada),
      `DATA-MODEL.md` e `PLAN-SEGURANCA.md`.

### Fase 1 — Atributos, modelo de dados e serviço de grade (API)
- [ ] Migrations: `atributos`, `atributo_valores`, `produto_modelos`, `modelo_atributos`,
      `modelo_atributo_valores`, `produto_atributo_valores`; `produtos.modelo_id/chave_variacao/
      variacao_rotulo` + índice único parcial + índice `(empresa_id, modelo_id)`. `down()` testado.
- [ ] Models com CompanyScope; `Produto::modelo()`, `Produto::CAMPOS_HERDADOS`; factories e
      estado de variação na `ProdutoFactory`.
- [ ] `CatalogoDeAtributos` (normalização, achar-ou-criar, autocompletar, renomear, mesclar com
      detecção de conflito) e `ModeloService` (criar em matriz idempotente, adicionar valor de
      eixo, compor nome/rótulo/chave/SKU ≤60, propagar padrões, inativar/reativar em massa) —
      tudo em transação.
- [ ] Controllers + rotas (§5.3, sem estoque) + validação com `empresa_id` nos `exists`, teto de 3
      eixos e 200 variações, valor de eixo ≤25 caracteres, `Auditoria`.
- [ ] Regra: `Produto::buscar`/`index` continuam funcionando; produto simples intocado.
- [ ] Desempenho (§11): com 5.000 simples + 6.000 variações, repetir P1–P3 e medir P7–P9; falhar se passar do orçamento; decidir G20 com o número na mão.
- **Testes (Pest, `tests/Feature/Products/ModeloGradeTest.php`, `AtributosTest.php` + `tests/Unit`):**
  "Azul", "azul " e "ÁZUL" resolvem o mesmo valor; autocompletar só da empresa logada; matriz
  N×M×K cria o produto cartesiano; repetir não duplica nem sobrescreve edição; adicionar valor cria
  só o que falta; remover valor de eixo não apaga variação; variação herda NCM/impostos/preço;
  "aplicar ao modelo" propaga e conta; renomear recompõe nome/rótulo; mesclar recusa colisão de
  `chave_variacao`; SKU gerado ≤60 e único mesmo com valores longos (E1); 4º eixo recusado; limite
  de 200; **isolamento entre empresas** (atributo, valor, modelo e variação de outra empresa →
  404/422); inativar modelo inativa variações; exclusão bloqueada com histórico; índice único
  impede combinação duplicada; **adicionar** valor, combinação avulsa e eixo novo (com e sem o valor
  das atuais); **editar** variação (preço/SKU/EAN livres, `nome` recusado em `produtos.update`,
  troca de valor recompõe nome/rótulo/chave e mantém SKU e histórico, troca para combinação
  existente → 409); **remover** variação sem histórico exclui, com histórico → 409 e inativar
  funciona, reativar volta; tirar valor do modelo não apaga variação; tirar eixo com colisão → 409;
  nenhuma dessas operações altera `estoque_atual` nem movimentações; permissões por perfil; produto simples continua criando e editando
  como antes.
- [ ] Portão: revisar (`/code-review`, `/simplify`) → testar → commitar → PROGRESS → PLAN-SEGURANCA.

### Fase 2 — Nota fiscal: descrição, código e GTIN (a fase de maior risco fiscal)
- [ ] `Produto::descricaoFiscal()` (E2) e uso em `NfeEmissaoService` (venda/NFC-e); expor no
      recurso de produto para pré-preencher a nota avulsa; `FormularioNotaAvulsa` continua
      avisando (`max:120`), não cortando.
- [ ] `RegrasFiscais::gtin()`: não enviar código de prefixo 20–29 (E3a). Conferência de DV conforme
      G16.
- [ ] Validação de SKU: recusar colisão pós-corte de 60 (E1), no cadastro simples também.
- **Testes:** nome de 150 caracteres com variação mantém os valores dos eixos no `descricao`
  enviado e tem ≤120; três eixos com valores de 25 caracteres ainda cabem; produto simples com nome
  longo continua cortando pelo fim (regressão); `gtin()` com EAN real de 13 dígitos sai, com
  `2xxxxxxxxxxxx` não sai, com código curto não sai; dois SKUs idênticos nos 60 primeiros
  caracteres são recusados; payload de NFC-e e de NF-e com duas variações do mesmo modelo: `codigo`
  e `gtin` distintos, mesmo NCM; nota avulsa com variação pré-preenche a mesma descrição que a
  venda enviaria; contrato com `nfe-api` (`StoreNfeRequest` aceita o payload — rodar a suíte do
  `nfe-api` com um payload de variação).
- [ ] Emissão em **homologação** de uma NF-e com duas variações do mesmo modelo, **somente com sua
      autorização** (envia dado à SEFAZ): confirma `cProd`/`xProd`/`SEM GTIN` aceitos e esclarece
      o que a §10 deixa sem verificação.
- [ ] Portão completo.

### Fase 3 — Estoque em matriz
- [ ] `EstoqueService`: `lancarEmLote`/`movimentarEmLote` aceitam movimento sem `nota_entrada_id`
      (entrada/ajuste manual em lote) sem alterar o contrato atual das notas de entrada.
- [ ] Endpoint `POST /produto-modelos/{id}/estoque`; `GET /{id}` devolve matriz com saldos.
- **Testes:** entrada em lote soma por variação e grava movimentação; quantidade ≤ 0 recusa tudo
  (transação, nada parcial); variação de outro modelo/empresa recusada; saldo do modelo = soma;
  venda de variação baixa só aquela; estorno de venda devolve só aquela; lançamento de nota de
  entrada existente **não regride** (suíte `Compras` inteira verde).
- [ ] Portão completo.

### Fase 4 — Front: cadastro, lista, estoque e catálogo
- [ ] Tipos (`Produto` ganha `modelo_id/variacao_rotulo/descricao_fiscal`; `ProdutoModelo`,
      `Atributo`, `AtributoValor`), `produtoModeloApi` e `atributoApi` em `services/api.ts`.
- [ ] Componente de campo com autocompletar (atributo e valor, criar ao digitar).
- [ ] `ProdutoForm` com modo variações (atributos, eixo/informativo, grades prontas,
      pré-visualização); tela do modelo (matriz de estoque e preço, "aplicar a todas", alerta de
      variação divergente e de EAN repetido).
- [ ] `Produtos` agrupada com linha expansível; filtros preservados.
- [ ] Tela opcional de manutenção do catálogo (renomear, mesclar, apagar sem uso) — cortável.
- [ ] `data-testid` novos entram na tabela "Seletores usados pelo E2E" do `gestaofacil-fe/CLAUDE.md`.
- **Testes:** `tsc`/build limpo; regra pura de combinações (produto cartesiano, ordem dos eixos,
  grade pronta) em módulo `utils/` testável isoladamente (checar com o `esbuild` do container, pois
  não há eslint/runner instalado — ver `reference_fe_lint_ausente`); conferência visual no Firefox
  feita por você.
- [ ] Portão completo.

### Fase 5 — Front: PDV, pedido e nota avulsa
- [ ] `GET /produtos?agrupar=1` (API) e `ProdutoBusca` agrupando; componente `GradeSeletor`
      (matriz com saldo; lista para 3 eixos) usado no PDV, `VendaForm` e `NotaForm`.
- [ ] Leitor/Enter com código exato continua indo direto à variação.
- [ ] Desempenho (§11): P1–P4 com `agrupar=1`; você confere no Firefox o tempo até a sugestão no PDV (nome e leitura de código).
- **Testes:** Pest do endpoint agrupado (ordem, saldo, inativos ocultos, empresa); venda no PDV com
  duas variações do mesmo modelo baixa cada saldo; pedido e nota avulsa com variação; regressão do
  PDV com produto simples.
- [ ] Portão completo.

### Fase 6 — Nota de entrada com variações
- [ ] `ResolvedorDeProdutos`: `cProd` repetido na mesma nota ⇒ de-para por código ambíguo;
      migration que inclui `descricao_fornecedor` no índice único do de-para; `LancamentoNotaService`
      grava o de-para por variação.
- [ ] Ação em massa "Criar grade com os itens selecionados" (API em `AcoesEmMassa` + modal em
      `ConferenciaNotaEntrada`): sugere valores a partir do catálogo, o usuário confirma, cria e
      vincula.
- [ ] Lançamento cria/atualiza variações e dá entrada por variação.
- **Testes:** com o XML de confecção da Fase 0: (1) 1ª importação cria grade e vincula;
  (2) 2ª importação do mesmo fornecedor vincula tudo sozinha; (3) `cProd` repetido não vincula
  tamanhos diferentes à mesma variação; (4) EAN único por variação casa; (5) EAN duplicado em duas
  variações não vincula (ambíguo); (6) cancelar nota estorna só as variações da nota; (7) fator de
  conversão por variação; (8) sugestão só a partir de valores já existentes no catálogo, descrição
  sem valor conhecido → sem sugestão, nunca vincula sozinha; regressão: XML de aviamentos (313
  itens) com o mesmo resultado de antes.
- [ ] Portão completo.

### Fase 7 — Ferramenta opcional: agrupar produtos existentes
Só se o piloto já tiver produtos soltos tipo "Camiseta Azul M".
- [ ] Ação na lista: selecionar produtos → "agrupar em modelo" (define o valor de cada eixo para
      cada produto; não altera estoque nem histórico).
- **Testes:** agrupa sem alterar `estoque_atual`, SKU nem vendas; recusa produto de outra empresa.
- [ ] Portão completo. (Cortável sem afetar o resto.)

### Fase 8 — E2E (Playwright)
Princípios do `PLAN-E2E.md` mantidos: nenhum teste emite documento fiscal fora da suíte fiscal
com gateway fake; dado de apoio por API; sem `waitForTimeout`; seletor por acessibilidade.

**Ajustes nos testes existentes** (a variação é produto, então a maioria segue verde; o que muda
é onde a tela mudou):
- [ ] `pages/ProdutoPage.ts`: `ProdutoFormPage` ganha o seletor do tipo (simples/variações) e
      fixa **simples** como padrão para `cadastra um produto pela tela` (CT-E2E-004).
- [ ] `pages/PdvPage.ts` e `PedidoPage.ts`: o resultado da busca pode ser um modelo; métodos
      `adicionarPorBusca`/`adicionarPorCodigo` ganham `escolherVariacao({atributo: valor, …})`;
      busca de produto simples permanece como está.
- [ ] `pages/NotaEntradaPage.ts`: ação "Criar grade".
- [ ] `helpers/api-helper.ts` e `helpers/dados.ts`: `criarModelo({eixos, informativos, …})`
      devolve o modelo e as variações (por API); `produtoDeTeste` continua gerando simples.
- [ ] Revisar `produto-cadastro`, `pdv-venda`, `pdv-codigo-barras`, `pedido-venda`,
      `nota-entrada*`, `unicidade-por-empresa`, `rbac-isolamento` e `dashboard` rodando-os
      **antes** de editar nada: só mudar o que falhar por causa da mudança de tela.

**Specs novos** (casos `CT-E2E-106` em diante em `docs/CASOS-DE-TESTE-E2E.md`):
- [ ] `produto-grade.spec.ts` — cria modelo pela tela (Cor × Tamanho com grade pronta P–GG × 2
      cores), conferir 8 variações, autocompletar reaproveita "Branco" digitado como "branco",
      atributo informativo "Marca", preço por exceção, repetir criação não duplica, lista agrupada
      e expansão, inativar modelo.
- [ ] `produto-grade-edicao.spec.ts` — adiciona um tamanho e uma cor a modelo existente (só as
      combinações novas aparecem); edita preço, SKU e EAN de uma variação; tenta editar o nome da
      variação (recusado); troca o valor de uma variação; remove variação sem histórico (some) e
      com histórico (recusa e inativa; some do PDV, reativa e volta); tira um valor do modelo e vê a
      lista de variações afetadas.
- [ ] `produto-grade-estoque.spec.ts` — entrada em matriz e saldo do modelo; movimentação por
      variação.
- [ ] `pdv-grade.spec.ts` — busca por nome abre a matriz; vende duas variações; saldo de cada
      cai; código de barras da variação entra direto; variação sem estoque é vendável.
- [ ] `nota-entrada-grade.spec.ts` — importa o XML de confecção, "criar grade", lança, confere
      estoque por variação; segunda importação vincula sozinha.
- [ ] `fiscal/nfe-grade.spec.ts` (com `E2E_GATEWAY_FAKE=1 make test-e2e-fiscal`) — venda de duas
      variações: no payload/XML, `cProd` e `xProd` por variação, `xProd` ≤120 com os valores dos
      eixos preservados, "SEM GTIN" para código interno, nota avulsa com a mesma descrição.
- [ ] `rbac-isolamento`: modelo, atributo e valor de outra empresa → 404; vendedor sem área
      `produtos` não cria modelo.
- [ ] Atualizar `PLAN-E2E.md` (estado e contagem), `docs/CASOS-DE-TESTE-E2E.md` (módulo novo e
      matriz de cobertura), `docs/MAPA-SISTEMA.md` e a tabela de seletores.
- [ ] Rodar a suíte inteira em chromium **e** firefox; conferir `nfe_emissoes = 0` ao fim da
      suíte comum (guarda de NFC-e).
- [ ] Portão completo.

### Fase 9 — Fechamento
- [ ] `DATA-MODEL.md` (api e raiz), `REQUISITOS.md`, `PROGRESS.md` (api, fe, raiz).
- [ ] Alinhar `PLAN-PRE-BETA.md` §7/D7 e `PLAN-LANCAMENTO.md` ao que foi decidido (reescrever o
      corpo, não anotar), **mediante sua confirmação**.
- [ ] `PLAN-SEGURANCA.md`: novos checks (isolamento de atributo/valor/modelo, autocompletar só da
      empresa, limite de lote e de eixos, `exists` com empresa) e registro.
- [ ] Auditoria de realidade (`/auditoria-realidade`) sobre a feature: nada de mock, nada
      "pronto" sem rodar; tela conferida por você no Firefox.
- [ ] Clone limpo + migração do zero (`migrate:fresh`) com a suíte verde.

---

## 8. Decisões

| # | Decisão | Opções | Estado / recomendação |
|---|---|---|---|
| G1 | Onde mora o modelo | tabela `produto_modelos` · `produto_pai_id` em `produtos` | *Adotada:* **tabela própria** — pai em `produtos` seria "produto" vendável sem estoque |
| G2 | Eixos | cor + tamanho fixos · atributos abertos | **Decidida por você em 27/10:** atributos abertos, criados no uso com autocompletar; cada atributo é eixo ou informativo **por modelo**; máx. 3 eixos |
| G3 | Dados fiscais | copiar para a variação e propagar do modelo (variação editável com aviso) · ler sempre do modelo | **Decidida em 28/10:** **copiar + "aplicar ao modelo"**; deixa `TributacaoDoItem`/`RegrasFiscais` intactos. Padrões do modelo em `jsonb` limitado a `Produto::CAMPOS_HERDADOS` |
| G4 | SKU da variação | gerado · vazio (usa `PROD-id`) · manual | *Adotada:* **gerado**, ≤60 caracteres, editável; exige campo `referencia` (opcional) no modelo |
| G5 | Nome da variação | gravar composto em `produtos.nome` · compor na leitura | *Adotada:* **gravar composto**, mantido pelo sistema; zero mudança nas telas que já mostram `nome` |
| G6 | Preço | padrão no modelo, exceção por variação · um preço só | *Adotada:* **padrão + exceção** |
| G7 | Código de barras | gerar EAN interno na criação · só sob demanda (etiqueta, F2) | *Adotada:* **sob demanda no F2**; sem EAN, a variação vende por busca/matriz. `gtin()` ignora prefixo 2 |
| G8 | Produtos que já existem | ficam simples · migrar automático · ferramenta de agrupar | *Adotada:* **ficam simples**; Fase 7 opcional |
| G9 | Plano | `grade` só no Loja já agora · sem flag até o F5 | *Adotada:* **sem flag agora**; liga no F5 por `PlanoService::permite($e,'grade')` |
| G10 | De-para com `cProd` repetido | incluir descrição no índice único · bloquear import | *Adotada:* **incluir descrição** + tratar repetido como ambíguo |
| G11 | Busca no caixa | matriz · lista plana | *Adotada:* **matriz** (2 eixos) / lista de combinações (3); lista plana é o fallback se a Fase 5 apertar |
| G12 | Colunas derivadas `chave_variacao` e `variacao_rotulo` em `produtos` | com as colunas · sem elas | **Decidida em 28/10:** **com as colunas** (unicidade garantida no banco; `xProd` sem carregar relação na emissão) |
| G13 | Teto de eixos | 2 · 3 · sem teto | *Adotada:* **3**, e 200 variações por chamada |
| G14 | Tamanho máximo de valor de eixo | 25 · 60 | *Adotada:* **25** (garante ≥39 caracteres para a base do `xProd`); informativo 60 |
| G15 | Atributos informativos na NF-e | fora da nota · `infAdProd` (muda `nfe-api` e `gestaofacil-api`) | **Decidida por você em 28/10:** **fora da nota** na v1. Se um cliente precisar de garantia ou composição impressa, vira fase própria nos dois serviços |
| G16 | Dígito verificador do GTIN | só avisar · avisar e emitir `SEM GTIN` se inválido · não mexer | **Decidida em 28/10:** **avisar no cadastro e emitir `SEM GTIN` se o DV for inválido** (Fase 2) |
| G17 | Atributo informativo em produto simples | já na v1 · depois | **Decidida em 28/10:** **depois da v1** (hoje só o modelo guarda informativos) |
| G18 | Quais campos congelar no item (Fase 0b) | só os dados fiscais · também `cProd`, GTIN e descrição | **Decidida em 28/10:** **todos os listados na Fase 0b** (dados fiscais, `cProd`, GTIN e descrição) |
| G19 | Backfill dos itens antigos | copiar o valor atual do produto · deixar nulo | **Decidida por você em 28/10:** **não alterar dado antigo nenhum.** Sem backfill: item existente fica com as colunas novas nulas e a emissão o trata como hoje (relê o produto). Só item criado depois da Fase 0b nasce com snapshot |
| G20 | Índice trigram (`pg_trgm`) na busca de produtos | habilitar a extensão · só ajustar consulta | ***Aberta, condicional.*** Só se a medição da §11 estourar o orçamento; habilitar extensão no Postgres de produção é decisão sua |

## 9. Riscos

| Risco | Prob. | Efeito | Mitigação |
|---|---|---|---|
| Fornecedor de moda repete `cProd` entre tamanhos | **alta** | vincula todos os tamanhos a uma variação | Fase 0 (XML real) + G10 + teste dedicado |
| **E1** SKU gerado colide depois do corte de 60 em `cProd` | média | dois itens da nota com o mesmo `cProd` | SKU ≤60, validação pós-corte, teste (Fase 1/2) |
| **E2** `xProd` perde os valores dos eixos no corte de 120 | média | nota com descrição igual para itens diferentes | `descricaoFiscal()` + limite de 25 por valor + teste (Fase 2) |
| **E3** EAN interno ou com DV errado enviado como GTIN | média | rejeição da nota inteira | `gtin()` exclui prefixo 2; G16 para o DV; validar em homologação |
| **E3c** EAN repetido entre variações | média | leitor/casamento ambíguo | alerta na matriz; nota de entrada trata como ambíguo |
| **E4** Variações com NCM divergente, ou "aplicar ao modelo" alterando nota ainda não emitida | baixa | emissão com NCM/descrição não esperados | alerta no modelo, confirmação com contagem, `Auditoria` |
| Catálogo com duplicatas ("Azul"/"Azull") | média | matriz e filtros poluídos | normalização + autocompletar + mesclar |
| Produto cartesiano grande por engano | baixa | 200+ linhas criadas sem querer | pré-visualização com contador, teto de 3 eixos e 200 |
| Lista de produtos lenta/poluída | baixa | UX ruim | lista agrupada + índice `(empresa_id, modelo_id)` |
| Snapshot fiscal (Fase 0b) mudar a emissão de produto comum | média | nota diferente da de hoje; correção de NCM no cadastro deixa de valer para venda pendente | testes 1–9 da Fase 0b, ação "atualizar a partir do cadastro", XML antes×depois em homologação |
| Busca do PDV ficar lenta com milhares de variações (`ILIKE '%x%'` não usa índice) | **média** | caixa travado, o pior efeito possível | §11: linha de base antes, orçamento relativo e absoluto, P1–P4 em cada fase; G20 (`pg_trgm`) se pedir |
| Escopo estourar a janela Dez–Jan | **média-alta** (atributos abertos aumentaram o escopo) | atraso do beta de moda | corte: tela de manutenção do catálogo e Fase 7 saem; depois Fase 6 vira "vincular manual"; piso = Fases 1–5 |
| Mudança de tela quebrar E2E | média | suíte vermelha | Fase 8 roda a suíte *antes* de editar |

## 10. O que não foi verificado

- Comportamento real de XML de fornecedor de **moda** (só existe o de aviamentos).
- Aceitação, pela SEFAZ, de GTIN com prefixo 2 no `cEAN` (por isso a regra de excluir) e rejeição
  por dígito verificador inválido: são premissas, não foram testadas contra a SEFAZ.
- Se uma nota com dois itens de `xProd` parecidos mas distintos é aceita sem aviso de duplicidade
  de item (esperado que sim; confirmar na homologação da Fase 2).
- Se o PDV de loja de moda precisa de leitura de etiqueta com **dois** códigos (modelo + variação).
- Desempenho do autocompletar e da busca agrupada com milhares de variações (esperado trivial;
  medir na Fase 5).
- Como a venda do PDV (`pdv_venda_itens`) chega à nota e se herda a tributação gravada em `venda_itens`.
- Se `RegrasFiscais::icms`/`cfop` leem do produto mais campos do que a Fase 0b lista (a Fase 0b começa por esse mapeamento completo).
- A lista final dos campos herdáveis (`CAMPOS_HERDADOS`) contra `TributacaoDoItem::CAMPOS`.
- Nada deste documento foi executado: é leitura de código e dos planos existentes.

## 11. Desempenho — testes antes e depois (o PDV tem de continuar rápido)

**O que existe hoje (lido em 28/10, não medido):** a busca do PDV chama `GET /produtos?busca=…&apenas_ativos=true&per_page=10`
(`ProdutoBusca.tsx`, com debounce de 250 ms e mínimo de 2 caracteres) → `ProdutoController::index`
→ `Produto::buscar`, que faz `ILIKE '%termo%'` em nome e SKU e `=` em `codigo_barras`. Os índices
são `(empresa_id, nome)`, `(empresa_id, ativo)` e `codigo_barras` (sem `empresa_id`). Um `ILIKE`
com curinga no começo **não usa** o índice de `nome`: o Postgres varre as linhas da empresa. Hoje
isso é barato; com a grade a tabela passa a ter uma linha por variação (200 modelos × 30 variações
= 6.000 linhas a mais por empresa). Não há `pg_trgm` nas migrations. Não existe nenhum teste de
desempenho no projeto.

**Cenários medidos (mesmo script antes e depois, no banco de teste `_test`, dentro do container):**

| # | Cenário | O que mede |
|---|---|---|
| P1 | `GET /produtos?busca=<nome parcial>&per_page=10`, 50 execuções | p50/p95 do servidor, nº de queries, plano (`EXPLAIN (ANALYZE, BUFFERS)`) |
| P2 | `GET /produtos?busca=<EAN exato>` (leitor de código de barras) | idem; tem de ser a mais rápida |
| P3 | `GET /produtos?busca=<SKU parcial>` | idem |
| P4 | `GET /produtos?busca=…&agrupar=1` (Fase 5) | idem + tamanho da resposta em KB |
| P5 | criar venda do PDV com 10 itens (`PdvVendaService`) | tempo e nº de queries (sem N+1) |
| P6 | montar o payload de NFC-e/NF-e com 50 itens (`construirItens`) | nº de queries, que **não pode crescer** com o snapshot da Fase 0b nem com a grade |
| P7 | `GET /atributos?busca=` e `/atributos/{id}/valores?busca=` (autocompletar) | p95 |
| P8 | `GET /produto-modelos/{id}` com 200 variações (matriz + saldos) | nº de queries e tempo |
| P9 | criar matriz de 200 variações (`criarComVariacoes`) | tempo total e nº de queries |

**Massa de dados:** uma empresa com 5.000 produtos simples (**fase "antes"**) e, depois, os mesmos
5.000 mais 6.000 variações de 200 modelos (**fase "depois"**), com outra empresa de volume igual
no mesmo banco, para pegar filtro de `empresa_id` mal usado. Gerada por seeder/factory no próprio
teste, nunca no banco de desenvolvimento. O `massa:gerar` ganha a opção de gerar essa massa para
a conferência manual no Firefox.

**Como falha (critério):** (1) **número de queries por requisição** é determinístico: o teste
afirma o valor exato do baseline, e subir exige justificativa; (2) tempo: **relativo ao baseline**
(≤ +20% no p95 do mesmo cenário, na mesma máquina) e **teto absoluto** a ser fixado depois da
primeira medição (proposta inicial: P1–P3 com p95 < 100 ms no servidor; P5 < 300 ms); (3) o plano do
`EXPLAIN` de P2 tem de usar índice, não varredura sequencial. Teste de tempo roda no grupo
`performance`, **fora da execução padrão** (`make test-api ARGS="tests/Performance"`), porque tempo
em máquina compartilhada oscila; as asserções de nº de queries e de uso de índice ficam também na
suíte comum. Confirmar o registro da pasta `tests/Performance` no `phpunit.xml` na Fase 0.

**Quando medir:**
- **Fase 0 (antes de qualquer alteração):** rodar P1–P3, P5, P6 e guardar os números em
  `docs/PROGRESS.md`. Sem essa linha de base, nenhuma fase seguinte começa.
- **Fase 0b:** repetir P5 e P6 (o snapshot acrescenta colunas ao item; as queries não podem subir).
- **Fase 1:** repetir P1–P3 com as 6.000 variações carregadas; incluir P7–P9.
- **Fase 5:** repetir P1–P4 com o `agrupar=1` e conferir no Firefox, por você, o tempo até a
  sugestão aparecer no PDV (busca por nome e leitura de código).
- **Fase 8/9:** relatório final comparando antes × depois na §10 do `PROGRESS.md`.

**Se estourar o orçamento:** a primeira medida é índice trigram (`pg_trgm`, `GIN` sobre
`nome` e `sku` com `empresa_id`), o que exige habilitar a extensão no Postgres — decisão G20,
**aberta, só se a medição pedir**. Outras medidas antes disso: não buscar variações na sugestão
(só o modelo, com contagem), `LIMIT 10` já na consulta agrupada, e `select` apenas das colunas
que o PDV mostra.
