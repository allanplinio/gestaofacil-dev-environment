# PLAN-GRADE.md — Produtos com variações (cor, tamanho) — detalhamento da F1

**Status:** **PLANO — nada implementado.** Escrito em 2026-10-22, conferido contra o código de
`gestaofacil-api`, `gestaofacil-fe` e `gestaofacil-e2e` nesta data. As decisões da §8 estão
**abertas**: a coluna "Recomendo" é proposta, não combinado (nada de campo novo, tabela nova ou
duplicação de dado entra antes de você confirmar).

**Documentos relacionados:** [`PLAN-PRE-BETA.md`](./PLAN-PRE-BETA.md) §7 (F1, que este plano
detalha) · [`PLAN-LANCAMENTO.md`](./PLAN-LANCAMENTO.md) · [`PLAN-IMPORTACAO-XML.md`](./PLAN-IMPORTACAO-XML.md) ·
[`PLAN-IMPOSTOS.md`](./PLAN-IMPOSTOS.md) · [`PLAN-SEGURANCA.md`](./PLAN-SEGURANCA.md) ·
[`gestaofacil-e2e/PLAN-E2E.md`](../../gestaofacil-e2e/PLAN-E2E.md) · [`DATA-MODEL.md`](./DATA-MODEL.md)

Cada fase termina com **revisar → testar → commitar → PROGRESS** e com a atualização do
`PLAN-SEGURANCA.md`, nessa ordem, antes de a seguinte começar.

---

## 1. Resumo

**Problema.** Loja de roupa vende o mesmo modelo em várias cores e tamanhos. Hoje o sistema só
tem "produto" plano: a loja teria de cadastrar "Camiseta Azul M", "Camiseta Azul G", … como
produtos soltos, sem saber o total do modelo, sem cadastro em lote, sem escolher o tamanho no
caixa.

**Recomendação.** **Variação = produto (linha em `produtos`) ligada a um *modelo* (tabela nova
`produto_modelos`)**, com `cor` e `tamanho`. O modelo guarda o que é comum (nome-base, impostos,
preço padrão, lista de cores e tamanhos); cada variação guarda o que é próprio (código de barras,
SKU, estoque, preço se for diferente).

**Por quê.** Estoque, venda, NF-e, NFC-e, nota de entrada, de-para de fornecedor, movimentação e
CC-e/cancelamento trabalham com `produto_id`. Se a variação *é* um produto, **nenhum desses
fluxos precisa ser reescrito** — o que muda é o cadastro (criar em matriz), a busca no caixa
(escolher cor/tamanho) e a importação de XML (casar item com variação). A alternativa de tabela
própria de variações com estoque próprio obriga a tocar em todos eles (§4).

**Tamanho:** G. Cabe na janela Dez/2026–Jan/2027 do PLAN-PRE-BETA somente se o escopo da §3
(v1 da grade) for respeitado; o que ficou fora está na §3.2.

---

## 2. O que existe hoje (conferido no código)

| Peça | Estado hoje | Onde |
|---|---|---|
| Produto | linha única; `sku` único por empresa (nullable), `codigo_barras` **não** único, `estoque_atual` decimal(…,4) no próprio produto | `app/Models/Produto.php`, migration `…000007` |
| Estoque | `EstoqueService`: entrada/ajuste/saída manuais gravam `estoque_movimentacoes`; venda baixa direto em `estoque_atual` (sem razão); entrada de nota em lote | `app/Services/EstoqueService.php` |
| Itens de venda | `venda_itens` e `pdv_venda_itens` apontam `produto_id` (FK `restrict`); **nome não é gravado no item** — vem do produto na hora de emitir | `PdvVendaService`, `VendaService` |
| NF-e/NFC-e | `cProd` = `sku` ou `PROD-{id}`; `xProd` = `produtos.nome` cortado em 120; `cEAN` = `codigo_barras` se tiver 8/12/13/14 dígitos | `RegrasFiscais::codigoProduto/gtin`, `NfeEmissaoService` ~L1057, `LimitesDoLayout` |
| Entrada de XML | `ResolvedorDeProdutos` casa na ordem: de-para por `cProd` → de-para por descrição → EAN → `cProd`=EAN-13 → `cProd`=SKU → criar. Ambíguo não vincula. De-para único por `(empresa, fornecedor, cProd)` | `app/Services/Compras/*` |
| Cadastro/lista/busca (FE) | `ProdutoForm`, `Produtos`, `ProdutoBusca` (até 10 sugestões; Enter com leitor), `MovimentacaoProduto`; tipo `Produto` em `types/index.ts` | `gestaofacil-fe/src` |
| Grade/variação | **não existe** em código nem em tela. Só planejada em PLAN-PRE-BETA §7 (F1) e PLAN-LANCAMENTO | — |
| Planos/feature flag | coluna `planos.features` (array) existe; **não há `PlanoService::permite()`** — é o F5 | `app/Models/Plano.php` |

Nada disto foi verificado em execução nesta sessão: é leitura de código. O que depende de
comportamento real (SEFAZ, XML de confecção) está marcado na §10.

---

## 3. Escopo

### 3.1 Entra na v1 da grade

1. Cadastro de **modelo** com cores × tamanhos → cria as variações (matriz), idempotente.
2. Variação herda impostos, unidade e preço do modelo; edição por exceção.
3. Lista de produtos **agrupada** por modelo (total de estoque, faixa de preço, nº de variações).
4. Estoque por variação, com **entrada/ajuste em matriz** (cor × tamanho) e saldo do modelo.
5. **PDV, pedido e nota avulsa**: leitor acha a variação; busca por nome abre a matriz.
6. **Nota fiscal**: `cProd`, `xProd`, `cEAN` por variação; nome "Modelo - Cor - Tamanho" que **não
   perde o tamanho no corte de 120**.
7. **Nota de entrada**: variação casa por de-para/EAN; ação "criar grade" na conferência.
8. Grades prontas (P–GG, 34–46, 33–44, infantil).
9. Testes Pest, testes de componente/tipo no FE e E2E (fase final).

### 3.2 Fica fora (de propósito)

| Fora | Motivo / onde vai |
|---|---|
| Relatórios por grade ("peças paradas", curva por modelo) | F9 do PLAN-LANCAMENTO; esta entrega só expõe os campos |
| Etiqueta com cor/tamanho | F2; aqui só garantimos que os campos existem |
| Troca de tamanho (devolução + nova venda) | F3; a variação já é produto, então a troca vira movimento entre produtos |
| Mais de dois eixos (ex.: tamanho + cor + estampa) | YAGNI; ver G2 |
| Gating por plano (`grade` só no Loja) | depende do F5; ver G9 |
| Atualizar `cor`/`tamanho` por XML automaticamente (parse de texto livre) | heurística errada vincula errado no meio de centenas de itens; só **sugere** (Fase 6) |

---

## 4. Soluções avaliadas

### A. Variação = produto + tabela de modelo (**recomendada**)
`produto_modelos` (nome-base, padrões, cores, tamanhos) e `produtos.modelo_id`, `cor`, `tamanho`.
- **Prós:** estoque, venda, nota e importação continuam em `produto_id`; leitor de código de
  barras e de-para já funcionam por variação; cada variação tem `cProd`/`cEAN` próprios (o que a
  SEFAZ e o fornecedor já esperam); nenhuma FK nova em item de venda.
- **Contras:** mais linhas em `produtos` (200 modelos × 5 cores × 6 tamanhos = 6.000 linhas —
  irrelevante para o Postgres, mas a lista precisa agrupar); dados fiscais aparecem em cada
  variação (ver G3); renomear o modelo reescreve o nome das variações.

### B. Tabela `produto_variacoes` com estoque próprio, e item de venda apontando `variacao_id`
- **Prós:** modelo relacional "puro", produto continua sendo um só.
- **Contras:** toca `venda_itens`, `pdv_venda_itens`, `EstoqueService`, `EstoqueDaNota`,
  `PdvVendaService`, `VendaService`, `FormularioNotaAvulsa`, `NfeEmissaoService`,
  `TributacaoDoItem`, `LancamentoNotaService`, `ResolvedorDeProdutos`, de-para, movimentação,
  FE inteiro de carrinho/busca, **e** as migrações de dado de quem já usa. É reescrever os
  caminhos que o PLAN-SEGURANCA e a suíte E2E já cobriram. Risco fiscal alto sem ganho: a NF-e
  não tem conceito de "variação", só de item.

### C. Atributos livres (EAV / JSON) em vez de cor e tamanho
- **Prós:** serve qualquer segmento (perfume em ml, cabo em metros).
- **Contras:** matriz de cadastro e de estoque precisa de eixos definidos; busca/filtro em JSON
  é pior; pouca demanda comprovada. Dá para evoluir A depois: `cor` e `tamanho` são só dois
  `varchar`; o rótulo da tela pode virar configurável sem mudar a estrutura.

### D. Não construir: convenção de nome ("Camiseta Azul M") + criação em lote por CSV
- **Prós:** quase zero código.
- **Contras:** sem saldo do modelo, sem escolha de tamanho no caixa, sem agrupar na lista. É o
  que o concorrente de moda anuncia como "grade" e o PLAN-LANCAMENTO trata como pergunta número 1
  de loja de moda. Descartada, mas é o **plano B de corte** se a data apertar (só Fases 1–2).

### Comparação

| Critério | A (produto + modelo) | B (tabela de variações) | C (EAV) | D (convenção) |
|---|---|---|---|---|
| Fluxos existentes reescritos | **nenhum** | ~10 serviços + FE | ~3 | nenhum |
| Risco fiscal | baixo (mesmo item de nota) | alto | médio | nenhum |
| Estoque por tamanho | sim | sim | sim | sim (sem soma) |
| Saldo do modelo | soma em consulta | soma em consulta | soma em consulta | **não** |
| Cadastro em lote | sim | sim | sim | CSV |
| Importação de XML | casa por variação | reescrever | reescrever | igual a hoje |
| Migração de quem já usa | nenhuma (produto simples segue) | obrigatória | obrigatória | nenhuma |
| Esforço | **G** | GG | G+ | P |

**Decisão proposta: A.** É a mesma que o PLAN-PRE-BETA já registrava como D7, com um refinamento:
o PLAN-PRE-BETA admitia `produto_pai_id` (auto-relação em `produtos`). Aqui recomendo **tabela
`produto_modelos` separada**, porque um "produto pai" é uma linha em `produtos` sem estoque e sem
preço próprio que aparece em lista, busca, PDV e relatório e **pode ser vendido por engano**.

---

## 5. Desenho (solução A)

### 5.1 Dados

```
produto_modelos                         (novo — escopo empresa, CompanyScope)
  id, empresa_id
  nome            varchar(200)          -- nome-base: "Camiseta Básica"
  referencia      varchar(60) null      -- código do modelo: "CAM001" (base do SKU)
  unidade         varchar(10)
  preco_venda     decimal(12,2)         -- padrão das variações
  padroes         jsonb                 -- campos herdados: ncm, cest, origem_icms, tem_substituicao_tributaria,
                                        -- icms_*, pis_*, cofins_*, ipi_* (só os de Produto::CAMPOS_HERDADOS)
  cores           jsonb                 -- ["Azul","Preto"] em ordem de exibição
  tamanhos        jsonb                 -- ["P","M","G","GG"] em ordem de exibição
  ativo           boolean
  timestamps
  unique (empresa_id, referencia) quando preenchida

produtos                                (colunas novas)
  modelo_id       bigint null  FK produto_modelos (restrict)
  cor             varchar(60) null
  tamanho         varchar(30) null
  unique (modelo_id, coalesce(cor,''), coalesce(tamanho,''))   -- índice de expressão (Postgres)
  index (empresa_id, modelo_id)
```

- **Produto simples** continua com `modelo_id = null`: nada muda para quem não usa grade.
- `produtos.nome` das variações guarda o **nome composto** `"Modelo - Cor - Tamanho"`,
  mantido pelo sistema (G5). Assim lista, PDV, comprovante, nota de entrada e a nota fiscal
  mostram o nome certo sem lógica nova de composição em cada tela.
- Estoque, preço, `sku`, `codigo_barras`, `preco_compra` e tributação **ficam em `produtos`**
  (inalterados) — por isso `TributacaoDoItem::deProduto`, `RegrasFiscais` e as validações de NCM/CEST
  da emissão não mudam.

### 5.2 Regras

1. **Criação em matriz** (`ModeloService::criarComVariacoes`): para cada `cor × tamanho` pedido,
   cria a variação se não existir; devolve criadas e já existentes. **Idempotente**: repetir a
   chamada não duplica nem sobrescreve edição manual.
2. **Adicionar cor ou tamanho depois** = nova chamada de matriz; só cria o que falta.
3. **Herança:** na criação a variação recebe uma cópia de `padroes`, unidade e `preco_venda`.
   Editar o modelo (impostos/unidade/preço padrão) **não mexe sozinho** nas variações: a tela
   oferece "aplicar a todas as variações" com contagem e confirmação. Variação com preço ou
   imposto editado à mão continua editável, com aviso "faz parte do modelo X" — nunca travada.
4. **Renomear modelo/cor/tamanho** recompõe `produtos.nome` das variações afetadas, na mesma
   transação.
5. **Inativar modelo** inativa as variações; inativar uma variação não afeta o modelo. Excluir
   segue a regra atual (produto com histórico não exclui; o modelo só exclui sem variações).
6. **SKU da variação:** `referencia-COR-TAM` gerado (G4), único por empresa como hoje; colisão
   recebe sufixo numérico. Editável.
7. **Limite de lote:** no máximo 200 variações por chamada de matriz (cores × tamanhos), com erro
   claro — protege o banco e a tela.
8. **Multi-tenant:** `ProdutoModelo` com `CompanyScope`; toda validação `exists:` carrega
   `empresa_id` (padrão do `FormularioNotaAvulsa`). Auditoria (`Auditoria`) em criação de matriz,
   "aplicar ao modelo" e inativação em massa.

### 5.3 API (proposta)

| Método | Rota | Função |
|---|---|---|
| GET | `/produto-modelos` | lista agrupada: nome, nº de variações, estoque total, faixa de preço, ativo |
| POST | `/produto-modelos` | cria modelo (+ matriz opcional) |
| GET | `/produto-modelos/{id}` | modelo + variações + matriz de estoque |
| PATCH | `/produto-modelos/{id}` | edita modelo; `aplicar_nas_variacoes: true` propaga padrões |
| POST | `/produto-modelos/{id}/variacoes` | adiciona cores/tamanhos (idempotente) |
| POST | `/produto-modelos/{id}/estoque` | entrada/ajuste em lote por variação (`[{produto_id, quantidade}]`) |
| POST | `/produto-modelos/{id}/inativar` / `reativar` | em massa |
| GET | `/produtos?busca=…&agrupar=1` | busca do PDV devolve modelos com as variações e o saldo de cada |

Permissão: mesma área `produtos` (`RequireArea:produtos`). Rotas de modelo declaradas **antes** de
`/{produto}` onde houver conflito de segmento.

---

## 6. Impacto por área

### 6.1 Emissão de notas (NF-e 55 e NFC-e 65)

| Campo da nota | Como sai com variação | Ação |
|---|---|---|
| `cProd` | `sku` da variação (único) ou `PROD-{id}` | nenhuma — hoje já é assim |
| `xProd` | nome composto; **limite 120 caracteres** | **mudar**: `LimitesDoLayout::texto` corta pelo fim, e cor/tamanho estão no fim. Montar `texto(nome-base, 120 − len(sufixo)) + sufixo` |
| `cEAN`/`cEANTrib` | `codigo_barras` da variação | **mudar**: `gtin()` aceita qualquer 13 dígitos, inclusive o EAN interno de prefixo 2 que o F2 vai gerar. Excluir prefixo 20–29 (sai "SEM GTIN"). A SEFAZ aceitar ou rejeitar esse código **não foi verificado**; excluir é o lado seguro |
| NCM, CEST, origem, CST/CSOSN, alíquotas | do produto (variação), que veio do modelo | nenhuma; a validação "produto sem NCM/CEST/unidade" já nomeia o produto (agora a variação) |
| `qCom`, `vUnCom`, rateio de desconto/frete | por item, igual | nenhuma |
| Estoque da nota avulsa (`EstoqueDaNota`) | por `produto_id` | nenhuma |
| CC-e / cancelamento / inutilização | independem do produto | nenhuma. Observação para o suporte: vender o tamanho errado e perceber depois da autorização **não** se corrige por CC-e (mercadoria diferente); é cancelamento ou devolução — confirmar com o contador |
| Contrato com `nfe-api` | nenhuma mudança: o payload continua `itens[].codigo/descricao/gtin/…` | confirmar com teste de contrato (Fase 2) |

**Risco fiscal residual:** os dados fiscais duplicados em N variações podem divergir (uma
variação com NCM diferente do modelo). Mitigação: aviso na edição, ação "aplicar ao modelo",
e **checagem na emissão** que já nomeia o produto sem NCM. Divergência de NCM entre variações do
mesmo modelo é permitida (existe caso real de mesmo modelo com NCM diferente por composição do
tecido) mas mostrada na tela do modelo como alerta.

### 6.2 Entrada de produtos

**Manual (digitando):** `lancarEstoque` por variação continua; ganha entrada **em matriz** no
modelo (uma tela, todas as quantidades). `EstoqueService::movimentarEmLote` hoje exige
`nota_entrada_id`; ganha variante sem nota (ajuste/entrada manual em lote).

**Por XML do fornecedor:** onde está o risco maior deste plano.

1. **Segunda nota em diante é automática.** Cada variação tem `cProd`/EAN próprios, o de-para por
   código e o EAN já casam, sem tocar no resolvedor.
2. **`cProd` repetido entre tamanhos.** Alguns fornecedores usam a **referência do modelo** como
   `cProd` em todas as linhas e diferenciam só em `xProd`/EAN. Hoje o passo 1 do resolvedor
   (de-para por `cProd`) vincularia **todos os tamanhos à mesma variação** — silenciosamente. E o
   índice `depara_empresa_forn_codigo_unico` impede guardar mais de um produto por `cProd`.
   **Mudar:** (a) dentro de uma mesma nota, `cProd` repetido ⇒ de-para por código é tratado como
   ambíguo e o item cai para EAN/descrição; (b) o índice único passa a incluir
   `descricao_fornecedor`. Teste obrigatório com esse cenário.
3. **Primeira nota de um modelo novo** (o caso mais doloroso, 40 itens ≈ 8 modelos × 5 tamanhos):
   na conferência, nova ação em massa **"Criar grade com os itens selecionados"**: o usuário
   escolhe/nomeia o modelo, o sistema **sugere** cor e tamanho a partir do fim da descrição
   (tamanho conhecido: P/M/G/GG/36…/U; o resto vira cor), mostra uma tabela editável e só então
   cria as variações e vincula os itens. Nunca vincula sozinho.
4. **Fator de conversão** não muda: continua por (fornecedor, código).
5. **Custo** (`CalculadoraDeCusto`) e histórico de preço continuam por produto = variação.
6. **Não há XML de confecção no projeto.** A única nota real é de aviamentos (313 itens,
   `cProd` = EAN-13 em 309). O comportamento real do fornecedor de moda (repete `cProd`? manda
   EAN? põe tamanho em `xProd` ou em campo próprio?) **não foi observado**; a Fase 0 exige
   pelo menos um XML real antes de congelar a Fase 6.

### 6.3 Estoque

- Saldo continua em `produtos.estoque_atual` (por variação). Saldo do modelo = `SUM` em consulta
  (índice `empresa_id, modelo_id`); **não** se guarda total no modelo (evita dado duplicado e
  divergência).
- Venda continua baixando direto no produto; estoque negativo continua permitido na venda.
- Histórico (`estoque_movimentacoes`) por variação; a tela do modelo mostra a matriz e um link
  para a movimentação de cada célula.

### 6.4 PDV, pedido de venda e nota avulsa

- Leitor de código de barras → variação direta (`ProdutoBusca` já resolve Enter com código
  exato). **Sem mudança.**
- Busca por nome: hoje devolve até 10 produtos; um modelo com 30 variações encheria a lista.
  Passa a agrupar: a sugestão mostra o **modelo**, e ao escolher abre a **matriz cor × tamanho
  com o saldo de cada célula**; clicar na célula adiciona a variação ao carrinho. Variações
  sem estoque aparecem esmaecidas mas **vendáveis** (regra atual de estoque negativo).
- Carrinho, desconto, pagamento, NFC-e: inalterados (o item é a variação).

### 6.5 Cadastro e lista

- `ProdutoForm`: escolha no topo "Produto simples" / "Produto com variações" (padrão: simples —
  quem não usa grade não vê diferença). Modo variações: nome, referência, impostos, preço padrão,
  grade pronta ou cores/tamanhos digitados, **pré-visualização da matriz** antes de criar.
- `Produtos`: modelos como linha expansível; simples como hoje; filtros ativo/inativo mantidos.
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
- [ ] Fechar as decisões G1–G11 da §8 (você decide; sem isso a Fase 1 não começa).
- [ ] Obter **ao menos 1 XML real de compra de confecção** (e idealmente 2 fornecedores) e
      guardar em `tests/Fixtures/nfe-entrada/` (sem dados sensíveis, CNPJ/valores anonimizados
      se necessário). Conferir: `cProd` repete? tem `cEAN`? onde está o tamanho?
- [ ] Rodar a suíte do `gestaofacil-api` e anotar o baseline de falhas.
- [ ] Confirmar com o contador: divergência de NCM entre variações; correção de tamanho errado
      pós-autorização (§6.1).
- [ ] Portão: nada a commitar além de fixtures e este plano ajustado → PROGRESS.

### Fase 1 — Modelo de dados e serviço de grade (API)
- [ ] Migrations: `produto_modelos`; `produtos.modelo_id/cor/tamanho` + índice único de
      expressão + índice `(empresa_id, modelo_id)`. `down()` testado.
- [ ] `ProdutoModelo` (CompanyScope, casts, `variacoes()`); `Produto::modelo()` e constante
      `Produto::CAMPOS_HERDADOS`; `ProdutoModeloFactory` e estado de variação na `ProdutoFactory`.
- [ ] `ModeloService`: criar em matriz idempotente, adicionar cor/tamanho, compor nome e SKU,
      propagar padrões, renomear (recompõe nomes), inativar/reativar em massa — tudo em transação.
- [ ] `ProdutoModeloController` + rotas (§5.3, sem a parte de estoque) + validação com
      `empresa_id` nos `exists`, limite de 200 variações, `Auditoria`.
- [ ] Regra: `Produto::buscar`/`index` continuam funcionando; produto simples intocado.
- **Testes (Pest, `tests/Feature/Products/ModeloGradeTest.php` + `tests/Unit`):**
  matriz cria N×M; repetir não duplica nem sobrescreve edição; adicionar tamanho cria só o que falta;
  variação herda NCM/impostos/preço; "aplicar ao modelo" propaga e conta; renomear recompõe nomes;
  SKU gerado único e com sufixo na colisão; limite de 200; **isolamento entre empresas** (modelo e
  variação de outra empresa → 404/422); inativar modelo inativa variações; exclusão bloqueada com
  histórico; índice único impede variação duplicada (cor+tamanho nulos incluídos); permissões por
  perfil; produto simples continua criando e editando como antes.
- [ ] Portão: revisar (`/code-review`, `/simplify`) → testar → commitar → PROGRESS → PLAN-SEGURANCA.

### Fase 2 — Nota fiscal: descrição, código e GTIN
- [ ] `LimitesDoLayout`/`RegrasFiscais`: `xProd` preserva o sufixo cor/tamanho no corte de 120
      (carregar `modelo` por eager load para não gerar N+1 na emissão).
- [ ] `RegrasFiscais::gtin()`: não enviar código de prefixo 20–29 (interno) — "SEM GTIN".
- [ ] Mesmo caminho na nota avulsa (`FormularioNotaAvulsa`) e na venda/NFC-e (`NfeEmissaoService`).
- **Testes:** nome de 150 caracteres com variação mantém "- Azul - GG" no `descricao` enviado e tem
  ≤ 120; produto simples com nome longo continua cortando pelo fim (regressão); `gtin()` com
  EAN real 13 dígitos sai, com `2xxxxxxxxxxxx` não sai, com código curto não sai; payload de
  NFC-e e de NF-e de duas variações do mesmo modelo: `codigo` e `gtin` distintos, mesmo NCM;
  contrato com `nfe-api` (`StoreNfeRequest` aceita o payload) — teste de contrato no `nfe-api`
  se existir suíte equivalente.
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

### Fase 4 — Front: cadastro, lista e estoque
- [ ] Tipos (`Produto` ganha `modelo_id/cor/tamanho`; `ProdutoModelo`), `produtoModeloApi` em
      `services/api.ts`.
- [ ] `ProdutoForm` com modo variações (grades prontas, cores/tamanhos, pré-visualização);
      tela do modelo (matriz de estoque e preço, "aplicar a todas", aviso de variação divergente).
- [ ] `Produtos` agrupada com linha expansível; filtros preservados.
- [ ] `data-testid` novos entram na tabela "Seletores usados pelo E2E" do `gestaofacil-fe/CLAUDE.md`.
- **Testes:** `tsc`/build limpo; regra pura de matriz (gerar combinações, ordenar tamanhos, grade
  pronta) em módulo `utils/` testável isoladamente (checar com o `esbuild` do container, pois não
  há eslint/runner instalado — ver `reference_fe_lint_ausente`); conferência visual no Firefox
  feita por você.
- [ ] Portão completo.

### Fase 5 — Front: PDV, pedido e nota avulsa
- [ ] `GET /produtos?agrupar=1` (API) e `ProdutoBusca` agrupando; componente `GradeSeletor`
      (matriz cor × tamanho com saldo) usado no PDV, `VendaForm` e `NotaForm`.
- [ ] Leitor/Enter com código exato continua indo direto à variação.
- **Testes:** Pest do endpoint agrupado (ordem, saldo, inativos ocultos, empresa); venda no PDV com
  duas variações do mesmo modelo baixa cada saldo; pedido e nota avulsa com variação; regressão do
  PDV com produto simples.
- [ ] Portão completo.

### Fase 6 — Nota de entrada com variações
- [ ] `ResolvedorDeProdutos`: `cProd` repetido na mesma nota ⇒ de-para por código ambíguo;
      migration que inclui `descricao_fornecedor` no índice único do de-para; `LancamentoNotaService`
      grava o de-para por variação.
- [ ] Ação em massa "Criar grade com os itens selecionados" (API em `AcoesEmMassa` + modal em
      `ConferenciaNotaEntrada`): sugere modelo/cor/tamanho, o usuário confirma, cria e vincula.
- [ ] Lançamento cria/atualiza variações e dá entrada por variação.
- **Testes:** com o XML de confecção da Fase 0: (1) 1ª importação cria grade e vincula;
  (2) 2ª importação do mesmo fornecedor vincula tudo sozinha; (3) `cProd` repetido não vincula
  tamanhos diferentes à mesma variação; (4) EAN único por variação casa; (5) EAN duplicado em duas
  variações não vincula (ambíguo); (6) cancelar nota estorna só as variações da nota; (7) fator de
  conversão por variação; (8) sugestão de tamanho/cor: P/M/G/GG/numérico/"U" e descrição sem
  tamanho → sem sugestão, nunca vincula sozinha; regressão: XML de aviamentos (313 itens) com o
  mesmo resultado de antes.
- [ ] Portão completo.

### Fase 7 — Ferramenta opcional: agrupar produtos existentes
Só se o piloto já tiver produtos soltos tipo "Camiseta Azul M".
- [ ] Ação na lista: selecionar produtos → "agrupar em modelo" (define cor/tamanho de cada um, não
      altera estoque nem histórico).
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
      `adicionarPorBusca`/`adicionarPorCodigo` ganham `escolherVariacao(cor, tamanho)`; busca de
      produto simples permanece como está.
- [ ] `pages/NotaEntradaPage.ts`: ação "Criar grade".
- [ ] `helpers/api-helper.ts` e `helpers/dados.ts`: `criarModelo({cores, tamanhos, …})` devolve o
      modelo e as variações (por API); `produtoDeTeste` continua gerando simples.
- [ ] Revisar `produto-cadastro`, `pdv-venda`, `pdv-codigo-barras`, `pedido-venda`,
      `nota-entrada*`, `unicidade-por-empresa`, `rbac-isolamento` e `dashboard` rodando-os
      **antes** de editar nada: só mudar o que falhar por causa da mudança de tela.

**Specs novos** (casos `CT-E2E-106` em diante em `docs/CASOS-DE-TESTE-E2E.md`):
- [ ] `produto-grade.spec.ts` — cria modelo pela tela (grade pronta P–GG × 2 cores), conferir 8
      variações, preço por exceção, repetir criação não duplica, lista agrupada e expansão,
      inativar modelo.
- [ ] `produto-grade-estoque.spec.ts` — entrada em matriz e saldo do modelo; movimentação por
      variação.
- [ ] `pdv-grade.spec.ts` — busca por nome abre a matriz; vende duas variações; saldo de cada
      cai; código de barras da variação entra direto; variação sem estoque é vendável.
- [ ] `nota-entrada-grade.spec.ts` — importa o XML de confecção, "criar grade", lança, confere
      estoque por variação; segunda importação vincula sozinha.
- [ ] `fiscal/nfe-grade.spec.ts` (com `E2E_GATEWAY_FAKE=1 make test-e2e-fiscal`) — venda de duas
      variações: no payload/XML, `cProd` e `xProd` por variação, `xProd` ≤ 120 com sufixo
      preservado, "SEM GTIN" para código interno.
- [ ] `rbac-isolamento`: modelo de outra empresa → 404; vendedor sem área `produtos` não cria
      modelo.
- [ ] Atualizar `PLAN-E2E.md` (estado e contagem), `docs/CASOS-DE-TESTE-E2E.md` (módulo novo e
      matriz de cobertura), `docs/MAPA-SISTEMA.md` e a tabela de seletores.
- [ ] Rodar a suíte inteira em chromium **e** firefox; conferir `nfe_emissoes = 0` ao fim da
      suíte comum (guarda de NFC-e).
- [ ] Portão completo.

### Fase 9 — Fechamento
- [ ] `DATA-MODEL.md` (api e raiz), `REQUISITOS.md`, `PROGRESS.md` (api, fe, raiz).
- [ ] Alinhar `PLAN-PRE-BETA.md` §7/D7 e `PLAN-LANCAMENTO.md` ao que foi decidido (reescrever o
      corpo, não anotar), **mediante sua confirmação**.
- [ ] `PLAN-SEGURANCA.md`: novos checks (isolamento de modelo, limite de lote, `exists` com
      empresa) e registro.
- [ ] Auditoria de realidade (`/auditoria-realidade`) sobre a feature: nada de mock, nada
      "pronto" sem rodar; tela conferida por você no Firefox.
- [ ] Clone limpo + migração do zero (`migrate:fresh`) com a suíte verde.

---

## 8. Decisões abertas

| # | Decisão | Opções | Recomendo |
|---|---|---|---|
| G1 | Onde mora o modelo | tabela `produto_modelos` · `produto_pai_id` em `produtos` | **Tabela própria** — pai em `produtos` seria "produto" vendável sem estoque |
| G2 | Eixos | cor + tamanho fixos · atributos genéricos | **Dois eixos nomeados**; rótulo configurável depois, se aparecer segmento que precise |
| G3 | Dados fiscais | copiar para a variação e propagar do modelo (variação editável com aviso) · ler sempre do modelo | **Copiar + "aplicar ao modelo"**; deixa `TributacaoDoItem`/`RegrasFiscais` intactos. Padrões do modelo em `jsonb` limitado a `Produto::CAMPOS_HERDADOS` (evita 14 colunas duplicadas). *É duplicação de dado — por isso pergunto* |
| G4 | SKU da variação | gerado `REF-COR-TAM` · vazio (usa `PROD-id`) · manual | **Gerado**, editável; exige campo `referencia` (opcional) no modelo |
| G5 | Nome da variação | gravar composto em `produtos.nome` · compor na leitura | **Gravar composto**, mantido pelo sistema; zero mudança nas telas que já mostram `nome` |
| G6 | Preço | padrão no modelo, exceção por variação · um preço só | **Padrão + exceção** |
| G7 | Código de barras | gerar EAN interno na criação · só sob demanda (etiqueta, F2) | **Sob demanda no F2**; sem EAN, a variação vende por busca/matriz. `gtin()` ignora prefixo 2 |
| G8 | Produtos que já existem | ficam simples · migrar automático · ferramenta de agrupar | **Ficam simples**; Fase 7 opcional para agrupar |
| G9 | Plano | `grade` só no Loja já agora · sem flag até o F5 | **Sem flag agora**; liga no F5 por `PlanoService::permite($e,'grade')` |
| G10 | De-para com `cProd` repetido | incluir descrição no índice único · bloquear import | **Incluir descrição** + tratar repetido como ambíguo |
| G11 | Busca no caixa | matriz cor×tamanho · lista plana de variações | **Matriz**; lista plana é o fallback se a Fase 5 apertar |

## 9. Riscos

| Risco | Prob. | Efeito | Mitigação |
|---|---|---|---|
| Fornecedor de moda repete `cProd` entre tamanhos | **alta** | vincula todos os tamanhos a uma variação | Fase 0 (XML real) + G10 + teste dedicado |
| `xProd` perde o tamanho no corte de 120 | média | nota com descrição sem tamanho | Fase 2 + teste |
| EAN interno enviado como GTIN | média | rejeição da nota inteira | `gtin()` exclui prefixo 2; validar em homologação |
| Variações com NCM divergente | baixa | emissão com NCM errado em uma peça | aviso no modelo + "aplicar ao modelo" |
| Lista de produtos lenta/poluída | baixa | UX ruim | lista agrupada + índice `(empresa_id, modelo_id)` |
| Escopo estourar a janela Dez–Jan | média | atraso do beta de moda | corte: Fase 7 sai; depois Fase 6 vira "vincular manual" (sem sugestão); piso = Fases 1–5 |
| Mudança de tela quebrar E2E | média | suíte vermelha | Fase 8 roda a suíte *antes* de editar |

## 10. O que não foi verificado

- Comportamento real de XML de fornecedor de **moda** (só existe o de aviamentos).
- Aceitação, pela SEFAZ, de GTIN com prefixo 2 no `cEAN` (por isso a regra de excluir).
- Se o PDV de loja de moda precisa de leitura de etiqueta com **dois** códigos (modelo + variação).
- Teste de carga com milhares de variações na busca agrupada (esperado trivial; medir na Fase 5).
- Nada deste documento foi executado: é leitura de código e dos planos existentes.
