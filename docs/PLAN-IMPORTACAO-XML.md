# PLAN-IMPORTACAO-XML.md — Importar XML de NF-e, cadastrar produtos e dar entrada no estoque

**Status:** **v3 — implementado nas 5 fases** na branch `feat/importacao-xml` (`gestaofacil-api` e
`gestaofacil-fe`), revisado contra o código em **2026-10-01**. Backend verde: 502 testes passando,
as 7 falhas restantes são a baseline pré-existente (ClienteTest ×2, NaturezaOperacao, NfeEmissao ×4),
sem relação com este plano. **O que ficou faltando e o que precisa de correção está na §13** — leia
a §13 antes de considerar a feature entregue.

**Documentos relacionados:** [`PLAN-API.md`](./PLAN-API.md) · [`PLAN-UI.md`](./PLAN-UI.md) · [`DATA-MODEL.md`](./DATA-MODEL.md) · [`REQUISITOS.md`](./REQUISITOS.md) · [`PLAN-DISTDFE.md`](./PLAN-DISTDFE.md) (continuação: buscar as notas na SEFAZ em vez de receber o XML do fornecedor)

> **O que mudou da v1 para a v2:** a análise de um XML real de compra (313 itens, seção 3.1)
> derrubou duas suposições minhas e fechou o D1. Todas as decisões viraram regra; o que a
> revisão posterior fechou está na seção 12. **Da v2 para a v3:** nada de decisão mudou — o
> checklist da §10 foi marcado contra o código e a §13 registra as lacunas encontradas.

---

## 1. O que este plano resolve

Hoje o produto entra digitado à mão (`ProdutoForm.tsx`) e o estoque sobe num modal com
quantidade inteira. Quem recebe a nota real analisada aqui — **313 itens** — digitaria 313
produtos.

Três coisas, nessa ordem de dependência:

1. **Ler o XML da nota de compra** (a que o fornecedor emitiu contra o seu CNPJ) e virar
   uma tela de conferência: cada item já ligado a um produto seu, ou como produto novo
   pré-preenchido.
2. **Dar entrada no estoque** a partir dessa conferência, num lançamento só, com rastro até
   a nota e estorno se lançar errado.
3. **Converter unidade de compra em unidade de venda**: 1 PCT `C/100` entra 100 UN;
   1 ROL `20MT` entra 20 m, para vender 2,5 m depois.

---

## 2. O que já existe (verificado no código)

| Peça | Onde | Situação |
|---|---|---|
| Produto com campos fiscais | `app/Models/Produto.php`, migrations `...000007`, `2026_09_21_000001`, `2026_09_22_000001` | nome, sku, codigo_barras, ncm, unidade, preco_compra, preco_venda, origem_icms, origem_fabricacao, tem_substituicao_tributaria |
| Movimentação de estoque | `app/Services/EstoqueService.php`, `app/Models/EstoqueMovimentacao.php` | `lancar()`/`estornar()`/`listarMovimentacoes()`, tipos entrada/saida/ajuste, `venda_id` opcional |
| Baixa por nota avulsa | `app/Services/Nfe/EstoqueDaNota.php` | precedente de idempotência: flag trocada condicionalmente no banco |
| Multitenancy | `app/Models/Scopes/CompanyScope.php` + middleware `enscope-to-company` (`routes/api.php:58`) | todo model novo entra nesse padrão |
| Cadastro de cliente | `app/Http/Controllers/ClienteController.php`, `src/pages/ClienteForm.tsx`, `src/services/cep.ts` | tem `ie`, `indicador_ie`, `codigo_municipio`, endereço + busca de CEP — base para reusar no fornecedor |
| Busca de produto | `src/components/ProdutoBusca.tsx` | reaproveitável na conferência |

**O que não existe:** parser de XML na `gestaofacil-api` (`grep -rn "simplexml\|DOMDocument" app` → zero),
fornecedor (`grep -rn -i fornecedor` → zero), nota de entrada. A `nfe-api` só **emite**; ler
XML de terceiro é assunto da `gestaofacil-api`.

---

## 3. Evidência: o que os XMLs reais provaram

### 3.1 A nota de compra real — 313 itens medidos item a item

`~/Downloads/35260810730088000231550010000562991715417711.xml`
NF-e mod 55, **produção** (`tpAmb=1`), Roma Importadora de Aviamentos e Armarinhos Ltda (SP, `CRT=3`)
→ Artesanatos Timbaubense (PE), CFOP 6102 em todos os itens, R$ 7.269,42, 377 KB.

| Medição | Resultado | Consequência no plano |
|---|---|---|
| `uCom` vs `uTrib` | **iguais em 313/313** | **O XML não traz fator de conversão.** Deduzir de `qTrib÷qCom` não funciona com fornecedor real — era a minha ideia da v1, está morta como caminho principal |
| fator na descrição | `C/100`, `C/50PC` em 179 (57%); `20MT`, `15Y` em 72 (23%); `500G/600UN` e afins no resto | O fator é texto livre em `xProd` → cabe **sugeridor por regex** (§7.3); cobertura **medida: 87,2% (273/313)** |
| `cEAN` | `SEM GTIN` em **132/313 (42%)** | casar por EAN resolve pouco mais da metade |
| `cProd` | 13 dígitos em 313/313, **EAN-13 válido em 309** | o fornecedor põe o GTIN no `cProd` → casar `cProd` contra `codigo_barras` também, não só contra `sku` |
| `vDesc` | em **295/313**, somando 30,6% do `vProd` | desconto é a regra, não a exceção; custo sem desconto erra feio |
| unidades | `CAR, CX, KIT, PAR, PC, PCT, ROL, UN` | **4 delas são rejeitadas pela validação de hoje** (`in:UN,KG,LT,CX,PCT,PC`) |
| totais | `vProd − vDesc + vIPI` = 7.269,43 vs `vNF` = **7.269,42** | 1 centavo de arredondamento numa nota legítima → **validar totais exige tolerância**, senão todo mundo vê aviso falso |
| impostos | `ICMS00` em 313, `IPITrib` em 195 (R$ 353,19 = 5,11% da base), sem ST, `CEST` vazio em 313 | o cálculo de custo tem que ler ICMS normal **e** `ICMSSN*`; ST existe no layout mas não nesta nota |
| `vUnCom` | até 3 casas significativas | `decimal(15,4)` em `preco_compra` (D7) cobre com folga |
| `cProd` repetido | nenhum | item duplicado na mesma nota é defensivo, não regra |

> **Reproduzido em teste (2026-10-01):** 313 itens, `uCom==uTrib` em 313, 132 sem GTIN, 309 `cProd`
> EAN-13 válidos, 295 com desconto, sugeridor de fator em **273/313 = 87,2%**. Todos os números
> desta tabela saem verdes de `tests/Unit/Compras/`.

**Os seus dois exemplos, com os números reais da nota:**

```
ETIQUETA COURO HANDMADE C/100   PCT  1 × R$ 21,00 − R$ 8,40 = R$ 12,60 ÷ 100 = R$ 0,1260/un
ALCA CHIC RO.153075 2.2CM 20MT  ROL  1 × R$ 14,30 − R$ 5,72 = R$  8,58 ÷  20 = R$ 0,4290/metro
```

Ignorando desconto e fator, a etiqueta entraria com custo R$ 21,00 em vez de R$ 0,1260 —
**166× errado, e silencioso.** Com 2 decimais em vez de 4, R$ 0,1260 viraria R$ 0,13 (+3,2%).

### 3.2 Os dois XMLs de venda própria = teste negativo

`26260911500611000115650030000000031529430910-nfe.xml` (NFC-e mod 65) e
`~/Downloads/26260911500611000115550010000000051014219835-nfe.xml` (mod 55; o de mod 65 estava
também na raiz do projeto; saiu de lá em 18/10/2026 e fica em `../nfe-xml-privados/`, fora do repositório, até virar fixture anonimizada): nos dois,
`emit/CNPJ = 11500611000115` com `tpNF=1` e `verProc=NFe API` — **notas emitidas pela própria
empresa**, em homologação. Viram fixture de rejeição. O de mod 65 **não tem bloco `dest`**,
o que importa para a regra do D6.

Deles sai também o layout confirmado: raiz `nfeProc` envolvendo `NFe`, namespace
`http://www.portalfiscal.inf.br/nfe`, `qCom` com 4 decimais, `vUnCom` com 10,
emitente Simples (`CRT=1`) usando `ICMS/ICMSSN102` com `CSOSN` em vez de `ICMS00`.

### 3.3 O fluxo do Bling, conferido na documentação oficial

Do vídeo que você passou (`youtube.com/watch?v=7PqMWG3QBXY`, *"Como inserir notas de entrada
no Bling — XML"*) **eu não consigo extrair nada**: só recebo o HTML da página, sem
transcrição. O que está aqui vem da Central de Ajuda deles.

Caminho: `Estoque > Notas fiscais de entrada > Importar – XML NFe` → assistente: importar →
*visualizar* ou *conciliar produtos* → **Avançar** → conciliação → marcar *Lançar Estoque* /
*Lançar Contas* → salvar.

**A ordem de vínculo automático deles** — a mesma que este plano usa em §7.2:
1. produto já vinculado **para aquele mesmo fornecedor** numa nota anterior
2. fornecedor + descrição do catálogo do fornecedor no cadastro do produto
3. mesmo SKU **ou** descrição, conforme configuração da empresa

Busca manual por SKU, GTIN, GTIN tributário ou nome. Atualização de dados do produto pela
nota é configurável campo a campo, e a regra do GTIN é *"só preenche se estiver vazio"* — virou D10.

**O que o Bling tem e não cabe aqui:** pedido de compra, *Lançar Contas* (não temos
financeiro no v1), **o próprio checkbox *Lançar Estoque*** (ver §7.5: sem financeiro nem
escrituração, nota que não mexe em estoque não tem função aqui), depósitos múltiplos,
conciliação de variações, importação em lote, busca/manifestação na SEFAZ. Os dois últimos são o próximo passo natural (§11).

Fontes: [importar XML de nota de entrada](https://ajuda.bling.com.br/hc/pt-br/articles/360036460513-Como-importar-o-XML-de-nota-de-entrada) · [conciliar produtos com o estoque](https://ajuda.bling.com.br/hc/pt-br/articles/360044990973-Como-conciliar-os-produtos-da-nota-com-produtos-do-meu-estoque) · [atualizar dados do produto pela nota](https://ajuda.bling.com.br/hc/pt-br/articles/20296610658071-Como-atualizar-automaticamente-os-dados-do-produto-atrav%C3%A9s-da-nota) · [notas de entrada da SEFAZ](https://ajuda.bling.com.br/hc/pt-br/articles/360057118174-Como-consultar-manifestar-e-importar-as-notas-de-entrada-da-SEFAZ)

---

## 4. Decisões fechadas

### D1 — Conversão de unidade: fator só na tela, nunca no cadastro do produto ✅

**Decidido:** o produto guarda **só a unidade de venda/estoque** (`M` para a alça, `UN` para a
etiqueta). O fator é escolhido na **tela de conversão da conferência** e gravado no de-para
`produto_fornecedor_codigos`. **Não** existe `unidade_compra` nem `fator_conversao` em `produtos`.

**Por quê (dados da §3.1):** o fator não é propriedade do produto, é da *embalagem daquele
fornecedor*. "ALCA CHIC BRANCO" se vende em metro; o fator 20 pertence ao rolo da Roma.
Outro fornecedor manda rolo de 50 e o mesmo produto teria outro fator — um campo no produto
obrigaria a eleger um fornecedor como "o certo".

Modelo descartado (opção B da v1): produto pai/filho com operação "desmembrar" explícita,
que permitiria vender a caixa fechada e saber quantas estão fechadas. **Fora de escopo**;
se aparecer a necessidade, nasce como fase própria e o de-para já é o pré-requisito dela.

Entrada manual sem XML ("recebi 3 rolos") sai do mesmo de-para: a tela oferece "entrada pela
embalagem do fornecedor X" usando o fator já gravado. Não precisa de campo no produto.

### D2 — Estoque decimal ✅ obrigatório para "vendo no metro"

`decimal(15,4)` (4 decimais = o que a NF-e aceita em `qCom`) em quatro colunas hoje `integer`.
Isso **já é bug latente**: `UNIDADES` no FE oferece `KG` e `LT` (`src/types/index.ts:58`) e
você não consegue ter 1,5 kg.

Raio de alcance completo, por grep — é a Fase 1 inteira e o trecho mais arriscado do plano,
porque mexe em venda e PDV que já funcionam:

- migrations: `..._000007_create_produtos_table.php:33` (`estoque_atual`), `..._000008_create_estoque_movimentacoes_table.php:23`, `..._000009_create_venda_itens_table.php:20`, `..._000014_create_pdv_venda_itens_table.php:20` → **1 migration nova** alterando as 4 colunas (não editar migration antiga)
- casts: `EstoqueMovimentacao.php:29`, `VendaItem.php:26`, `PdvVendaItem.php:26`, `Produto.php:37`
- assinaturas `int $quantidade`: `EstoqueService.php:20` e `:63`; `Produto::temEstoque(int)` em `Produto.php:90`; **`VendaService.php:54`, `PdvVendaService.php:260` e `ValoresDoItem::calcular(int ...)` em `ValoresDoItem.php:24`** (esta calcula subtotal e desconto em centavos: é onde mora a regra de arredondamento). Se ficarem `int`, venda fracionada quebra com `TypeError`, não com erro de validação
- validações `integer`: `ProdutoController.php:57` (`estoque_atual` na criação), `:173` e `:205`, `VendaController.php:90`, `PdvVendaController.php:108` e `:183`, `Services/Nfe/FormularioNotaAvulsa.php:346`. (`transporte.volumes.*.quantidade` continua inteiro: é volume de transporte, outra coisa)
- a `nfe-api` **já aceita** quantidade fracionada (`StoreNfeRequest.php:97` é `numeric`): a emissão não precisa mudar
- o `down()` da migration volta para `integer` e **trunca decimais**: depois do primeiro lançamento fracionado o rollback perde dado
- `(int) $item['quantidade']` em `Services/Nfe/EstoqueDaNota.php` (`quantidadesPorProduto`)
- FE: `parseInt`/`step="1"` em `ProdutoForm.tsx:248,275`; `parseInt` em `VendaDetalhe.tsx:295`; **`utils/notaFiscal.ts:459`**, que hoje valida literalmente `A quantidade deve ser inteira.`; `useCarrinho.ts:16` multiplica quantidade por centavos (revisar arredondamento)

Regra de ouro: quantidade fracionada × preço arredonda para 2 casas no subtotal, com uma
regra só. `useCarrinho` já trabalha em centavos — manter esse estilo e **não** introduzir
`float` em dinheiro. O `step` do input passa a depender da unidade (UN inteiro, M/KG fracionado).

### D3 — Tabela `fornecedores` nova (não `tipo` em `clientes`) ✅

Decidido pela opção (b): entidade própria, **zero risco** para os 5 consumidores de
`clienteApi` no FE (`ClienteBusca`, `ClienteRapidoModal`, `nota/DestinatarioNota`, `PDV`,
`VendaForm`), que não precisam aprender a filtrar.

**No FE, reusar o que der** (sua instrução): os campos de endereço + busca de CEP
(`src/services/cep.ts`) saem de `ClienteForm.tsx` para um componente compartilhado, e
`Table`/`PageHeader`/`Pagination` já são genéricos. O schema de `fornecedores` **espelha de
propósito os nomes de coluna de `clientes`** para esse componente servir aos dois sem adaptador.

**Criação:** na importação, se o CNPJ não existir, cria com o que vem no `emit` do XML.
Consequência aceita: importação cancelada deixa o fornecedor cadastrado — é entrada de
catálogo, inofensiva. O de-para passa a chavear `fornecedor_id`, não CNPJ solto.

### D4 — Whitelist de unidades ampliada ✅

`ProdutoController.php:56` (criação) e `:104` (edição) validam `in:UN,KG,LT,CX,PCT,PC`. A nota real usa `CAR, KIT, PAR, ROL`
— **quatro unidades que seriam rejeitadas hoje**, barrando a importação.

Lista nova: `UN, PC, PCT, CX, CAR, KIT, PAR, ROL, DZ, FD, SC, KG, G, TON, LT, ML, M, M2, M3, CM, MIL`.
Normalização na entrada: `MT`/`MTS`/`MTR`/`METRO`→`M`, `UNID`/`UND`/`PÇ`/`PEÇA`/`PECA`→`UN`,
`LTA`/`LTS`/`LITRO`→`LT`, `ROLO`/`RL`→`ROL`.
*(Implementado em `app/Support/Unidades.php`. `RL` saiu da lista canônica — era redundante com
`ROL` e virou sinônimo.)*
O `uCom` original do XML continua gravado no item da nota, para conferência.

### D5 — Preço de compra: valor da NF por padrão, custo composto por checkbox ✅

**Decidido:** `preco_compra` recebe o **valor de compra da própria NF**, e a tela tem um
**checkbox "aplicar cálculo de custo"** que, marcado, recalcula **todos os itens** com a
composição completa, mostrando a conta. O motivo é multiempresa: a regra de custo muda de
empresa para empresa, então é escolha do usuário, não constante do código.

```
checkbox DESMARCADO (padrão):  preco_compra = (vProd − vDesc) ÷ quantidade_estoque
checkbox MARCADO:              preco_compra = (vProd − vDesc + vFrete + vSeg + vOutro + vICMSST + vIPI) ÷ quantidade_estoque
```

Frete, seguro e outros que vierem só no total da nota são rateados proporcionalmente ao
`vProd` de cada item. A escolha fica gravada em `notas_entrada.custo_composto`, então dá
para saber depois como aquela nota foi custeada. O valor segue **editável linha a linha**
depois do recálculo.

**Confirmado:** o checkbox nasce **desmarcado**, e o padrão desconta o `vDesc` — desconto é
preço de compra de fato, é o que foi pago. Na nota real o desconto é 30,6%: a etiqueta
`C/100` fica R$ 0,1260/un; sem descontar daria R$ 0,2100 (+67%).

Na nota real, o checkbox marcado muda pouco: frete e ST são zero e o IPI é R$ 353,19 =
**5,11%** da base. É esse o tamanho da diferença entre as duas opções nessa nota.

As colunas de frete/seguro/outros/ST/IPI são **sempre gravadas** no item, marcadas ou não —
vêm de graça no XML e permitem recustear depois sem reimportar.

**Último custo, não custo médio:** o valor substitui o anterior. Custo médio exige saldo
valorizado, é outro projeto (§11).

### D6 — Destinatário diferente da empresa: aviso forte com aceite registrado ✅

Uma regra só, uma mensagem só: **sempre que o destinatário da nota não for a empresa atual**,
aviso forte e o usuário prossegue aceitando. Sem texto especial para nota própria.

**De onde sai o CNPJ para comparar:** `empresas.cnpj` — coluna local, `char(14)`, `unique`
(migration `..._000001_create_empresas_table.php:18`). **Não** usar `EstadoDoCertificado`,
que faz chamada HTTP à `nfe-api` e devolve `null` quando não há certificado: a importação
de XML não precisa de certificado nenhum para funcionar.

Leitura que fecha o caso do seu NFC-e: **nota sem bloco `dest` também dispara o aviso**
(§3.2 — o mod 65 não tem `dest`), porque o destinatário não é a empresa. Cobre os três
casos com uma regra.

**Onde o aviso aparece e onde o aceite é gravado** (a v2 estava inconsistente aqui): o aviso
é **mostrado duas vezes** — na tela de importação, assim que o XML é lido, e de novo no resumo
de confirmação do "Lançar". O **aceite é gravado no lançamento**, não na importação, porque
lançar é o ato irreversível — importar para rascunho não muda nada (§7.5). Fica em
`notas_entrada.avisos`: qual aviso, quem aceitou, quando.

Também avisam, sem bloquear: `tpAmb=2` (homologação), `protNFe/cStat ≠ 100`,
soma dos itens fora do `vNF` **além da tolerância de centavos** (§3.1).

### D7 — `preco_compra` para `decimal(15,4)` ✅

Validado com dado real: o custo convertido R$ 0,1260 com 2 decimais vira R$ 0,13, erro de
3,2%. Mexe em `produtos`, no cast e no `MoneyInput` do FE.

### D8 — `estoque_movimentacoes` ganha `nota_entrada_id` ✅

Nullable, FK, no mesmo estilo do `venda_id` que já existe. É o que permite cancelar a nota
inteira e mostrar "veio da NF 56299 da Roma Aviamentos" no histórico do produto.

### D9 — Preço de venda editável na conferência, nunca automático ✅

A conferência mostra `preço de venda` em toda linha:
- **produto existente:** vem com o preço atual preenchido, editável, com o valor anterior
  visível ao lado ("era R$ 30,00")
- **produto novo:** vem **vazio**, o usuário digita

Só grava as linhas onde o valor **realmente mudou** (dirty tracking), para edição acidental
não virar mudança de preço silenciosa.

`produtos.preco_venda` é NOT NULL e validado `required|min:0.01` (`ProdutoController.php:54`),
então **o botão "Lançar" fica desabilitado enquanto existir produto novo sem preço**.

~~Lacuna conhecida, registrada e fora de escopo: não existe histórico de preço no sistema, então
alteração por aqui não deixa rastro.~~ **Resolvido fora do plano:** a implementação acabou criando
`produto_preco_historico` + `App\Services\RegistradorDePreco`, e a tela
`MovimentacaoProduto.tsx` mostra estoque e preço com link para a nota de origem. Era "fora de
escopo" aqui e virou feature própria — registrado para o plano não mentir sobre o que existe.

### D10 — Que campos de produto já cadastrado a nota pode atualizar ✅

Regra "só preenche se estiver vazio", sem tela de configuração: `codigo_barras` (de `cEAN`,
ou de `cProd` quando passa o dígito verificador EAN-13 — 309/313 na nota real), `ncm`,
`origem_icms`. (`cest` fica de fora: `produtos` não tem a coluna e a nota real traz `CEST` vazio
nos 313 itens; se um dia for necessário, é campo novo e decisão própria.)
`preco_compra` **sempre** atualiza (D5, último custo).
**Nunca** atualiza: `nome`, `unidade`, `sku`. E `preco_venda` só pela mão do usuário (D9).
A descrição do fornecedor fica no de-para (`descricao_fornecedor`), para conferir sem sobrescrever.

### D11 — Nota duplicada: bloqueia ✅ *(novo)*

**Lançar a mesma nota duas vezes não é permitido** — avisa que a NF já foi lançada. Diferente
do D6: aqui é **bloqueio**, não aviso.

Três camadas, porque cada uma pega um erro diferente:

1. **No upload:** `chave` já existente na empresa → recusa com HTTP 409, dizendo o status da
   nota que já está lá e oferecendo abri-la ("essa NF já foi importada e está em conferência"
   / "já foi lançada em 01/10/2026").
2. **No banco:** índice **unique parcial** `(empresa_id, chave)` *where* `status in
   ('rascunho','lancado')`. Parcial porque nota **cancelada** precisa poder ser reimportada —
   foi justamente para refazer que você cancelou.
3. **No lançamento:** o `UPDATE ... WHERE status = 'rascunho'` condicional (padrão do
   `EstoqueDaNota`) garante que dois cliques no botão não lancem duas vezes.

Chave igual em **empresas diferentes** é permitida — escopo por empresa (§5).

---

## 5. Multiempresa — regra transversal

Tudo é atrelado à empresa, sem exceção:

- as 4 tabelas novas (`fornecedores`, `notas_entrada`, `nota_entrada_itens`,
  `produto_fornecedor_codigos`) têm `empresa_id` e `CompanyScope` no model
- **unicidade sempre escopada:** `unique(empresa_id, chave)` parcial em `notas_entrada` (D11),
  `unique(empresa_id, cpf_cnpj)` em `fornecedores`,
  `unique(empresa_id, fornecedor_id, codigo_fornecedor)` no de-para. O mesmo CNPJ pode ser
  fornecedor de duas empresas = duas linhas; a mesma NF pode chegar para duas empresas
- **o de-para não vaza entre empresas:** o fator que a empresa A ensinou não aparece para a B
- XML guardado em `storage/app/notas-entrada/{empresa_id}/{chave}-{nota_id}.xml`, nome derivado
  da chave validada (44 dígitos) **mais o id da nota**, **nunca** do nome do arquivo enviado.
  O id entra porque uma nota cancelada pode ser reimportada (D11) e só a chave faria o
  segundo arquivo sobrescrever o primeiro, apagando a evidência da importação anterior
- rotas no grupo `auth:sanctum` + `enscope-to-company` que já existe (`routes/api.php:58`)
- **teste de isolamento obrigatório em cada endpoint**: empresa B não lista, não lê, não
  altera e não lança nota da empresa A (§9)

---

## 6. Modelo de dados

### 6.1 `fornecedores` *(D3 — nomes de coluna espelhando `clientes` de propósito)*
```
id, empresa_id
cpf_cnpj      varchar(14)   -- emit/CNPJ, ou CPF (produtor rural)
nome                        -- xNome
nome_fantasia               -- xFant
ie, crt
telefone, email
rua, numero, complemento, bairro, cidade, estado, cep (char(8), só dígitos), codigo_municipio
ativo         boolean default true
timestamps
unique(empresa_id, cpf_cnpj) · index(empresa_id, ativo) · index(empresa_id, nome)
```

### 6.2 `notas_entrada`
```
id, empresa_id, fornecedor_id (FK)
chave          char(44)
modelo         smallint      -- 55
numero, serie
dh_emissao     timestamptz   -- filtro da listagem
valor_produtos, valor_desconto, valor_frete, valor_seguro, valor_outros,
valor_st, valor_ipi, valor_total        decimal(15,2)
custo_composto boolean default false    -- D5: como esta nota foi custeada
status         varchar       -- rascunho | lancado | cancelado   (D12)
xml_path       varchar
avisos         jsonb         -- aviso, quem aceitou, quando (D6)
criado_por     FK users      -- quem subiu o XML
lancado_em, lancado_por      -- em nota cancelada, `lancado_em` preenchido é o que diz
                             -- que ela chegou a mexer no estoque antes de ser cancelada
cancelado_em, cancelado_por
timestamps
unique parcial (empresa_id, chave) where status in ('rascunho','lancado')   -- D11
index(empresa_id, status) · index(empresa_id, dh_emissao)
```

### 6.3 `nota_entrada_itens`
```
id, nota_entrada_id (cascade), empresa_id
n_item             smallint      -- det/@nItem
codigo_fornecedor  varchar       -- cProd
ean                varchar       -- cEAN (ignora "SEM GTIN")
descricao          varchar       -- xProd (máx. observado: 86 chars)
ncm, cest, cfop, origem_icms
unidade_xml        varchar       -- uCom original, sem normalizar
quantidade_xml     decimal(15,4) -- qCom
valor_unitario     decimal(15,10)-- vUnCom
unidade_trib, quantidade_trib    -- uTrib/qTrib (iguais a uCom/qCom na nota real)
valor_produto, valor_desconto, valor_frete, valor_seguro, valor_outros, valor_st, valor_ipi
-- resultado da conferência:
produto_id         FK nullable
acao               varchar       -- vincular | criar | ignorar
origem_vinculo     varchar       -- de_para | de_para_descricao | ean | cprod_ean | sku | manual | novo
fator_conversao    decimal(15,6) default 1
fator_sugerido     decimal(15,6) nullable
fator_origem       varchar       -- de_para | descricao | xml_qtrib | unidade_igual | manual
trecho_sugestao    varchar       -- "C/100", "20MT" — o texto que gerou a sugestão (§7.3)
quantidade_estoque decimal(15,4) -- quantidade_xml × fator
preco_compra_calc  decimal(15,4) -- D5, editável
produto_novo       jsonb         -- rascunho do produto a criar: nome, unidade, preco_venda
preco_venda_novo   decimal(15,2) nullable  -- edição pendente de preço de produto existente (D9)
index(nota_entrada_id) · index(empresa_id, produto_id)
```
`produto_novo` e `preco_venda_novo` existem porque **nada é criado até o "Lançar"** (§7.5):
é onde o trabalho de conferência mora enquanto a nota é rascunho.

### 6.4 `produto_fornecedor_codigos` — o de-para que carrega o fator (D1)
```
id, empresa_id, produto_id (cascade), fornecedor_id (FK)
codigo_fornecedor    varchar       -- cProd
unidade_fornecedor   varchar       -- PCT, ROL
fator_conversao      decimal(15,6) -- 100 (PCT C/100), 20 (ROL 20MT)
descricao_fornecedor varchar       -- também é chave de casamento (§7.2 passo 2)
timestamps
unique(empresa_id, fornecedor_id, codigo_fornecedor)
index(empresa_id, fornecedor_id, descricao_fornecedor)
```
É a memória do sistema: a 1ª importação dessa nota são 313 decisões, a 2ª é ≈ zero.

### 6.5 Alterações em tabelas existentes
- `produtos`: `estoque_atual` → `decimal(15,4)` (D2); `preco_compra` → `decimal(15,4)` (D7).
  **Nenhum campo novo** — sem `unidade_compra`, sem `fator_conversao` (D1)
- `estoque_movimentacoes`: `quantidade` → `decimal(15,4)` (D2); `+ nota_entrada_id` nullable (D8)
- `venda_itens` / `pdv_venda_itens`: `quantidade` → `decimal(15,4)` (D2)

---

## 7. Como funciona

### 7.1 Leitura do XML — `app/Services/Compras/LeitorXmlNfe.php`

Classe sem banco: recebe string, devolve DTO. Testável sozinha.

- aceita raiz `nfeProc` **ou** `NFe` nua; XPath registrando o namespace `http://www.portalfiscal.inf.br/nfe`
- **XXE:** recusa o arquivo se contiver `<!DOCTYPE`/`<!ENTITY` antes de parsear;
  `libxml_use_internal_errors(true)`; parse com `LIBXML_NONET | LIBXML_NOCDATA` e **sem**
  `LIBXML_NOENT`/`LIBXML_DTDLOAD`; upload de 1 arquivo, mime xml/text, **até 2 MB**
  (a nota real tem 377 KB com 313 itens, então 2 MB sobra)
- extrai `ide`, `emit` completo, `dest/CNPJ` (ou a ausência dele), `det/prod` + `det/imposto`
  lendo **`ICMS00/10/60` e `ICMSSN*`**, `IPITrib`/`IPINT`, ST, `total/ICMSTot`, `protNFe/cStat`
- **não valida assinatura digital** — é nota de terceiro, a assinatura é do fornecedor; o que
  protege contra nota inventada é o `cStat` e o olho de quem confere. Decisão consciente.

### 7.2 Casamento com produtos — `ResolvedorDeProdutos`

Por item, para no primeiro acerto:
1. de-para por **código** (`fornecedor_id` + `cProd`) → traz o fator junto
2. de-para por **descrição do fornecedor** (`fornecedor_id` + `descricao_fornecedor`), para
   fornecedor que troca o `cProd` entre notas
3. `cEAN` = `produtos.codigo_barras` (ignora `SEM GTIN` — 42% dos itens reais).
   `codigo_barras` **não é único** no banco: se casar com **mais de um** produto, não vincula.
   **Desvio do implementado:** `cEANTrib` não é lido, e o item ambíguo cai em `criar` sem guardar
   os candidatos como dica — não existe estado "pendente" (§13.1)
4. **`cProd` = `produtos.codigo_barras`**, quando `cProd` passa o dígito verificador EAN-13
   (309/313 na nota real: o fornecedor põe o GTIN no `cProd` e declara "SEM GTIN")
5. `cProd` = `produtos.sku`
6. nada → `acao = criar`, produto novo pré-preenchido: nome `xProd`, `ncm`, `codigo_barras` (de `cEAN`, ou de `cProd` quando passa o EAN-13; vazio se nenhum), **`sku` vazio** (`unique(empresa_id, sku)` e o `cProd` é código do fornecedor, não seu), unidade
   normalizada de `uCom`, `origem_icms` de `ICMS/*/orig`, `tem_substituicao_tributaria` se
   houver ST, `preco_compra` calculado (D5)
7. ~~semelhança de nome (NCM igual + nome parecido) entra como **dica** na tela, **nunca vincula**~~ — **não implementado** (§13.1)

**Diferença proposital em relação ao Bling:** lá, casar por descrição solta contra o próprio
cadastro é opção de configuração. Aqui fica só como dica (passo 7) — dois produtos seus com
nome parecido vinculados errado desaparecem no meio de 313 itens e só aparecem no inventário.
Descrição **do fornecedor já confirmada por você uma vez** (passo 2) é outra coisa: essa vincula.

Ao lançar, todo vínculo confirmado **grava/atualiza o de-para** com código, descrição, unidade
e fator.

### 7.3 Fator de conversão — a tela de conversão (D1)

O fator vem, em ordem de confiança:
1. **do de-para** daquele fornecedor (já ensinado numa nota anterior)
2. **sugerido pela descrição** — `SugeridorDeFator`, regex sobre `xProd`:
   `C/100`, `C/50PC` → 100, 50 · `20MT`, `15Y` → 20, 15 · `500G/600UN` → 600 · `X50` → 50.
   **medido em 87,2% (273/313)** dos itens reais (padrões `C/n`, `X n`, `n UN`, `nMT`, `nM`, `nY`); os ~13% restantes são itens vendidos a peso (`500G`) ou peça solta, sem fator por regex — vão no manual. A tela mostra **o trecho que casou** (`trecho_sugestao`) para você
   confirmar de olho em vez de digitar
3. `qTrib ÷ qCom`, se `uTrib ≠ uCom` — **0 itens na nota real**, fica só para fornecedor que preenche
4. `1`, se as unidades batem
5. digitado — e o que for digitado vai para o de-para no lançamento

A linha da conferência, então:

`PCT (do XML, travado)` → `UN (unidade do produto)` → `fator 100` → `= 100 UN` → `custo R$ 0,1260`

**Assimetria deliberada:** produto **novo** tem a unidade escolhida ali (vira a `unidade` do
cadastro); produto **existente** mostra a unidade do cadastro travada e pede só o fator,
porque D10 proíbe a importação de mexer na unidade. Trocar unidade de produto existente é
edição de cadastro, não importação.

`quantidade_estoque = quantidade_xml × fator` e `preco_compra = valor_do_item ÷ quantidade_estoque`.

### 7.4 Custo (D5)

Checkbox na tela, aplicando a todos os itens, recalculável à vontade antes de lançar:
desmarcado = `(vProd − vDesc) ÷ quantidade_estoque`; marcado = soma frete, seguro, outros,
ST e IPI, rateando proporcionalmente ao `vProd` o que vier só no total da nota. A conta fica
visível na linha. O valor segue editável item a item. A escolha é gravada em `custo_composto`.

### 7.5 Estados, draft e lançamento

**Três estados, dois verbos** (`lancar` e `cancelar`). O que importa em cada estado é o que já
aconteceu no banco:

| Estado | Produtos criados? | Estoque mexido? | Vai para |
|---|---|---|---|
| `rascunho` | não | não | `lancado`, `cancelado` |
| `lancado` | sim | sim | `cancelado` |
| `cancelado` | os que já existiam ficam | desfeito, se houve | — (chave liberada, D11) |

```
importar → rascunho ─┬─ lancar   ─> lancado
                     └─ cancelar ─> cancelado

           lancado ─── cancelar ─> cancelado   (reverte o estoque automaticamente)
```

**Nota que não é mercadoria de revenda** (material de consumo, uma impressora, embalagem de uso
próprio) não precisa de estado próprio: marca-se os itens como `ignorar` (§6.3) e lança. Zero
produto criado, zero movimentação, nota arquivada com fornecedor e XML. Um estado "só
arquivada" seria o checkbox *Lançar Estoque* do Bling, que faz sentido lá porque a nota
alimenta financeiro e escrituração — aqui não há nem um nem outro no v1, e ele colidiria com o
D9 (produto novo exige `preco_venda`: arquivar a nota da impressora pediria preço de venda
para a impressora).

**O draft é o coração do fluxo (seu pedido):** importar grava nota + 313 itens em `rascunho` e
**não toca em `produtos` nem em `estoque`**. Cada linha salva sozinha ao sair do campo
(autosave por item via `PATCH`, com indicador "rascunho salvo"), em vez de um botão "salvar
rascunho" que dá para esquecer. Fechar o navegador no meio não perde nada: o produto novo
digitado está em `produto_novo`, o preço editado em `preco_venda_novo`, o fator em
`fator_conversao`. Dá para voltar dias depois e continuar.

`POST /lancar` em **uma transação**: cria os produtos de `produto_novo`, aplica os
`preco_venda_novo` que mudaram, grava o de-para, lança a entrada por item
(tipo `entrada`, `nota_entrada_id`, motivo `"NF-e 56299 — Roma Aviamentos"`), atualiza
`preco_compra`, marca `lancado`. Idempotente pelo `UPDATE ... WHERE status = 'rascunho'` (D11).

**Custo de 313 itens numa transação:** chamar `EstoqueService::lancar()` em laço dá ~626
queries (um `INSERT` + um `increment` por item) e mantém a transação aberta por segundos.
Proposta: um método novo `EstoqueService::lancarEmLote(array $movimentos, ...)` que faz
`INSERT` em lote nas movimentações e um `UPDATE` por produto, reusando a mesma validação.
**É código novo em serviço que já funciona** — não altera `lancar()`/`estornar()`, só soma
um caminho ao lado, e a Fase 4 cobre os dois com teste.

**`cancelar` — um verbo só, efeito conforme o estado:** de `rascunho` apenas fecha a nota
(não houve movimentação a desfazer); de `lancado` **reverte o estoque primeiro** —
movimentações espelhadas (`saida`, mesma nota) — e só então vai para `cancelado`. Nos dois
casos a chave é liberada para reimportação (D11) e **nada apaga produto criado nem de-para**.

Isso funde o antigo par `descartar`/`estornar` num verbo só. Nenhuma informação se perde: quem
precisa saber se aquela nota cancelada chegou a mexer no estoque olha `lancado_em` —
preenchido ou nulo.

**A reversão permite estoque negativo** (`permitirNegativo = true`, o mesmo caminho de venda e
PDV): desfazer a entrada quando a mercadoria já foi vendida tem que poder deixar o saldo
negativo, senão a nota fica impossível de cancelar. O saldo negativo é o retrato real e
aparece no histórico. `EstoqueService::estornarEmLote()` nasce ao lado do `lancarEmLote()`
com a mesma regra.

### 7.6 Endpoints

```
POST   /api/v1/notas-entrada/importar          multipart xml → rascunho + conferência (409 se duplicada)
GET    /api/v1/notas-entrada                   paginada; filtros: status, fornecedor_id,
                                               dh_emissao_de, dh_emissao_ate   ← filtro por data da NF
GET    /api/v1/notas-entrada/{id}              nota + avisos + itens paginados
                                               (?per_page, ?situacao=pendente|vinculado|novo|ignorado)
PATCH  /api/v1/notas-entrada/{id}/itens/{item} autosave: produto_id, acao, fator_conversao,
                                               preco_compra_calc, produto_novo, preco_venda_novo
PATCH  /api/v1/notas-entrada/{id}              custo_composto (recalcula todos os itens)
POST   /api/v1/notas-entrada/{id}/lancar       { aceites: [...] }  → lancado
POST   /api/v1/notas-entrada/{id}/cancelar     de rascunho ou lancado; reverte o estoque se lancado
GET    /api/v1/fornecedores                    + PATCH /{id}  (CRUD mínimo, §8)
```

**Nota sobre permissão:** a API hoje **não** tem middleware de perfil — o gate é só no FE
(`RequirePerfil`). Sigo o padrão existente (esconder de `vendedor`, área `produtos`) e **não**
invento middleware novo aqui; fechar isso no back é decisão separada, válida para todas as
rotas.

---

## 8. Telas (FE)

**Importação é tela, não modal** (sua decisão — é informação demais para modal).

| Tela | Arquivo | Conteúdo |
|---|---|---|
| Lista de notas de entrada | `src/pages/NotasEntrada.tsx` | status, fornecedor, número, data, valor; **filtro por data da NF**; botão "Importar XML" |
| Importar | `src/pages/ImportarNotaEntrada.tsx` | drop zone, o que o XML trouxe (fornecedor, número, total, nº de itens), avisos do D6 com aceite; ao importar vai para a conferência |
| **Conferência** | `src/pages/ConferenciaNotaEntrada.tsx` | o coração; detalhes abaixo |
| Fornecedores | `src/pages/Fornecedores.tsx` + `FornecedorForm.tsx` | CRUD mínimo, reusando os campos de endereço + CEP extraídos de `ClienteForm` (D3) |
| Histórico do produto | `ProdutoForm.tsx` (existente) | movimentação passa a mostrar a nota de origem (D8) |

**A conferência com 313 itens exige o que a v1 tratava como opcional:**

- **paginação ou virtualização** — obrigatória, não "se doer"
- **filtros por situação:** pendentes / vinculados / novos / ignorados
- **ações em massa:** "criar todos os novos", "ignorar todos os pendentes", "aceitar todos os
  fatores sugeridos" (com o trecho que gerou cada um à vista)
- **resumo antes de lançar:** "vai criar 313 produtos, vincular 0, ignorar 0; estoque de 313
  produtos vai mudar" — confirmação explícita
- indicador de **"rascunho salvo"** por linha (§7.5)

Linha: `[descrição + cProd/EAN]` · `[badge de origem do vínculo]` · `[busca de produto (ProdutoBusca)]` ·
`[qCom uCom]` · `[× fator + trecho sugerido]` · `[= qtd estoque + unidade]` · `[preço compra]` ·
`[preço venda (era R$ x,xx)]` · `[ignorar]`

Rodapé fixo: contagens por ação, checkbox **"aplicar cálculo de custo"** (D5), soma contra o
`vNF` **com tolerância de centavos**, e `Lançar estoque` — desabilitado enquanto houver item
sem ação ou produto novo sem preço de venda (D9).

Mais: rota em `App.tsx`, menu em `Layout.tsx` (área `produtos`), tipos em `src/types/index.ts`
(incluindo a lista nova de `UNIDADES`), chamadas em `src/services/api.ts`.

---

## 9. Testes

Pest, no padrão request/feature do projeto, **rodando dentro do container** (o env do
container vence o `phpunit.xml`).

Fixtures em `tests/Fixtures/nfe-entrada/`:
1. **`compra-roma-313itens.xml`** — a nota real da §3.1. Vale por dez: `uCom==uTrib` em tudo,
   42% sem GTIN, `cProd` como EAN-13, desconto em 295 itens, IPI em 195, 1 centavo de
   arredondamento no `vNF`, 8 unidades distintas.
   ⚠️ **Anonimizar antes de commitar.** O arquivo é uma NF-e de produção: carrega CNPJ e IE
   reais das duas empresas, endereços, telefones, dois e-mails pessoais e a assinatura digital
   do fornecedor. Vai para `tests/Fixtures/` com CNPJ/IE/nome/endereço/e-mail substituídos por
   valores falsos mas estruturalmente válidos, e com o bloco `Signature` cortado (o parser não
   valida assinatura — §7.1). **O original fica fora do repositório**, em
   `~/Downloads`, para o teste manual da Fase 5.
   Sugestão: commitar também uma versão reduzida de ~20 itens (`compra-roma-reduzida.xml`)
   para os testes do dia a dia, e deixar a de 313 itens só no teste de volume — 377 KB em
   toda rodada de suite é desperdício
2. `compra-caixa-utrib.xml` — construída à mão com `uCom=CX qCom=2 / uTrib=UN qTrib=24`, para
   cobrir o passo 3 do §7.3 que a nota real não exercita
3. `compra-st-ipi.xml` — com `vICMSST`, para o custo composto do D5
4. `compra-simples-nacional.xml` — emitente `CRT=1` com `ICMSSN102`/`CSOSN`
5. `venda-propria-65.xml` e `venda-propria-55.xml` — os dois arquivos da §3.2 (rejeição; o 65 **sem `dest`**)
6. `com-doctype.xml` — tentativa de XXE, rejeitada antes do parse

Casos: os 7 caminhos de casamento do §7.2 · sugeridor de fator nos 4 padrões de descrição ·
fator do de-para vencendo o sugerido · custo com e sem checkbox, com rateio de frete ·
**chave duplicada bloqueia (409) em rascunho e lancado, e permite reimportar depois de
cancelada** · destinatário divergente e nota sem `dest` disparam o aviso ·
tolerância de centavos nos totais · autosave de item preserva `produto_novo`/`preco_venda_novo` ·
lançar cria produtos, grava de-para, sobe estoque e atualiza `preco_compra` · duplo `lancar`
não duplica · estorno volta o estoque · 2ª importação do mesmo XML resolve tudo pelo de-para ·
**isolamento por empresa em todos os endpoints** (§5).

Na Fase 1, rodar **toda** a suíte de venda, PDV e nota avulsa — é ela que prova que o decimal
não quebrou nada.

---

## 10. Roteiro de implementação (checklist)

**Como usar:** marque `[x]` neste arquivo conforme avança. **Nada é marcado sem a verificação
ter rodado.** Os itens de verificação estão no checklist de propósito: são passo, não ritual.

### Portão de fechamento — vale para toda etapa, sem exceção

Nenhuma etapa começa antes da anterior passar por estes quatro passos, **nesta ordem**:

1. **Revisar** o diff do que foi feito contra o checklist da etapa — o que está marcado
   confere com o que o código faz, e nada entrou fora do escopo da etapa. (`/code-review` no
   diff serve; `/simplify` quando a etapa mexeu em código que já existia.)
2. **Rodar os testes** dentro do container — a suite da área afetada, e a **suite inteira**
   nas etapas que mexem em código em produção (Fases 1, 2 e 3). Verde, não "verde menos um".
3. **Commitar** — um commit por etapa, mensagem dizendo a etapa e o que mudou.
4. **`PROGRESS.md`** — 3–5 linhas: o que fechou, o que ficou de fora e por quê.

Se a revisão ou os testes apontarem problema, a etapa **não fechou**: corrige e repete os
quatro passos. Etapa pela metade não vira commit nem libera a seguinte.

| Fase | O que | Depende de | Portão de saída |
|---|---|---|---|
| 1 | Estoque decimal | D2 | suite inteira verde (venda + PDV + nota avulsa) |
| 2 | Unidades + `preco_compra` 4 decimais | D4, D7 | testes de validação de produto |
| 3 | Fornecedor + parser + importar | Fase 2, D3, D6, D11 | parser medido contra a nota real de 313 itens |
| 4 | Conciliação + custo + lançamento | Fases 1–3, D1, D5, D8–D10 | fluxo completo + isolamento por empresa |
| 5 | Telas | Fase 4 | importar a nota real de 313 itens no Firefox |

---

### ✅ Fase 1 — Estoque decimal (D2)

> O trecho mais arriscado do plano: mexe em venda e PDV que já funcionam. Commit próprio,
> nada de misturar com a importação.

**Banco**
- [x] 1.1 Migration nova (ex. `2026_10_01_000001_alter_quantidades_para_decimal.php`) alterando para `decimal(15,4)`: `produtos.estoque_atual`, `estoque_movimentacoes.quantidade`, `venda_itens.quantidade`, `pdv_venda_itens.quantidade` — com `down()` de volta para `integer`
- [x] 1.2 Rodar a migration e conferir os tipos no Postgres (`\d produtos`)

**Back**
- [x] 1.3 Casts: `Produto.php:37` (`estoque_atual`), `EstoqueMovimentacao.php:29`, `VendaItem.php:26`, `PdvVendaItem.php:26`
- [x] 1.4 `EstoqueService.php:20` e `:63`, `VendaService.php:54`, `PdvVendaService.php:260` — assinaturas `int $quantidade` saem; `ValoresDoItem.php:24` também (1.8)
- [x] 1.5 `Produto::temEstoque()` em `Produto.php:90` — comparação decimal, sem `float`
- [x] 1.6 Validações `integer` → `numeric`: `ProdutoController.php:57`, `:173` e `:205`, `VendaController.php:90`, `PdvVendaController.php:108` e `:183`, `Services/Nfe/FormularioNotaAvulsa.php:346`
- [x] 1.7 `Services/Nfe/EstoqueDaNota.php` — tirar o `(int)` de `quantidadesPorProduto()`
- [x] 1.8 `ValoresDoItem::calcular()`: revisar arredondamento de subtotal: quantidade fracionada × preço arredonda para 2 casas, uma regra só, sem `float` em dinheiro

**Front**
- [x] 1.9 `src/utils/notaFiscal.ts:459` — sai a validação `A quantidade deve ser inteira.`
- [x] 1.10 `src/pages/ProdutoForm.tsx:248,275` — `parseInt` e `step="1"`; o `step` passa a depender da unidade (UN inteiro, M/KG/G fracionado)
- [x] 1.11 `src/pages/VendaDetalhe.tsx:295` — `parseInt` sai; idem `src/components/CarrinhoLista.tsx:69` (`Math.max(1, parseInt(...))` no PDV) e `ProdutoForm.tsx:95` e `:177` (`estoque_atual` na criação, `parseInt` + `step="1"`)
- [x] 1.11b `useCarrinho.ts` (`valoresDoItem`, ~linha 15) é **espelho de `ValoresDoItem.php`** ("se divergir um centavo, o pagamento exato é recusado"): mudar os dois **juntos** e testar que dão o mesmo centavo com quantidade fracionada
- [x] 1.12 `src/hooks/useCarrinho.ts:16` — conferir a multiplicação por centavos com quantidade fracionada

**Verificação**
- [x] 1.13 Teste novo: estoque 1,5 KG entra, sai 0,25 e sobra 1,25
- [ ] 1.14 Firefox: criar venda com 2,5 de um produto em M; ajuste de estoque fracionado; PDV  
      ↳ **pendente:** conferência visual é sua (§13.4)
- [x] 1.15 **Revisar** o diff contra este checklist (`/code-review`); nada fora do escopo da fase
- [x] 1.16 **Testes** no container: suite **inteira** (venda, PDV, nota avulsa, produtos) — verde
- [x] 1.17 **Commit** da fase
- [x] 1.18 **`PROGRESS.md`**: o que fechou, o que ficou de fora e por quê

---

### ✅ Fase 2 — Unidades e preço de compra (D4, D7)

- [x] 2.1 Migration: `produtos.preco_compra` → `decimal(15,4)` (+ cast no model)
- [x] 2.2 `app/Support/Unidades.php`: lista nova (D4) + `normalizar()` (`MT`→`M`, `UNID`/`PÇ`→`UN`, `LTA`→`LT`, `ROLO`→`ROL`)
- [x] 2.3 `ProdutoController.php:56` e `:104` passam a validar contra a lista de `Unidades`
- [x] 2.4 FE: `UNIDADES` em `src/types/index.ts:58` espelhando a lista; `select` do `ProdutoForm`
- [x] 2.5 FE: `MoneyInput` aceita 4 decimais em preço de compra (e só nele)
- [x] 2.6 Testes: produto com `ROL`, `CAR`, `KIT`, `PAR` é aceito; `MT` normaliza para `M`; `preco_compra` 0,1260 ida e volta sem perder casa
- [x] 2.7 **Revisar** o diff contra este checklist (`/code-review`); nada fora do escopo da fase
- [x] 2.8 **Testes** no container: suite **inteira** (a mudança de `preco_compra` toca emissão) — verde
- [x] 2.9 **Commit** da fase
- [x] 2.10 **`PROGRESS.md`**: o que fechou, o que ficou de fora e por quê

---

### ⚠️ Fase 3 — Fornecedor, parser e importar (D3, D6, D11)

**Fornecedor**
- [x] 3.1 Migration `fornecedores` (§6.1) + model com `CompanyScope`
- [x] 3.2 `FornecedorController` (index/show/update) + rotas no grupo `enscope-to-company`
- [x] 3.3 FE: extrair `EnderecoFields` de `ClienteForm.tsx` reusando `services/cep.ts`
- [ ] 3.4 FE: `ClienteForm` passa a usar o componente extraído — **conferir a tela de cliente no Firefox** (não há teste de FE que pegue regressão aqui)  
      ↳ o refactor foi feito; **a conferência da tela de cliente no Firefox está pendente** (§13.4)
- [x] 3.5 FE: `Fornecedores.tsx` + `FornecedorForm.tsx` + rota + menu
- [x] 3.6 Testes de `fornecedores`: CRUD e isolamento por empresa

**Fixtures**
- [x] 3.7 Anonimizar a nota real (CNPJ, IE, nomes, endereços, e-mails; cortar `Signature`) → `tests/Fixtures/nfe-entrada/compra-roma-313itens.xml`
- [~] 3.8 ~~Gerar a versão reduzida de ~20 itens~~ — **descartada** (§13.8): os testes da nota real checam o arquivo cheio; versão reduzida não substituiria nenhum
- [x] 3.9 Construir à mão: `compra-caixa-utrib.xml`, `compra-st-ipi.xml`, `compra-simples-nacional.xml`, `com-doctype.xml`; copiar os dois de venda própria (§3.2)

**Parser**
- [x] 3.10 `app/Services/Compras/LeitorXmlNfe.php` + DTO: `nfeProc`/`NFe`, namespace, `ICMS00/10/60` e `ICMSSN*`, `IPITrib`/`IPINT`, ST, `ICMSTot`, `protNFe/cStat`, ausência de `dest`
- [x] 3.11 Guardas de XXE: recusa `<!DOCTYPE`/`<!ENTITY`; `LIBXML_NONET|LIBXML_NOCDATA`, sem `LIBXML_NOENT`/`LIBXML_DTDLOAD`; limite de 2 MB e mime
- [x] 3.12 `app/Services/Compras/SugeridorDeFator.php`: `C/100`, `C/50PC`, `20MT`, `15Y`, `500G/600UN`, `X50` — devolve fator **e** o trecho que casou
- [x] 3.13 Testes do parser contra a nota real: 313 itens, `uCom==uTrib` em tudo, 132 sem GTIN, 309 `cProd` EAN-13 válidos, soma de `vProd`/`vDesc` igual ao `ICMSTot`
- [x] 3.14 Testes do sugeridor nos 4 padrões; **medir a cobertura real nos 313 itens** (o plano estima ~90%, não reproduzido) e ajustar o texto do §3.1/§7.3 ao número medido; itens sem padrão devolvem `null`
- [x] 3.15 Teste de XXE: `com-doctype.xml` recusado antes do parse

**Importar**
- [x] 3.16 Migrations `notas_entrada` (com **unique parcial** do D11) e `nota_entrada_itens` (§6.2, §6.3) + models com `CompanyScope`
- [x] 3.17 `POST /notas-entrada/importar`: valida, grava XML em `{empresa_id}/{chave}-{nota_id}.xml`, cria/vincula fornecedor, cria nota + itens em `rascunho`
- [x] 3.18 Avisos do D6 (`dest` divergente, sem `dest`, `tpAmb=2`, `cStat≠100`, totais fora da tolerância de centavos) gravados em `avisos`
- [x] 3.19 Dedupe do D11: 409 com o status da nota existente
- [x] 3.20 Testes: importa a nota real; rejeita as duas de venda própria; 409 em rascunho e lancado; permite reimportar depois de cancelada; isolamento por empresa
- [x] 3.21 **Revisar** o diff contra este checklist (`/code-review`); nada fora do escopo da fase
- [x] 3.22 **Testes** no container: suite **inteira** (o refactor do `ClienteForm` toca venda e NF-e) — verde
- [x] 3.23 **Commit** da fase
- [x] 3.24 **`PROGRESS.md`**: o que fechou, o que ficou de fora e por quê

---

### ⚠️ Fase 4 — Conciliação, custo e lançamento (D1, D5, D8, D9, D10)

- [x] 4.1 Migration `produto_fornecedor_codigos` (§6.4)
- [x] 4.2 Migration `estoque_movimentacoes.nota_entrada_id` nullable (D8)
- [x] 4.3 `ResolvedorDeProdutos`: os 7 passos da §7.2, gravando `origem_vinculo`
- [x] 4.4 Fator na ordem da §7.3, gravando `fator_sugerido`, `fator_origem` e `trecho_sugestao`
- [x] 4.5 `CalculadoraDeCusto`: checkbox desmarcado `(vProd−vDesc)÷qtd`; marcado soma frete/seguro/outros/ST/IPI com rateio proporcional a `vProd`
- [x] 4.6 `PATCH /itens/{item}` — autosave de `produto_id`, `acao`, `fator_conversao`, `preco_compra_calc`, `produto_novo`, `preco_venda_novo`
- [x] 4.7 `PATCH /{id}` — `custo_composto` recalcula todos os itens
- [x] 4.8 `EstoqueService::lancarEmLote()` — **ao lado** de `lancar()`, sem alterar o existente
- [x] 4.9 `POST /lancar`: transação única — cria produtos de `produto_novo`, aplica `preco_venda_novo` que mudaram (D9), aplica D10 ("só se vazio"), grava de-para, lança estoque, atualiza `preco_compra`, grava aceites, marca `lancado`
- [x] 4.10 `POST /cancelar`: de `rascunho` só fecha; de `lancado` reverte o estoque com `permitirNegativo` via `estornarEmLote()`; libera a chave (D11)
- [x] 4.11 Teste: nota com todos os itens `ignorar` lança sem criar produto e sem movimentar (é o caminho da nota de material de consumo, §7.5)
- [x] 4.12 `GET /notas-entrada` com filtros `status`, `fornecedor_id`, `dh_emissao_de`, `dh_emissao_ate`
- [x] 4.13 `GET /notas-entrada/{id}` com itens paginados e filtro por situação
- [x] 4.14 Testes dos 7 caminhos de casamento, com o de-para vencendo o sugerido  
      ↳ **parcial:** só `sku`, `de_para` e `novo` têm teste; `de_para_descricao`, `ean`, `cprod_ean` e a regra de ambiguidade, não (§13.2)
- [x] 4.15 Testes de custo: com e sem checkbox, com rateio de frete, conferindo R$ 0,1260 da etiqueta e R$ 0,4290 do metro  
      ↳ **parcial:** o rateio de frete não tem teste (a nota real tem frete zero) (§13.2)
- [x] 4.16 Testes de lançamento: cria produto, grava de-para, sobe estoque, atualiza `preco_compra`; duplo `lancar` não duplica; estorno volta o estoque, **inclusive quando o produto já foi vendido ou estava negativo (termina negativo, não falha)**
- [x] 4.17 Teste do de-para: 2ª importação do mesmo XML resolve tudo sozinha
- [x] 4.18 Teste do draft: autosave preserva `produto_novo` e `preco_venda_novo` entre requisições
- [x] 4.19 Teste de bloqueio: produto novo sem `preco_venda` impede o lançamento
- [x] 4.20 Isolamento por empresa em **todos** os endpoints novos
- [x] 4.21 **Revisar** o diff contra este checklist (`/code-review`); nada fora do escopo da fase
- [x] 4.22 **Testes** no container: suite de notas de entrada + produtos/estoque — verde
- [x] 4.23 **Commit** da fase
- [x] 4.24 **`PROGRESS.md`**: o que fechou, o que ficou de fora e por quê

---

### ⚠️ Fase 5 — Telas (§8)

- [x] 5.1 Tipos em `src/types/index.ts` e chamadas em `src/services/api.ts`
- [x] 5.2 `NotasEntrada.tsx`: lista, status, **filtro por data da NF**, paginação
- [x] 5.3 `ImportarNotaEntrada.tsx`: **tela, não modal** — drop zone, resumo do XML, avisos do D6
- [x] 5.4 `ConferenciaNotaEntrada.tsx` — linha completa (§8) com badge de origem do vínculo, `ProdutoBusca`, fator + trecho sugerido, qtd convertida, preço de compra, preço de venda com "era R$ x,xx"
- [~] 5.5 Paginação/virtualização — **adiada** (decisão do usuário): hoje `per_page: 1000` + paginação no cliente; refactor servidor fica para quando aparecer nota > 1000 itens
- [~] 5.6 Filtros por situação — **adiado** (decisão do usuário): vinculados/novos/ignorados existem; o estado "pendente" + dica é feature própria, parada
- [x] 5.7 Ações em massa: ignorar/restaurar, aceitar fatores sugeridos e **aplicar markup de preço de venda**  
      ↳ **feito em 2026-10-01** (endpoint `POST /notas-entrada/{id}/itens/massa`, serviço `AcoesEmMassa`, §13.6)
- [x] 5.8 Autosave por linha com indicador "rascunho salvo"  
      ↳ **parcial:** o autosave funciona; o indicador "rascunho salvo" por linha não existe (§13.1)
- [x] 5.9 Rodapé: contagens, checkbox de custo (D5, **desmarcado por padrão**), soma vs `vNF` com tolerância, botão `Lançar` desabilitado conforme D9
- [x] 5.10 Resumo de confirmação antes de lançar ("vai criar 313 produtos…") com os avisos do D6
- [x] 5.11 `ProdutoForm.tsx`: histórico de movimentação mostra a nota de origem (D8)  
      ↳ **entregue em outro lugar:** virou a tela própria `MovimentacaoProduto.tsx` (estoque +
      preço, NF como link), não um bloco dentro do `ProdutoForm` (§13.5)
- [x] 5.12 Rota em `App.tsx` + menu em `Layout.tsx` (área `produtos`, escondido de `vendedor`)
- [ ] 5.13 **Firefox:** importar a nota real de 313 itens de ponta a ponta — conferir, lançar, checar estoque de 3 produtos na mão, cancelar e conferir a reversão  
      ↳ **pendente:** conferência visual é sua (§13.4)
- [x] 5.14 **Revisar** o diff contra este checklist (`/code-review`); nada fora do escopo da fase
- [x] 5.15 **Testes** no container: suite de notas de entrada — verde
- [x] 5.16 **Commit** da fase
- [x] 5.17 **`PROGRESS.md`**: o que fechou, o que ficou de fora e por quê

---

## 11. Riscos e fora de escopo

**Riscos:**
- **Fase 1 mexe em venda e PDV que já funcionam.** Maior risco do plano. Fase separada, commit
  próprio, suíte inteira antes de seguir.
- **Fator errado corrompe estoque em silêncio.** `C/100` lido como 10 e entram 10 em vez de
  100. Mitigação: o trecho da descrição que gerou a sugestão fica à vista, e o estorno
  desfaz a nota inteira.
- **313 itens de uma vez é muito trabalho humano na 1ª nota.** As ações em massa são o que
  torna isso viável; o de-para é o que faz a 2ª nota ser rápida.
- Fornecedor que muda `cProd` entre notas cai no casamento por descrição (passo 2) ou por EAN.
- Importação cancelada deixa fornecedor cadastrado (D3) — aceito.
- **Extrair o componente de endereço de `ClienteForm.tsx` mexe em tela que já funciona** (D3,
  §8). É refactor puro, mas de código em produção: fazer na Fase 3, isolado, e conferir a tela
  de cliente no Firefox antes de seguir — não há teste de FE que pegue isso.

**Fora de escopo agora:**
- custo médio / estoque valorizado (D5)
- histórico de alteração de preço de venda (D9)
- produto pai/filho com "desmembrar" explícito, para vender a caixa fechada (D1)
- contas a pagar, pedido de compra
- devolução ao fornecedor e nota de entrada emitida por nós (`tpNF=0`)
- recebimento parcial (divergência entre nota e mercadoria)
- NFC-e (mod 65) como nota de compra — não existe

**Fora de escopo, mas é o próximo passo natural** (o Bling tem os dois, §3.3):
- **buscar e manifestar notas direto na SEFAZ** (`NFeDistribuicaoDFe`) — é o que faz parar de
  pedir XML ao fornecedor. Depende de endpoint novo na `nfe-api`, que hoje só emite: projeto próprio.
  **→ planejado em [`PLAN-DISTDFE.md`](./PLAN-DISTDFE.md) (2026-10-02), nada implementado e com as
  decisões D1–D7 abertas.** Duas coisas que o levantamento daquele plano corrigiu nesta linha: (a)
  não depende só de endpoint novo — a manifestação do destinatário é obrigatória, porque antes dela
  a SEFAZ devolve apenas o *resumo* da nota, sem itens; e (b) `LeitorXmlNfe` já aceita a raiz
  `nfeProc`, então o XML completo vindo da distribuição entra no `ImportacaoNotaService` sem
  alteração — o trabalho todo é antes dele, não dentro. **Pré-requisito: fechar a §13 antes**, senão
  as lacunas da conferência chegam multiplicadas (as notas passam a chegar sozinhas).
- **importação em lote** (vários XML). Barato depois que 1 funcionar; a conferência é que
  precisaria de fila.

**Fora de escopo e sem previsão:** pedido de compra, depósitos múltiplos, conciliação de
variações, lançamento no financeiro.

---

## 12. Decisões — estado final

D1 a D11 **fechadas** (§4), incluindo o padrão do D5 (checkbox desmarcado, desconto aplicado).

**D12 — estados simplificados** (§7.5): **três** estados (`rascunho → lancado`, `cancelado` a
partir de qualquer um dos dois) e **dois** verbos (`lancar`/`cancelar`), contra cinco estados e
quatro verbos na primeira versão. Saíram: `descartar` e `estornar` como operações separadas
(são o mesmo `cancelar`, com efeito conforme o estado) e o estado intermediário
`importado`/`registrada`, que era cópia do checkbox *Lançar Estoque* do Bling e colidia com o
D9. Nota que não é mercadoria passa por `ignorar` nos itens.

Também fechado: a reversão permite estoque negativo (§7.5); `cest` fora do D10 (`produtos`
não tem a coluna).

D13 — **a revisão pós-implementação virou a §13** (2026-10-01): as 5 fases estão no código, e o
que falta são as ações em massa da conferência (13.1), 9 correções de backend (13.2), a
anonimização da fixture (13.3) e a conferência no Firefox (13.4).

Próximo passo: **§13.1 item 1** — as ações em massa da conferência. Sem elas a tela não resolve o
problema que originou o plano (313 itens à mão), e os itens 2 e 3 da mesma lista são correções
pequenas na mesma tela, então vão no mesmo trabalho.

---

## 13. Revisão pós-implementação — 2026-10-01

Auditoria do código das 5 fases contra este plano. **O que passou:** o fluxo inteiro existe e
funciona — parser, dedupe, fornecedor, de-para, custo, lançamento, estorno, telas. Backend com
**502 testes passando** (as 7 falhas restantes são a baseline pré-existente, nenhuma neste
escopo) e `tsc --noEmit` limpo no FE. Os números medidos da §3.1 foram todos reproduzidos.

O que segue é o que **não** está pronto, em ordem de importância.

### 13.1 Lacunas de tela — a conferência de 313 itens ainda não é usável de verdade

1. ~~**Ações em massa não existem** (item 5.7).~~ **✅ feito (2026-10-01, §13.6).** Era *"o que torna isso viável"*
   para 313 itens, e a tela saiu sem nenhuma: não há "criar todos os novos", "ignorar todos os
   pendentes" nem "aceitar todos os fatores sugeridos". Quem importar a nota real vai clicar
   item por item, que é exatamente o problema que o plano se propôs a resolver.
   **É a correção mais importante da lista.**

2. ~~**A tela bloqueia a nota 100% ignorada**~~ **✅ corrigido (2026-10-01):** `podeLancar` agora exige só
   preço nos produtos novos e ao menos um item. Contrariava a §7.5. `podeLancar` em
   `ConferenciaNotaEntrada.tsx` exige `(vincular + criar) > 0`, então a nota de material de
   consumo — todos os itens em `ignorar`, zero produto, zero movimentação — **não pode ser
   lançada pela interface**. O backend aceita e tem teste verde para esse caminho (item 4.11):
   a regra está certa no serviço e errada na tela.

3. **Paginação só no cliente** (item 5.5). A tela chama `get(id, { per_page: 1000 })` e fatia o
   array em memória. Funciona com 313 itens; uma nota com mais de 1000 perde itens em silêncio.
   O endpoint já pagina de verdade — é a tela que não usa.

4. **Não existe estado "pendente"** (itens 5.6 e §7.2). O `acao` só tem `vincular | criar |
   ignorar`; item com EAN ambíguo vira `criar` em vez de ficar pendente com os candidatos como
   dica, e o passo 7 (semelhança de nome como dica) não foi implementado. Consequência: o filtro
   "pendentes" do plano não existe nem no back nem no front, e a dica que evitaria vínculo errado
   no meio de 313 linhas também não.

5. **Sem indicador "rascunho salvo" por linha** (item 5.8). O autosave por `PATCH` funciona; o
   usuário só não tem como saber que gravou — erro aparece, sucesso não.

### 13.2 Correções no backend

6. **`produto_novo` entra em `produtos` sem validação.** `NotaEntradaController::atualizarItem`
   valida só `produto_novo.preco_venda` e grava o array inteiro com `fill()`; no lançamento,
   `LancamentoNotaService::criarProduto` escreve `unidade`, `nome` e `codigo_barras` direto no
   cadastro. **Uma unidade fora da whitelist do D4 entra no banco** por esse caminho, e nenhuma
   das regras do `ProdutoController` se aplica. Validar `produto_novo.unidade` com
   `Unidades::regraIn()` (e `nome`/`codigo_barras`) fecha o buraco.

7. **Trocar a ação de `criar` → `vincular` → `criar` perde o código de barras.** Nessa volta o
   `produto_novo` é remontado pela tela sem `codigo_barras`, e `criarProduto` não tem o fallback
   para `$item->ean` / `cProd` EAN-13 que `atualizarProduto` tem. O produto nasce sem GTIN
   embora a nota o trouxesse.

8. **`tem_substituicao_tributaria` pela presença do nó, não pelo valor.** Em
   `LeitorXmlNfe::itens()`, `temSt` é `length > 0` do `vICMSST`. Fornecedor que emite
   `<vICMSST>0.00</vICMSST>` marca o produto novo com ST indevidamente. Deve ser `valor > 0`.

9. **D10 nunca preenche `origem_icms`.** `atualizarProduto` testa
   `$produto->origem_icms === null`, mas a coluna é `NOT NULL DEFAULT 0` — o ramo é código
   morto. Se a intenção é "só preenche se estiver vazio", o vazio aqui é `0`.

10. **Dedupe fora da transação** (D11). `recusarSeDuplicada` roda antes do `DB::transaction`, e
    o índice unique parcial é a única barreira real. Dois uploads simultâneos da mesma chave
    devolvem 500 (violação de unique) em vez do 409 combinado. Em uso de um usuário por vez não
    aparece; é correção de robustez.

11. **Upload sem checagem de mime** (§7.1 pedia `xml`/`text`). A regra é
    `['required','file','max:2048']`; o que protege é o parser recusar depois. Barato de somar.

12. **Lacunas de teste** (itens 4.14, 4.15): dos caminhos de casamento da §7.2 só `sku`,
    `de_para` e `novo` têm teste — `de_para_descricao`, `ean`, `cprod_ean` e a regra de
    ambiguidade não. O rateio de frete do custo composto também não tem teste (a nota real tem
    frete zero, então foi preciso construir a fixture e ela não cobre rateio). Os filtros de
    `GET /notas-entrada` (itens 4.12, 4.13) estão implementados sem teste.

13. **A fixture reduzida de ~20 itens não foi feita** (item 3.8). Toda rodada da suíte parseia
    os 377 KB da nota de 313 itens.

### 13.3 Dados de terceiros na fixture commitada

14. **A anonimização da nota real ficou incompleta** (item 3.7). Emitente, destinatário, CNPJ,
    IE, e-mails e telefones foram trocados e a `Signature` foi cortada, mas sobraram, em
    `tests/Fixtures/nfe-entrada/compra-roma-313itens.xml`:
    - `transp/transporta/xNome` e `xEnder` com o nome e o endereço reais da transportadora
    - `infAdic/infCpl` com `Cliente: 100341 - FEITO A MAO`

    São dados de empresas de verdade num arquivo de repositório. Trocar por valores falsos
    fecha o item.

### 13.4 Só você pode fechar

15. **Conferência visual no Firefox** (itens 1.14, 3.4 e 5.13): venda/PDV com quantidade
    fracionada; a tela de cliente depois do refactor do `EnderecoFields` (não há teste de FE que
    pegue regressão ali); e a nota real de 313 itens de ponta a ponta — importar, conferir,
    lançar, checar o estoque de 3 produtos na mão, cancelar e conferir a reversão. Houve revisão
    no navegador durante a Fase 5 (os commits de "ajustes após revisão no navegador"), mas o
    roteiro completo do 5.13 não está registrado como feito.

### 13.5 Observações que não são defeito

- **`lancarEmLote` resolveu metade do problema de queries.** As 313 movimentações saem num
  `INSERT` só, mas o saldo ainda é um `find` + um `increment` por produto — ~626 queries, o
  número que a §7.5 queria evitar. Como a transação já está curta na prática, fica registrado,
  não cobrado.
- **`CalculadoraDeCusto` faz as contas em `float`**, não em centavos como o `ValoresDoItem`. Com
  4 decimais e valores de nota não dá erro observável, mas é uma exceção à regra "sem `float` em
  dinheiro" do D2, e vale saber que está ali.
- **O FE duplica a tolerância de centavos** (`0.05`) que o backend já aplica em `avisos`. Duas
  cópias da mesma constante.
- **A API continua sem middleware de perfil**, como a §7.6 previu: o gate é o `RequirePerfil`
  do FE. Mantido de propósito, é decisão separada.
- **Fora do escopo deste plano, mas no caminho:** a `gestaofacil-api` está com
  `bootstrap/app.php` modificado e não commitado (o renderer que transforma 422/404/401 em 500)
  e um `.head-app.php.tmp` solto na raiz. É o que obriga a rodar a suíte numa cópia; limpar isso
  tira uma armadilha permanente do caminho de todo mundo.

---

## 13.6 Ações em massa + markup de preço de venda — 2026-10-01

Primeira correção pós-revisão. Fecha o §13.1 itens 1 e 2 e acrescenta o markup pedido.

**Endpoint único** `POST /notas-entrada/{id}/itens/massa` (só em rascunho, escopado por empresa),
com `operacao`:
- `ignorar` / `restaurar` — marca/desmarca `ignorar` nos itens do filtro. "Restaurar" volta para
  `vincular` (se o item tem produto) ou `criar`.
- `aceitar_fatores` — devolve o `fator_conversao` ao `fator_sugerido` pela descrição, onde houver,
  e recalcula o custo do item.
- `margem` — **o markup**: `preço de venda = custo × (1 + margem%)`.

Todas respeitam o filtro de situação da tela (`todos`/`vinculado`/`novo`/`ignorado`), via o campo
`situacao`. Serviço: `App\Services\Compras\AcoesEmMassa`.

**D14 — markup de preço de venda (ação em massa).** Decisões, confirmadas com o usuário:
- **Botão "Aplicar"**, não recálculo automático (ao contrário do checkbox de custo composto). O
  usuário controla quando roda. Não conflita com o D9 porque não é silencioso.
- **Base escolhível**: `custo` (= (vProd−vDesc) + impostos + frete rateado, igual ao D5 composto)
  ou `compra` (= só vProd−vDesc). A base do markup é **independente** do `custo_composto` gravado
  na nota — dá para guardar o custo simples e mesmo assim precificar sobre o custo cheio.
- **Preserva o que foi editado à mão.** A coluna nova `nota_entrada_itens.preco_venda_manual`
  marca a linha cujo preço de venda veio do autosave humano; o markup pula essas. O autosave
  liga a flag só quando o valor do preço de venda realmente muda (mexer na unidade reenvia o
  `produto_novo` inteiro e **não** deve marcar como manual).
- **Mensagem obrigatória** (pedido do usuário): ao aplicar, a tela diz quantos receberam o preço,
  quantos foram **preservados** por terem sido editados à mão, e quantos ignorados ficaram de fora.
- A margem e a base ficam gravadas na nota (`margem_percentual`, `margem_base`) só como memória da
  última aplicação, para a tela reabrir com os mesmos valores. O preenchimento continua pelo botão.

**Custo técnico:** `CalculadoraDeCusto::custoUnitario($nota, $item, bool $composto)` virou a fonte
única do cálculo de custo por unidade (o `aplicar()` do recálculo passou a usá-la), para o markup e
o preço de compra nunca divergirem.

**Testes:** `tests/Feature/Compras/AcoesEmMassaTest.php` — 8 casos: markup base compra (15,00) e
custo (17,58) sobre a `compra-st-ipi.xml`, base independente do `custo_composto`, preservação do
editado à mão com a contagem no resumo, item ignorado fora do markup, ignorar/restaurar 313 itens,
aceitar fatores recalculando custo, e isolamento por empresa (404). Suíte: **510 passando**, as 7
falhas restantes continuam sendo a baseline pré-existente.

**Ainda aberto do §13** (não mexido nesta sessão): paginação só no cliente (13.1-3), sem estado
"pendente"/dica (13.1-4), sem indicador "rascunho salvo" (13.1-5), as correções de backend 13.2
(6 a 13), a anonimização da fixture (13.3) e a conferência no Firefox (13.4). O indicador
"editado à mão" por linha foi adicionado de passagem (ajuda a entender o que o markup preserva),
mas não é o "rascunho salvo" do 13.1-5.

---

## 13.7 Preço de compra + preço de custo lado a lado, sem checkbox — 2026-10-01

Segue o §13.6, no mesmo dia. **Substitui o checkbox "Aplicar cálculo de custo" do D5** por dois
valores sempre visíveis em cada linha da conferência.

**D15 — a conferência mostra os dois custos, sem checkbox** (decisão do usuário, revoga o
mecanismo de checkbox do D5):
- Cada item exibe **preço de compra** (input editável) e **preço de custo** (label):
  `preço de custo = preço de compra + impostos e frete por unidade` (ST, IPI, frete/seguro/outros,
  incluindo o rateio do que veio só no total da nota).
- O **checkbox sumiu** e com ele o endpoint `PATCH /notas-entrada/{id}` (custo_composto) e o
  alerta do passo anterior (toggle do checkbox) — não há mais o que alertar.
- Editar o preço de compra à mão **arrasta** o preço de custo (mantém compra + impostos/frete).
- O **markup** lê os valores gravados: base `compra` → `preco_compra_calc`; base `custo` →
  `preco_custo_calc`. Assim o preço que o markup usa é exatamente o que a tela mostra.
- **O que vai para `produtos.preco_compra` no lançamento continua sendo `preco_compra_calc`** (o
  input de preço de compra). O preço de custo é informativo + base de markup; não é gravado no
  produto.
- `notas_entrada.custo_composto` virou coluna morta (não é mais lida nem escrita); ficou no banco
  para não exigir migration destrutiva. Pode cair numa limpeza futura.

**Técnico:** coluna nova `nota_entrada_itens.preco_custo_calc` (migration `..._000010`);
`CalculadoraDeCusto` reescrita — grava sempre `preco_compra_calc` (simples) e `preco_custo_calc`
(= compra + `extrasPorUnidade`), sem olhar `custo_composto`; `custoUnitario()` saiu.
Backfill dos itens existentes feito via `ajustarCustoAoPrecoEditado` (preserva o preço de compra).

**Testes:** `LancamentoNotaTest` — "grava preço de compra (simples) e preço de custo (com ST e
IPI)" e "editar o preço de compra arrasta o custo" (12,00 → custo 13,72). `AcoesEmMassaTest`
segue verde (markup custo 17,58, compra 15,00). Suíte: **511 passando**, 7 da baseline.

**Ajuste de 2026-10-02 (layout + correção):**
- A conta do preço de compra virou **fórmula rotulada**: `VL Prod − Desc ÷ Qtd = Compra` em cima,
  os números embaixo, cada valor sob o seu rótulo (sugestão do usuário). `VL Prod` é o valor cheio
  do produto na nota. O preço de custo fica numa linha à parte (compra + impostos/frete).
- **Bug corrigido:** o backfill do §13.7 usou `ajustarCustoAoPrecoEditado`, que preserva o
  `preco_compra_calc` existente. Nas notas calculadas antes com o checkbox "custo composto" ligado,
  esse valor já trazia o IPI embutido, então o custo somou o IPI **duas vezes**. Corrigido
  recalculando do zero (`recalcular`) as notas em rascunho do dev — o backfill correto para quem já
  tinha valores do checkbox é o recompute, não o ajuste.
- **Custo sub-centavo no markup:** itens comprados em pacote (ex.: etiqueta a R$ 0,001/un) fazem o
  markup arredondar o preço de venda para R$ 0,00. O serviço **não grava 0** (travaria o
  lançamento sem explicar) — deixa o preço **nulo** e conta em `resumo.semPreco`; a tela avisa
  "N ficaram sem preço (custo abaixo de 1 centavo) — ajuste à mão" em tom de aviso. Esses itens
  caem no `semPreco` da conferência e seguem bloqueando o lançamento até receberem preço (D9).

---

## 13.8 Correções de backend + testes + anonimização — 2026-10-02

Fecha o §13.2 (itens 6–11, parte do 12) e o §13.3. Tudo com teste; suíte **524 passando**, as 7 da
baseline intactas. Telas (#3, #4, #5) ficam para o próximo commit (precisam de Firefox).

- **#6 — `produto_novo` sem validação:** o autosave (`atualizarItem`) agora valida
  `produto_novo.unidade` contra `Unidades::PERMITIDAS` (D4), `nome` (required) e `codigo_barras`.
  **Cuidado com a mudança de unidades:** a importação nunca pré-preenche unidade fora da lista —
  `unidadeDeEstoque` cai em `UN` se a `uCom` normalizada não estiver em `PERMITIDAS`, senão a
  validação travaria uma nota legítima. No lançamento, `criarProduto` também força a whitelist.
- **#7 — `criar → vincular → criar` perdia o código de barras:** `criarProduto` ganhou fallback
  (`codigoBarrasDoItem`): usa `cEAN`, ou o `cProd` quando é EAN-13 válido. A unidade também tem
  fallback para a `uCom` normalizada (antes ia direto para `UN`).
- **#8 — ST pela presença do nó:** `LeitorXmlNfe` agora marca `temSt` por **valor** (`vICMSST > 0`);
  `<vICMSST>0.00</vICMSST>` não marca mais ST.
- **#9 — D10 nunca preenchia `origem_icms`:** era código morto (`=== null` numa coluna NOT NULL
  default 0). Removido. Decisão registrada: **a nota não atualiza `origem_icms` de produto
  existente** — não há "vazio" para distinguir de "Nacional (0)", e preencher arriscaria
  sobrescrever um 0 legítimo. Fica só na criação / no cadastro.
- **#10 — dedupe fora da transação:** além do pré-check, a importação agora captura a violação do
  índice único parcial (SQLSTATE 23505) e devolve o 409 do D11 em vez de 500 numa corrida.
- **#11 — upload sem mime:** `importar` valida `mimetypes:application/xml,text/xml,text/plain`
  (o parser segue sendo o guarda final).
- **#12:** testes de casamento por `ean`, `cprod_ean` e **`de_para_descricao`** (2ª nota com cProd
  trocado), e **rateio de frete** no preço de custo (fixture `compra-frete-rateado.xml`: frete 10 no
  total, rateado 6/4 entre itens de 60/40). Fecha o §12.
- **3.8 (fixture reduzida): descartada** — os testes que usam a nota real checam propriedades do
  arquivo cheio (313 itens, cobertura 87%, soma == ICMSTot, itens específicos); uma versão de ~20
  itens não substituiria nenhum, só criaria arquivo sem uso.
- **#13 (§13.3) — anonimização:** removidos da `compra-roma-313itens.xml` o nome/endereço reais
  da transportadora e o `infCpl` com a referência real de cliente. Fixture limpa.
- **Fixture nova:** `compra-cprod-ean13.xml` (1 item, `uCom=BALDE` fora da whitelist, `cProd`
  EAN-13, `cEAN` SEM GTIN) cobre os caminhos do #6 e do #7.

**Ainda aberto do §13:** telas 13.1-3 (paginação no servidor), 13.1-4 (estado "pendente"/dica),
13.1-5 feito (indicador "rascunho salvo"); a conferência no Firefox (13.4); e as dívidas do 13.5
(`custo_composto` coluna morta, `lancarEmLote` ~626 queries, `float` na calculadora, middleware de
perfil, `bootstrap/app.php` não commitado).


---

## 14. Atualização de 2026-10-19 — entrada de XML pela SEFAZ (ver `PLAN-DISTDFE.md`)

A importação passou a ter **duas portas** para o mesmo `ImportacaoNotaService`: o upload de XML (esta feature) e a busca de notas na SEFAZ. Regras que ligam as duas:
- **Mesma chave, mesma nota:** nota importada por upload aparece como importada na lista da SEFAZ (reconciliação por chave); nota de entrada **cancelada** libera a linha para importar de novo (D11).
- **O upload continua indispensável:** a SEFAZ só entrega até 90 dias e só a partir do primeiro acesso do CNPJ (NT 2014.002 §3.4). Histórico e compras no CPF do sócio entram por XML (Fase 6 do `PLAN-DISTDFE`: importação em lote).
- **CNPJ alfanumérico:** `LeitorXmlNfe` lê chave e CNPJ do emitente com letras (a chave perdia as letras em `digitos()`).
