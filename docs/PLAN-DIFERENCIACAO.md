# PLAN-DIFERENCIACAO.md — Como se destacar além de "PDV que emite nota"

**Status:** PLANO / estratégia. Escrito em 2026-10-20. Frameworks citados vêm da literatura de
estratégia e SaaS (referências no §9); a aplicação ao produto é análise própria, a validar com
lojistas (§7). Nada aqui está implementado além do que o §2 marca como existente.

**Documentos relacionados:** [`PLAN-LANCAMENTO.md`](./PLAN-LANCAMENTO.md) ·
[`PLAN-PRE-BETA.md`](./PLAN-PRE-BETA.md) · [`PLAN-IMPORTACAO-XML.md`](./PLAN-IMPORTACAO-XML.md) ·
[`PLAN-DISTDFE.md`](./PLAN-DISTDFE.md)

---

## 1. Tese

> **Todo concorrente mostra quanto a loja vendeu. Nós mostramos quanto ela ganhou.**

O pequeno lojista precifica no olho: pega o preço da nota, multiplica por 2 e torce. O custo real
está escondido na nota do fornecedor — desconto por item (30% do valor na nota real da Roma
Aviamentos), IPI, frete, ST e o fator de conversão escrito na descrição ("PCT C/100"). Ninguém faz
essa conta à mão para 313 itens.

**O sistema já faz essa conta na entrada da nota.** O diferencial é transformar isso de um passo da
importação em **o centro do produto**: margem real por produto, por venda e por dia; alerta quando o
fornecedor sobe o preço; sugestão do que comprar.

Categoria proposta: não "PDV" nem "ERP" (lotadas), e sim **"o sistema que mostra o lucro de cada
item, direto da nota do fornecedor"**.

Base de evidência do problema: falta de capital de giro, controle de custos e precificação aparecem
entre as causas citadas de fechamento de pequenas empresas em levantamentos que citam o Sebrae (§9).
O número exato precisa ser conferido no relatório original antes de usar em material público.

## 2. Ativos que já existem (conferido no código em 20/10/2026)

| Ativo | Onde |
|---|---|
| Custo real por item na entrada (desconto, frete, seguro, outros, ST, IPI, fator de conversão) | `nota_entrada_itens.preco_custo_calc`, `preco_compra_calc`, `fator_conversao` |
| Margem aplicada na conferência (sobre custo ou outra base) | `ConferenciaNotaEntrada.tsx` (margem, `margem_base`) |
| Vínculo item do fornecedor ↔ produto, reaproveitado nas próximas notas | `produto_fornecedor_codigos` |
| Histórico de preço de venda | `produto_preco_historico` |
| Notas de compra chegam sozinhas da SEFAZ | DistDFe, em produção |
| XML em lote/ZIP (para carregar o histórico que o contador já tem) | PLAN-DISTDFE Fase 6 |

Concorrentes da faixa de preço importam XML; o que **não** encontramos anunciado por eles é margem
real derivada da nota com fator de conversão e alerta de custo. Conferir isso nos testes de produto
dos concorrentes antes de afirmar em material público.

## 3. Os frameworks aplicados

### 3.1 Jobs to be Done (Christensen; Ulwick)
O lojista não "contrata" um sistema para emitir nota. A nota é obrigação. Os trabalhos reais:

| Tipo | Trabalho |
|---|---|
| Funcional | Saber se está ganhando dinheiro; repor o que vende sem encalhar o que não vende; cumprir o fisco sem pensar nisso |
| Emocional | Dormir tranquilo: não tomar multa, não ser enganado pelo fornecedor, não ficar sem troco no fim do mês |
| Social | Ser visto pelo contador e pelos fornecedores como alguém que tem o negócio sob controle |

**Conclusão:** emitir nota é requisito básico. Lucro e reposição são o trabalho que paga a assinatura.

### 3.2 Posicionamento (April Dunford, *Obviously Awesome*)
1. **Alternativas reais do cliente:** caderno + planilha + emissor barato + "pergunto ao contador".
   Bling/Tiny para quem já tentou e achou complicado.
2. **Atributos únicos:** nota do fornecedor vira estoque e custo real sozinha; margem por item;
   contador conectado.
3. **Valor:** saber o lucro de verdade e corrigir preço antes de perder dinheiro, sem digitar nada.
4. **Cliente ideal:** loja de balcão que compra com nota, muitos itens por nota, dono que também é o
   comprador.
5. **Categoria:** gestão de margem para loja de balcão (com PDV e nota inclusos, não o contrário).

### 3.3 Estratégia do Oceano Azul — matriz ERRC (Kim & Mauborgne)

| Eliminar | Reduzir |
|---|---|
| Lojista configurando imposto (CFOP, CST, NCM) — passa para o contador | Telas e módulos; relatórios que ninguém lê |
| Digitação de produto | Treinamento (o sistema se explica) |
| Implantação cobrada | Tempo até a primeira venda |

| Elevar | Criar |
|---|---|
| Automação da entrada de mercadoria | **Margem real por item, venda e dia** |
| Avisos proativos (certificado, custo, estoque) | **Alerta de aumento de custo do fornecedor** |
| Atendimento humano no WhatsApp | **Contador como co-usuário** (configura o fiscal, recebe o mês fechado) |
| | **Resumo diário no WhatsApp do dono** |

### 3.4 Atravessando o Abismo (Geoffrey Moore)
- **Cabeça de praia:** um segmento + uma região. Dominar armarinho/aviamentos/papelaria (ou o
  segmento que os contadores mais atendem, PLAN-PRE-BETA §1) **na sua cidade** antes de abrir.
- **Produto completo:** para esse segmento, o produto inclui a implantação concierge (§5) e o
  contador. Sem isso o lojista conservador não troca de sistema.
- **Pinos de boliche:** o segmento seguinte é o vizinho que compartilha a mesma dor (utilidades,
  pet, cosméticos, e só depois moda).

### 3.5 7 Powers (Hamilton Helmer)

| Poder | Aplicação |
|---|---|
| **Custo de troca** | Quanto mais notas de compra entram, mais o histórico de custo e fornecedor vale. Sair significa perder a memória da loja |
| **Contraposicionamento** | Bling e Tiny crescem com e-commerce e marketplace; dar prioridade ao balcão e ao contador vai contra o próprio modelo deles |
| **Efeito de rede (fraco, local)** | Cada contador parceiro traz vários clientes, e o painel dele fica mais útil com cada cliente a mais |

### 3.6 Modelo Kano
- **Obrigatório** (se falhar, cancela; se funcionar, ninguém elogia): nota sai, PDV rápido, não perde venda.
- **Desempenho** (quanto mais, melhor): velocidade do PDV, quantidade de itens importados sem ajuste.
- **Encantamento** (ninguém pede, todo mundo comenta): "a nota do fornecedor virou estoque com preço",
  "o sistema me avisou que o fornecedor subiu 15%", resumo do dia no WhatsApp.

Regra: não investir em encantamento enquanto o obrigatório falhar (PLAN-PRODUCAO primeiro).

### 3.7 10x em uma coisa (Peter Thiel, *De Zero a Um*)
Ser **10x melhor em uma coisa** em vez de 10% melhor em tudo. A coisa: **colocar uma nota de compra
em estoque, com custo e preço certos**. Medida: de horas de digitação para minutos de conferência.

### 3.8 Fazer coisas que não escalam (Paul Graham)
No começo, o Allan carrega o histórico do cliente pessoalmente (§5). Isso convence o cliente,
alimenta o produto com dados reais e ensina o que automatizar.

## 4. Funcionalidades que materializam a tese

Continuam a numeração do PLAN-LANCAMENTO §7.

| # | Funcionalidade | Base existente | Antes do beta? |
|---|---|---|---|
| F17 | **Margem real** por produto, por venda e "lucro de hoje" no dashboard (hoje mostra faturamento) | `preco_custo_calc` na entrada | **Sim** — é o pitch |
| F18 | **Alerta de custo:** "Fornecedor X subiu 12% no item Y; sua margem caiu de 40% para 28%. Reajustar para R$ Z?" com um clique e etiqueta nova (F2) | Comparar custo da entrada nova com a anterior | **Sim** |
| F19 | Comparação de fornecedores por item (mesmo EAN, fornecedores diferentes, preço ao longo do tempo) | `produto_fornecedor_codigos` + itens das notas | Depois |
| F20 | **Lista de reposição:** vendeu N em 30 dias, estoque cobre X dias, último fornecedor e preço; enviar a lista pelo WhatsApp ao representante | Vendas + estoque + notas | Depois |
| F21 | **Fiscal configurado pelo contador:** padrões de NCM/CST/CFOP definidos no painel dele (F8) | Padrões de impostos já existem na empresa | Depois (junto com F8) |
| F22 | **Mês fechado para o contador:** XMLs de entrada e saída, resumo e pendências (rejeições, notas sem manifestação) entregues no dia 1 | ZIP de XML e DistDFe | Depois (junto com F8) |
| F23 | **Resumo diário no WhatsApp do dono:** vendeu, lucrou, o que acabou, custos que subiram | F17, F18 | Logo após o beta |

Decisão aberta para F17: **custo médio ponderado** (mais correto para margem) ou **último custo**
(mais simples e o que o lojista entende para reajustar preço). Recomendo mostrar margem sobre o
custo médio e usar o último custo no alerta de reajuste (F18).

## 5. Implantação concierge (o produto completo do §3.4)

Promessa: **"Mande os XMLs de compra dos últimos 90 dias. Em até 48 horas sua loja está com estoque
cadastrado, custo real e preço sugerido."**

- O DistDFe não traz notas antigas para cliente novo (NT 2014.002, sem NSU retroativo), mas o
  **contador já tem esses XMLs** — o upload em lote/ZIP resolve. Mais um motivo para o contador ser
  parceiro.
- O Allan faz a conferência junto com o lojista por videochamada ou presencialmente nos primeiros
  20 clientes; registrar o que travou para automatizar depois.
- Contagem física do estoque fica com a loja; o sistema já entra com os itens e custos.

## 6. Mensagem

- **Título:** "Saiba quanto você ganha em cada item. Direto da nota do fornecedor."
- **Apoio:** "A mercadoria chega, o estoque se cadastra sozinho com o custo certo. O sistema avisa
  quando o fornecedor sobe o preço. A nota fiscal sai na venda e seu contador recebe tudo pronto."
- **Prova:** vídeo de 60 segundos com a nota de 313 itens entrando e virando estoque com margem.
- **Não usar:** "ERP completo", "PDV moderno", "tecnologia de ponta" — todo concorrente diz isso.

## 7. Como validar antes de construir tudo

1. **Teste de mensagem com 10 lojistas** (piloto, indicados pelos contadores): mostrar as duas
   promessas, "PDV com nota fiscal" e "saiba quanto ganha em cada item", e perguntar qual faria trocar
   de sistema e quanto pagariam.
2. **Página com duas versões** no Google Ads local (R$ 200 de teste): medir cliques e cadastros na
   lista de espera de cada versão.
3. **Prova com dados reais:** rodar F17 sobre as notas da empresa piloto e mostrar ao dono a margem
   real de 10 itens que ele acha que conhece. Se ele se surpreender, a tese está viva.

Critério: se menos da metade dos lojistas preferir a mensagem de margem, rever a tese antes de F19–F23.

## 8. Impacto nos outros planos

- **PLAN-PRE-BETA:** F17 e F18 entram antes do beta. Se faltar tempo, F3 (troca) cede antes de F17 —
  exceto se o beta for de moda.
- **PLAN-LANCAMENTO §4:** a promessa passa a ser a margem; "estoque sem digitação" vira o meio de
  chegar nela.

## 9. Referências

Literatura:
- Clayton Christensen et al., *Competing Against Luck* (2016) — Jobs to be Done.
- Anthony Ulwick, *Jobs to be Done: Theory to Practice* (2016).
- April Dunford, *Obviously Awesome* (2019).
- W. Chan Kim e Renée Mauborgne, *A Estratégia do Oceano Azul* (2005) — matriz ERRC.
- Geoffrey Moore, *Atravessando o Abismo* (1991, ed. rev. 2014).
- Hamilton Helmer, *7 Powers* (2016).
- Noriaki Kano, modelo de satisfação (1984).
- Peter Thiel, *De Zero a Um* (2014).
- Paul Graham, "Do Things that Don't Scale" (2013).

Problema do lojista (fontes secundárias que citam o Sebrae — conferir o original):
- [Repositório UFU — gestão financeira e contábil](https://repositorio.ufu.br/bitstream/123456789/36862/1/Gest%c3%a3oFinanceiraCont%c3%a1bil.pdf)
- [Meu Contador Online — motivos de fechamento](https://www.meucontadoronline.com.br/blog/motivos-de-fechamento-de-pequenas-empresas/)
- [Revista Gestão & Sociedade (UnB) — estoque e saúde financeira](https://periodicos.unb.br/index.php/rgs/article/download/2499/2225/4337)
