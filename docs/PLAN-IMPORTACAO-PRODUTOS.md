# PLAN-IMPORTACAO-PRODUTOS — importar produtos por planilha (Excel/CSV)

> Status: **implementado nas branches `feat/importacao-produtos` (30/10/2026)**. Falta a conferência visual no Firefox e o merge.
> Criado em 30/10/2026.

## 1. Objetivo

Na listagem de produtos, um botão leva a uma tela de importação. Nela o usuário baixa o
modelo de planilha ou envia a própria (.xlsx ou .csv). Se as colunas da planilha não forem as
do modelo, ele diz qual coluna dele corresponde a cada campo (ex.: "Nome" ← coluna "Título").
Depois de tudo validado, importa e os produtos são criados **na empresa do usuário logado**.

Principal público: quem migra de outro sistema (ver [[feedback_avisar_nao_travar]]) — a planilha
vem de fora, com nomes de coluna imprevisíveis e dados sujos. Por isso o mapeamento e a
validação linha a linha são o coração da tarefa, não um acabamento.

## 2. O que já existe e será reaproveitado

| Peça | Onde | Uso |
|---|---|---|
| Regras de validação de produto | `ProdutoController::store` (nome, sku, preço, ncm, cest, unidade, impostos) | Extrair para uma classe única usada pelo cadastro **e** pela importação, para não divergirem |
| SKU único por empresa + colisão nos 60 chars do `cProd` | `ProdutoController::store`, `Produto::skuQueColideNoCProd` | Conferir também **dentro da própria planilha** (duas linhas com o mesmo SKU) |
| Unidades e sinônimos (MT→M, UND→UN…) | `App\Support\Unidades::normalizar` | Normalizar a coluna unidade |
| GTIN com aviso | `App\Support\Gtin::aviso` | Aviso (não bloqueio) por linha |
| Estoque inicial | `ProdutoController::store` | O cadastro de produto novo grava `estoque_atual` direto no produto, **sem movimentação** e **sem `RegistradorDePreco`** (este só roda na edição). A importação faz igual |
| Escopo por empresa | `CompanyScope` + `Auth::user()->empresa_id` | `empresa_id` nunca vem da planilha |
| Permissão da área | `RequireArea::class . ':produtos'` | Mesmo middleware nas rotas novas |
| Padrão de upload em lote | `Compras\ImportacaoEmLote` + tela `ImportarNotaEntrada.tsx` | Mesmo estilo: limites no servidor, tela confere antes de enviar e traduz o 413 |
| Limite de upload | nginx `client_max_body_size 8M`; PHP `upload_max_filesize 32M` | O teto efetivo é **8 MB** (nginx) |

Faltam bibliotecas: não há leitor de xlsx nem no backend (`composer.json`) nem no frontend
(`package.json`).

## 3. Decisões de arquitetura (propostas)

**D1. Leitura da planilha no backend, não no navegador.**
O arquivo vai ao servidor, que lê, devolve o cabeçalho + amostra e valida. Motivo: a validação
(SKU duplicado no banco, colisão de `cProd`, unidade) precisa do banco de qualquer jeito, e
assim a regra mora num lugar só. Custo: sobe o arquivo duas vezes (ver D3).

**D2. Biblioteca: `openspout/openspout`** (leitura em streaming do xlsx, memória baixa; o CSV é lido com o PHP nativo, que dá controle de separador e codificação).
`phpoffice/phpspreadsheet` carrega a planilha inteira na memória e é pesada para 8 MB.
Fórmulas: lê o valor em cache; não executa nada. **Pedir confirmação antes de adicionar a
dependência** (ver §9).

**D3. Fluxo em 3 chamadas, com o arquivo guardado temporariamente.**
1. `POST /produtos/importacao/analisar` — recebe o arquivo, valida tipo/tamanho, grava em
   `storage/app/private/importacoes/{empresa}/{uuid}`, devolve `importacao_id`, colunas
   detectadas, 5 linhas de amostra, total de linhas e um **mapeamento sugerido**.
2. `POST /produtos/importacao/{id}/validar` — recebe o mapeamento, lê o arquivo guardado,
   valida todas as linhas e devolve o relatório (válidas / com erro / com aviso). **Não grava produto.**
3. `POST /produtos/importacao/{id}/confirmar` — grava as linhas válidas e apaga o arquivo.

Arquivo temporário: pertence a (empresa, usuário), expira em 1 h (comando agendado limpa o resto),
é apagado ao confirmar. Alternativa descartada: reenviar o arquivo em cada passo (simples, mas
estoura o limite de banda e o tempo em planilhas grandes).

**D4. Tudo ou parcial: o usuário escolhe na revisão.** Dois botões: **"Importar as N
corretas"** (padrão) e **"Cancelar e corrigir a planilha"**. Não há modo tudo-ou-nada à parte:
é o mesmo que cancelar e reenviar. Atenção: reenviar a planilha inteira depois de importação
parcial duplica as linhas sem SKU (não há como detectá-las); por isso o relatório de rejeitadas
(§6) é obrigatório, para reenviar só elas.

**D7. Validação: de linha só no backend; no frontend só o que se sabe antes de enviar.**
FE: tamanho, extensão, obrigatórios mapeados, coluna não repetida em dois campos. Todo o
resto (formato, SKU, `cProd`, unidade, NCM) é do BE, que é a autoridade e acessa o banco; o FE
só exibe o resultado. Evita duas cópias das regras divergindo e dispensa biblioteca xlsx no FE.

**D5. Limite de 500 linhas por planilha, tudo síncrono, sem fila (decidido).** Planilha
com mais que isso é recusada na análise, com mensagem pedindo para dividir. O limite também
mantém a revisão de erros viável para uma pessoa.

**D6. Idempotência.** Produto criado em lote não pode duplicar se o usuário clicar duas vezes
em "Importar": `confirmar` marca a importação como consumida dentro de transação, e a segunda
chamada devolve o resultado da primeira.

## 4. Campos da planilha

Obrigatórios: **nome**, **preço de venda** (a regra atual exige `> 0,01`).

Opcionais (decidido: **todos** os campos do cadastro de produto, exceto variação): SKU, código de
barras, preço de compra, unidade, NCM, CEST, estoque inicial, origem de fabricação, substituição
tributária, origem ICMS, alíquota ICMS, crédito SN (%), PIS, COFINS, IPI (CST, alíquota,
enquadramento). Os formatos e limites de cada um são os das regras do `store`.
`ativo` não é coluna: todo produto importado nasce ativo.

Fora do escopo: variações/modelos (grade) e os campos `modelo_id`, `chave_variacao`,
`variacao_rotulo`. Cada linha vira **produto simples**; o usuário agrupa depois no fluxo de grade.

Tratamento de valores (planilha brasileira):
- Decimal com vírgula e milhar com ponto (`1.234,56`) **e** formato `1234.56`; `R$` e espaços removidos.
- NCM/CEST com pontos (`6109.10.00`) → só dígitos; NCM com zero à esquerda perdido pelo Excel
  (`61091000` virando número, ou 7 dígitos) → aviso, sem adivinhar.
- Código de barras e SKU **sempre como texto** (Excel vira `7,89E+12`; detectar e rejeitar com mensagem clara).
- Unidade passa por `Unidades::normalizar`.
- CSV: detectar separador (`;` ou `,`) e codificação (UTF-8 com/sem BOM, Windows-1252).
- Segurança: valor que começa com `=`, `+`, `-`, `@` é gravado como texto literal e, no
  modelo e em qualquer exportação futura, escapado (CSV/fórmula injection).

## 4.1 Identificação de produto repetido (decidido)

Cada linha tem **uma chave**, a primeira que existir na ordem **SKU → código de barras → nome**:

| A linha traz | Chave | Repetido no sistema | Repetido na planilha |
|---|---|---|---|
| SKU | SKU | rejeitada: "Já existe produto com este SKU" | rejeitada |
| sem SKU, com código de barras | código de barras | rejeitada: "Já existe produto com este código de barras" | rejeitada |
| sem SKU e sem código de barras | **nome** (sem acento, sem maiúscula, espaços colapsados) | rejeitada: "Já existe produto com este nome" | rejeitada |

Regras complementares:
- **Código de barras repetido vale sempre**, mesmo que a linha tenha SKU novo: se o código de barras
  já é de outro produto, a linha é rejeitada. É regra só da importação; o cadastro manual hoje
  permite repetir, e **não será alterado sem confirmar com você**.
- A busca no sistema inclui produtos **inativos** (o SKU único já os conta).
- Duplicata dentro da planilha: vale a **primeira ocorrência**; as seguintes são rejeitadas
  citando a linha da primeira ("repetido da linha 12").
- Consequência: **reenviar a mesma planilha não duplica nada**, tenha ela SKU, código de barras
  ou só nome.

**O usuário precisa ver isso com clareza**, separado dos erros de dado:
- No resumo da revisão, uma categoria própria: *"Já cadastrados no sistema: N"* e *"Repetidos na
  planilha: N"*, distintas de *"Com erro nos dados: N"*.
- Cada linha mostra a chave usada e o produto que bate: "Já cadastrado: *Camiseta Básica* (SKU
  CB-01)", ou "Repetido da linha 12".
- Quando a chave foi o nome, a mensagem diz isso e que para diferenciar basta informar SKU ou
  código de barras ("Camiseta" em tamanhos diferentes precisa de SKU próprio).
- O mapeamento avisa que, sem SKU nem código de barras, o nome é a chave.
- Na planilha de rejeitadas, o motivo vem escrito do mesmo jeito.
- Teste: reenviar a mesma planilha (com SKU, só com código de barras e só com nome) não cria nada
  e informa a duplicidade; planilha com duas linhas iguais cria só a primeira.

## 5. Backend

- Rotas em `routes/api.php`, dentro do grupo `RequireArea::class . ':produtos'`, **antes** de
  `/produtos/{produto}` (senão `importacao` é lido como id).
- `ProdutoImportacaoController` (fino) + serviços em `app/Services/Produtos/`:
  - `LeitorDePlanilha` — abre xlsx/csv, devolve cabeçalho e linhas em streaming; limites de
    linhas, colunas e bytes; rejeita xlsx com `.zip` malicioso (limite de descompressão como
    em `ImportacaoEmLote`).
  - `SugeridorDeMapeamento` — casa cabeçalhos com campos por normalização (minúsculas, sem
    acento/pontuação) + sinônimos ("título", "descrição", "produto"→nome; "preço", "valor",
    "preço de venda"→preço_venda; "ean", "gtin", "cód. barras"→código_barras; "código",
    "ref"→sku…). É só sugestão; o usuário sempre pode trocar.
  - `ValidadorDeLinhaDeProduto` — usa as regras extraídas do `store`, mais a chave de duplicidade da §4.1 (SKU, código de barras ou nome)
    no sistema e na planilha. Devolve erros (bloqueiam a linha) e avisos (não bloqueiam, ex.: GTIN inválido).
  - `ImportadorDeProdutos` — transação, cria `Produto` com `empresa_id` do usuário e `estoque_atual` direto, como o `store` (sem
    movimentação, sem histórico de preço); grava auditoria (`Auditoria`) com o resumo.
- `GET /produtos/importacao/modelo` — devolve o template (xlsx gerado na hora com os cabeçalhos e
  uma aba "Instruções" com as regras e exemplos de cada coluna; opção de csv). **Sem linha de exemplo
  na aba de dados** (esquecida lá, viraria um produto de verdade); as colunas de código saem
  formatadas como Texto para o Excel não tirar o zero do NCM. *(Desvio do texto original, que previa linha de exemplo.)*
- Limites no servidor (constantes, como em `ImportacaoEmLote`): 8 MB, 500 linhas, 30 colunas,
  extensões `.xlsx`/`.csv` conferidas **pelo conteúdo**, não só pela extensão. `.xls` antigo não
  é suportado (a mensagem manda salvar como xlsx).
- Rate limit na rota de análise (arquivo grande é custo de CPU).
- Mensagens de erro em português, sem vazar caminho/stack (ver `SECURITY-ERROR-HANDLING.md`).

## 5.1 Performance (meta: 500 linhas sem o usuário sentir travamento)

Metas medidas em teste com planilha de 500 linhas, nos containers: **analisar < 2 s, validar < 3 s,
confirmar < 5 s**. Se alguma estourar, otimiza-se antes de seguir; fila só se a medição pedir.

O custo está no banco, não na leitura. Regras:

- **Zero consulta por linha na validação.** Os SKUs existentes da empresa que aparecem na
  planilha vêm de **uma** consulta (`whereIn`), e a checagem de SKU repetido na planilha é em
  memória. A colisão nos 60 caracteres do `cProd` (`skuQueColideNoCProd`) só roda para SKU com
  60+ caracteres, que é raro. Prova: teste que **conta as consultas** e exige que o número não
  cresça com as linhas (500 linhas = mesma ordem de consultas que 5).
- **Ler a planilha uma vez só.** Na validação, as linhas já normalizadas e o resultado ficam
  guardados no arquivo temporário; `confirmar` usa esse resultado e não reabre o xlsx nem revalida
  do zero (só reconfere SKU no banco, numa consulta, porque pode ter mudado entre as etapas).
- **Leitura em streaming** (openspout) e parada ao passar de 500 linhas, **sem ler o resto**:
  planilha de 200 mil linhas é recusada barato. Idem para colunas.
- **Gravação numa única transação**, com inserção em blocos. Começa simples (criar cada produto dentro da transação, ~500 inserts
  para 500 linhas, bem abaixo de 1 s no Postgres esperado; a medir); **medir antes de otimizar**. Só se passar da meta, passa a
  inserção em lote (`insert` em blocos de 100, recuperando os ids por SKU).
- **Resposta pequena**: `validar` devolve contagens, os problemas agrupados e **no máximo 5 exemplos
  por grupo**, nunca as 500 linhas. A lista completa vai só na planilha de rejeitadas, gerada
  sob demanda a partir do resultado guardado (sem revalidar).
- **Limites de tempo/memória**: `max_execution_time` e `memory_limit` conferidos no container
  para o pior caso (500 linhas × 30 colunas); timeouts de nginx/proxy maiores que a meta.
- **Rate limit** na análise e na validação (arquivo é custo de CPU).

## 6. Frontend

- Botão **"Importar planilha"** em `Produtos.tsx`, ao lado de "Novo produto", visível só para
  quem tem a área `produtos` (como os outros botões).
- Nova página `ImportarProdutos.tsx` (rota `/produtos/importar`), com 4 estados em tela única:
  1. **Enviar** — área de envio e, ao lado, o botão **opcional** "Baixar modelo" (xlsx e csv);
     o modelo não é obrigatório, qualquer planilha pode ser enviada e mapeada. **Sempre visível**:
     "Tamanho máximo: 8 MB · formatos .xlsx e .csv · até 500 linhas". A tela confere o tamanho
     **antes** de enviar e traduz o 413 do nginx (padrão do `ImportarNotaEntrada`).
  2. **Mapear colunas** — uma linha por campo do sistema (Nome\*, Preço de venda\*, SKU…) com um
     seletor das colunas da planilha, já pré-preenchido pela sugestão; mostra 3 valores de exemplo
     da coluna escolhida; marca obrigatórios não mapeados; uma coluna não pode servir a dois
     campos; opção "não importar este campo". Se o cabeçalho já bate com o modelo, esta etapa
     aparece resumida ("Reconhecemos todas as colunas") com opção de revisar.
  3. **Revisar** — resumo (total / prontas / com aviso / com erro) e os problemas **agrupados
     por tipo**, não por linha ("Preço de venda inválido: 340 linhas"), cada grupo expansível com
     5 exemplos (nº da linha e valor). Erro (bloqueia) e aviso (não bloqueia) em cores diferentes.
     Se quase todas as linhas falham no mesmo campo, aviso de que a coluna mapeada pode estar
     errada, com atalho para voltar ao mapeamento. "Baixar linhas rejeitadas" gera planilha só com
     elas, **com as colunas e a ordem da planilha original** + coluna "Motivo" no fim (ignorada se reenviada), para corrigir e reenviar sem refazer o mapeamento. Botões: **"Importar as N corretas"**
     (habilita com ao menos uma válida) e **"Cancelar e corrigir a planilha"**. Sem edição de
     célula na tela na v1.
  4. **Resultado** — quantos criados, quantos rejeitados, link de volta para a listagem.
- **Feedback de carregamento em cada espera** (nada de tela parada):
  - *Envio:* barra de progresso real do upload (`onUploadProgress`) e, ao terminar, "Lendo a planilha…".
  - *Validação:* indicador com texto "Validando N linhas…" (sem barra falsa de porcentagem: a
    chamada é única, então spinner indeterminado honesto).
  - *Importação:* "Importando N produtos… não feche esta página", tela bloqueada contra clique
    duplo (botões desabilitados desde o primeiro clique) e aviso se tentar sair (`beforeunload`).
  - Cancelar durante a leitura/validação aborta a requisição (`AbortController`).
  - Erro de rede/timeout vira mensagem clara com "tentar de novo", sem perder o arquivo já enviado
    (o `importacao_id` continua válido por 1 h).
  - Tabelas da tela renderizam só o necessário: amostra de 5 linhas no mapeamento, grupos de erro
    com 5 exemplos.
- Serviço em `services/api.ts`; tipos em `types/index.ts`. Rota em `App.tsx` e permissão em
  `contexts/permissoes.ts`.
- Textos em português, mesma linguagem visual das telas existentes (ver `UX-DESIGN-NOTES.md`).

## 7. Segurança e isolamento (não negociável)

- `empresa_id` vem **só** de `Auth::user()`; coluna "empresa" na planilha é ignorada.
- Arquivo temporário e `importacao_id` são amarrados a empresa + usuário; outro usuário/empresa
  com o id recebe 404. Teste cobre isso.
- Validar tipo pelo conteúdo (magic bytes), limite de descompressão do xlsx, limite de linhas.
- Sem execução de fórmula/macro; `.xlsm` rejeitado.
- Texto da planilha escapado na tela (React já faz) e protegido contra fórmula no export do relatório de erros.
- Registrar na auditoria quem importou, quando, quantos.
- Atualizar `PLAN-SEGURANCA.md` ao fechar (regra do projeto).

## 8. Etapas (portão: revisar → testar → commitar → PROGRESS antes da próxima)

Andamento (branch `feat/importacao-produtos` nos 4 repositórios):

- [x] **I1** — `RegrasDeProduto` extraída; 33 testes de produto + 7 novos passam (30/10/2026)
- [x] **I2** — leitor de planilha (xlsx via openspout 5.3; CSV com o PHP nativo para controlar separador e codificação); 35 testes novos (30/10/2026)
- [x] **I3** — mapeamento, validador, normalização, duplicidade, resumo (hoje, 30/10/2026); 206 testes de produto passam
- [x] **I4** — importador + rotas (30/10/2026); 500 linhas medidas: validar ~0,3 s com 1 consulta, confirmar ~0,15 s; 41 testes de feature
- [x] **I5** — frontend (30/10/2026): tsc e vite build passam, `npm run verificar:importacao-produtos` verde; conferência visual no Firefox é do Allan
- [x] **I6** — E2E (30/10/2026): 9 casos × Chromium e Firefox, 18 passam; suíte normal no Chromium sem regressão nova
- [x] **I7** — limpeza, auditoria, documentação (30/10/2026): comando agendado, PLAN-SEGURANCA, CLAUDE.md da API e do FE

| Etapa | Entrega | Prova de pronto |
|---|---|---|
| **I1** | Extrair regras de validação do `store` para classe compartilhada | Testes do cadastro atuais passam sem alteração |
| **I2** | `LeitorDePlanilha` (xlsx/csv, separador, codificação, limites) | Testes com fixtures: xlsx do Excel, csv `;` Windows-1252, csv com BOM, arquivo corrompido, xlsm, arquivo de 8 MB+ |
| **I3** | `SugeridorDeMapeamento` + `ValidadorDeLinha` + normalização de números/NCM/GTIN | Testes por caso (vírgula/ponto, `7,89E+12`, SKU repetido na planilha e no banco, colisão de 60 chars) |
| **I4** | `ImportadorDeProdutos` + rotas analisar/validar/confirmar/modelo | Teste de feature nos containers: cria na empresa certa, **não** cria na outra, clique duplo não duplica, `estoque_atual` gravado igual ao cadastro manual (sem movimentação). **Performance:** fixture de 500 linhas dentro das metas da §5.1 e teste de número de consultas constante |
| **I5** | Frontend: botão, tela, mapeamento, revisão, resultado | Conferido por mim com build; loading de cada etapa presente; **conferência visual no Firefox é sua** |
| **I6** | E2E no `gestaofacil-e2e`: baixar modelo → preencher → importar; planilha com colunas trocadas → mapear | Playwright verde, com overlay de banco |
| **I7** | Limpeza de temporários (comando agendado), auditoria, doc, `PLAN-SEGURANCA` | Arquivo expirado some; checklist atualizado |

## 9. Perguntas (todas respondidas)


- ~~**Q1. Produto que já existe.**~~ Resolvida: rejeita e informa; chave SKU → código de barras → nome (§4.1).
- ~~**Q2. Campos.**~~ Resolvida: todos os do cadastro, menos variação (§4).
- ~~**Q3. Linhas com erro.**~~ Resolvida: o usuário escolhe na revisão (D4).
- ~~**Q4. Variações.**~~ Resolvida: fora; cada linha é produto simples.
- ~~**Q5. Tamanho.**~~ Resolvida: 500 linhas, síncrono (D5).
- ~~**Q6. Biblioteca.**~~ Resolvida: `openspout/openspout` autorizado.
- ~~**Q7. Estoque inicial.**~~ Resolvida: igual ao cadastro de produto novo (grava o saldo, sem movimentação).
- ~~**Q8. Preço zero.**~~ Resolvida: mantém a regra do cadastro; linha rejeitada com mensagem clara.
- ~~**Q9. Permissão.**~~ Resolvida: a mesma do cadastro de produto (área `produtos`).
