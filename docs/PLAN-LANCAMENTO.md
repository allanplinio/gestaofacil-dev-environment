# PLAN-LANCAMENTO.md — Plano de lançamento comercial

> **EM REVISÃO (22/10/2026):** a direção do negócio mudou para **empresa nova, comércio e serviço,
> financeiro no centro**. Segmento, promessa, calendário e funcionalidades deste documento ainda
> partem de "loja que troca de sistema". Vale o [`PLAN-DIRECAO.md`](./PLAN-DIRECAO.md) onde houver
> conflito; este plano será reescrito após as decisões R1–R6.

**Status:** PLANO. Escrito em 2026-10-20 e reescrito no mesmo dia para refletir as decisões de
segmento, diferenciação e preço. Preços de concorrentes vêm de páginas de fornecedores e blogs
(fontes no §13) e **precisam ser conferidos nos sites oficiais antes de qualquer material público**.
Preços próprios, metas e capacidade de suporte são hipóteses a validar com os primeiros clientes.

**Documentos relacionados:** [`PLAN-EXECUTIVO.md`](./PLAN-EXECUTIVO.md) (resumo de uma página) ·
[`PLAN-DIFERENCIACAO.md`](./PLAN-DIFERENCIACAO.md) (tese de margem) ·
[`PLAN-NEGOCIO.md`](./PLAN-NEGOCIO.md) (preço, GTM, números) ·
[`PLAN-PRE-BETA.md`](./PLAN-PRE-BETA.md) (F1–F5 detalhadas e escolha do segmento) ·
[`PLAN-PRODUCAO.md`](./PLAN-PRODUCAO.md) · [`PLAN-INFRA.md`](./PLAN-INFRA.md) ·
[`PLAN-FINANCEIRO.md`](./PLAN-FINANCEIRO.md) · [`PLAN-DISTDFE.md`](./PLAN-DISTDFE.md)

**Quem decide o quê:** este documento é o plano de lançamento (calendário, canais, funcionalidades).
Preço e números detalhados vivem no PLAN-NEGOCIO; se divergirem, vale o PLAN-NEGOCIO.

---

## 1. Contexto e restrições

| Item | Situação |
|---|---|
| Equipe | 1 pessoa (Allan); suporte por WhatsApp; ajudante depois |
| Orçamento de aquisição | ~R$ 1.000/mês |
| Canal disponível | ~5 escritórios de contabilidade conhecidos, parceria ainda não fechada |
| Piloto | 1 empresa vai começar a usar |
| CNPJ | Ainda não tem; quer captar clientes antes de abrir |
| Público | Pequenas e médias lojas de balcão **que compram com nota**. Primeiro segmento definido pela carteira dos contadores; sem dado, armarinho / aviamentos / papelaria. Moda, calçados e acessórios na segunda onda (PLAN-PRE-BETA §1) |
| Infra | VPS ~R$ 50/mês no piloto, ~R$ 80/mês até 20 clientes (PLAN-INFRA §3) |
| Fora do foco agora | MEI. A obrigatoriedade de nota para venda a PF não foi aprovada e pode não passar |

## 2. Mercado

| Concorrente | Preço mensal encontrado | Leitura |
|---|---|---|
| Bling | Entrada R$ 60 (Cobalto) | Genérico, forte em e-commerce |
| Olist/Tiny | R$ 66 / R$ 177 / R$ 390 / R$ 948 | Mesmo perfil do Bling |
| Vhsys | R$ 169 / R$ 499 | PDV incluso |
| Mais PDV | R$ 49,90 a R$ 149,90 | Já anuncia "grade + NFC-e" para moda |
| Conta Azul | A partir de R$ 149,90 | Financeiro; programa de parceiros com contadores (5 níveis, +10 mil parceiros) |

Faixa citada para loja de roupa: **R$ 100 a R$ 250/mês**.

**Leitura:** preço não diferencia, porque há opções baratas e conhecidas. As brechas são:
1. Bling e Tiny pensam em quem vende online. A loja de balcão é cliente de segunda classe neles.
2. O lojista pequeno tem medo de nota fiscal, certificado e SEFAZ. Quem tirar esse medo ganha.
3. Cadastrar estoque é a maior barreira para trocar de sistema. Quem cadastra sozinho a partir da nota
   do fornecedor elimina a maior dor da migração.

### 2.1 Outros players (análise de 20/10/2026)

Não são o mesmo tipo de concorrente. Três grupos:

| Grupo | Quem | Preço encontrado | O que significa para nós |
|---|---|---|---|
| **API fiscal** (vende para software houses) | TecnoSpeed PlugNotas, NFE.io, Spedy API (e Focus NFe, Brasil NFe) | PlugNotas sob consulta, por licença/CNPJ; NFE.io NFC-e R$ 220/mês até 2.000 notas, NF-e R$ 265/mês até 500 (páginas antigas); Spedy API sob consulta; Focus NFC-e R$ 62,90/mês por CNPJ; Brasil NFe R$ 49,90 ilimitado | Concorrem com o **nfe-api**, não com o produto. Quem monta um ERP sobre elas paga por nota ou por CNPJ; nós não. |
| **Emissor simples** (vende para a empresa) | Emitte, Spedy Emissor | Emitte R$ 59,90 / 79,90 / 119,90, por faixa de faturamento (até 81 mil / até 360 mil / acima); Spedy R$ 66,75 a R$ 186,75 por volume de notas (preço promocional) | Teto do que o lojista paga **só pela nota**. Nosso Balcão (R$ 69) fica nessa faixa entregando PDV e estoque junto. |
| **Ferramenta do contador** | HubCount | Sob proposta; diz atender +1.000 escritórios com BI, alertas fiscais e atendimento | Não concorre. Mostra que o contador paga para monitorar clientes: reforça o painel do contador (F8) e é possível parceiro/integração no futuro. |

**Conclusões**
1. **Custo por nota é vantagem nossa.** Concorrentes que dependem de API fiscal pagam por nota ou por
   CNPJ. Com o nfe-api próprio podemos anunciar **"notas ilimitadas em todos os planos"**. Conferir o
   custo real de servidor antes de prometer. **Conferido:** PLAN-INFRA dimensiona pelo pior caso
   (4.400 notas/mês por cliente) e o custo fica em R$ 4–16 por cliente (PLAN-NEGOCIO §5.2).
2. **O custo escondido é manutenção.** O que essas APIs vendem é acompanhar notas técnicas, mudanças
   de SEFAZ e a reforma tributária (IBS/CBS em 2027, ver `PLAN-REFORMA-PL010.md`). Esse trabalho é
   nosso; reservar tempo fixo para ele no calendário.
3. **Não vender API (decisão do Allan, 20/10/2026).** O nfe-api é infraestrutura interna do produto,
   não está à venda e não entra em reavaliação. Opção retirada do plano.
4. **Preço por faixa de faturamento** (modelo Emitte) foi considerado e não adotado: o preço é por
   loja e funcionalidade (§6). Fica como alternativa a testar se a conversão do plano Loja for baixa.

Fontes: [PlugNotas](https://pages.tecnospeed.com.br/api-emissao-de-notas-plugnotas),
[NFE.io NFC-e](https://nfe.io/precos/emissao-nfce/), [NFE.io NF-e](https://nfe.io/precos/emissao-nfe/),
[Spedy](https://spedy.com.br/ecommerce), [Spedy API](https://spedy.com.br/api),
[Emitte](https://emitte.com.br/preco/), [HubCount](https://www.hubcount.com.br/planos),
[Focus NFe](https://focusnfe.com.br/precos/), [Brasil NFe](https://www.brasilnfe.com.br/).

## 3. O que o produto já tem (conferido no front em 20/10/2026)

- PDV com NFC-e (PF e PJ) e pedido com NF-e; cancelamento, CC-e, inutilização.
- Produto com código de barras; estoque com movimentação e histórico.
- **Importação e conferência de XML de compra** e **busca automática de notas de entrada na SEFAZ**
  (DistDFe, testada em produção pelo Allan em 20/10/2026, varredura diária).
- Download dos XMLs do período em `.zip` (tela Notas fiscais), útil para o contador.
- Alerta de vencimento do certificado; multiusuário com perfis; cadastro de empresa pela plataforma.

**Não encontrado no front:** grade cor/tamanho, etiqueta, troca/vale-troca, condicional, crediário,
envio de cupom por WhatsApp, modo offline, cobrança da assinatura (planos existem com preço 0 e
limites que nada lê).

## 4. Posicionamento e linguagem

**Público-alvo:** dono de loja de balcão com 1 a 3 pessoas, faturamento até ~R$ 360 mil/ano, que
compra de distribuidores com nota (muitos itens por nota) e hoje usa caderno, planilha ou um sistema
que acha caro e complicado.

**Promessa:** *"Saiba quanto você ganha em cada item. A mercadoria chega, o estoque se cadastra
sozinho com o custo certo. Vendeu, a nota sai. Seu contador recebe tudo pronto."*

Quatro pilares, em ordem (justificativa em PLAN-DIFERENCIACAO):
1. **Margem real** — custo de verdade tirado da nota do fornecedor (desconto, IPI, frete, ST, fator de
   conversão), margem por item e por dia, alerta quando o fornecedor sobe o preço.
2. **Estoque sem digitação** — a nota do fornecedor vira cadastro (DistDFe + conferência de XML). É o
   meio que torna a margem possível.
3. **Nota fiscal sem medo** — cupom em segundos, aviso de certificado, linguagem humana nos erros.
4. **Contador junto** — XML organizado, painel dele, mês fechado.

**Compromissos de venda** (contra as dores dos concorrentes, PLAN-NEGOCIO §1): resposta humana no
WhatsApp em até 1 hora útil; preço travado 12 meses e reajuste nunca acima do IPCA com 60 dias de
aviso; PDV no navegador sem instalar nada; notas e usuários ilimitados.

**Linguagem**
- Use: "cupom fiscal", "dar baixa", "mercadoria que chegou", "peça parada", "o contador recebe".
- Evite fora da tela técnica: NFC-e, CSC, SEFAZ, modelo 65, DistDFe, NSU, manifestação.
- Tom: direto, próximo, sem gíria de startup. Erro sempre diz o que fazer:
  "Seu certificado vence em 7 dias. Chama a gente no WhatsApp que ajudamos a renovar."

## 5. Nome e marca

**Situação em 22/10/2026:** nome ainda não definido. Domínios conferidos no RDAP do registro.br;
INPI **não** consultado (o Allan não conseguiu acesso; pedir a contador ou despachante).

**Descartados**
- **GestãoFácil** (nome de trabalho): `gestaofacil.com.br` está ativo com outro titular desde
  17/05/2000 (confirmar se não é do Allan). Nome descritivo — proteção fraca no INPI — e não comunica o
  diferencial. `gestaof.com.br` está livre, mas abreviação gera tráfego para o domínio do outro.
- **Orbis:** nome comum (ORBIS SE, Orbis Software); `orbis.com.br` ocupado.
- **Orby:** bom como marca inventada, mas disputado: `orby.com.br` (2004), `meuorby` (2022), e em 2026
  `useorby`, `orby.net.br`, `orby.app.br`, **`orbygestao.com.br` (14/09/2026)** e `orbyapp.com.br`
  (21/10/2026 — confirmar se é do Allan). Existem Orby.co (neurotech BR) e Orby AI (automação, EUA).
  Abstrato: não comunica margem.

**Finalistas** (`.com.br` livre em 22/10/2026; sem produto homônimo encontrado na web)

| Nome | Leitura | Força de marca |
|---|---|---|
| **Lucrário** (empata com Lucral, da 2ª rodada) | "diário do lucro" | Alta (inventada) |
| NotaLucro | a nota vira lucro | Média (composição de palavras comuns) |
| Margino | de "margem" | Alta, mas significado pouco claro ao lojista |

Frase de apoio sugerida: **"Lucrário — o lucro de cada item, direto da nota do fornecedor."**

Passos:
1. Registrar `lucrario.com.br` como reserva (barato, antes que alguém pegue).
2. Consulta no INPI (classes 9, 35 e 42) por contador ou despachante.
3. Testar com 5 lojistas: "o que esse nome te lembra?". Passa se a maioria associar a lucro/dinheiro.
4. Conferir @ no Instagram e TikTok.

Também livres: `lucrofino`, `lucrodobalcao`, `balcaolucro` (descritivos, menos protegíveis).

**Segunda rodada — curtos e abstratos** (`.com.br` livre em 22/10/2026; produto homônimo na web
**não** pesquisado):

| Curtos (com raiz) | Abstratos |
|---|---|
| **Lucral** (recomendado), Lucrel, Margal, Custal, Notira, Notavo, Notalu, Gondi, Balku, Caixu | **Vorna** (recomendado), Sovri, Dalvo, Nalvo, Farvo, Juvra, Quarvo, Quena, Quiru, Olvar |

Critério extra: o nome tem de ser escrito certo por quem só o ouviu (WhatsApp em áudio, telefone).
Balku, Caixu, Quena e Quiru falham nisso. Descartados mesmo livres por soarem mal: Calvio, Sombi,
Duvra, Pirto. Com o orçamento de R$ 1.000/mês, nome com raiz (Lucral, Lucrário) custa menos para
ganhar significado do que nome abstrato.

## 6. Preço, trial e gratuidade

**Decisão: sem plano gratuito permanente.** Suporte individual por WhatsApp não escala para quem não
paga, e cada empresa custa certificado, notas e atenção.

**Métrica de valor:** preço **por loja (CNPJ), usuários ilimitados**; planos se diferenciam por
funcionalidade e número de caixas. **Notas ilimitadas** em todos. Números e detalhes em
[`PLAN-NEGOCIO.md`](./PLAN-NEGOCIO.md) §3.

| Plano | Preço (hipótese) | Inclui |
|---|---|---|
| Balcão | R$ 69/mês | 1 caixa, PDV, cupom fiscal, NF-e, estoque, entrada de nota automática, etiqueta |
| **Loja** (âncora) | R$ 129/mês | + margem real e alerta de custo, troca, grade, condicional, 2 caixas |
| Loja+ | R$ 219/mês | Caixas ilimitados, reposição, comparação de fornecedores, crediário, suporte prioritário |

- **Plano "Só Nota":** emissor de NF-e/NFC-e sem PDV, estoque e grade, por ~R$ 49/mês. É o mesmo
  sistema com funcionalidades desligadas (F5), **não** um produto ou marca separada, e não é a oferta
  anunciada. Serve para: cliente indicado por contador que só quer nota (atacado, pequena confecção
  que vende para lojas), e degrau de saída para quem ia cancelar. Motivo do cuidado: o suporte de
  certificado e rejeição custa o mesmo para quem paga R$ 49 e R$ 129. Entrar como emissor avulso,
  competindo com Emitte, Brasil NFe e Focus, é disputa por preço com produto igual. NFS-e não existe
  hoje no sistema, então prestador de serviço fica fora.
- **Mensal sem fidelidade.** **Anual à vista** (Pix/boleto) com 2 meses grátis; sem parcelar no
  cartão.
- **Preço de fundador:** os 20 primeiros pagam o plano Loja por **R$ 79/mês fixos por 12 meses**,
  com implantação feita pelo Allan. Cria urgência sem rebaixar a tabela.
- **Trial:** 30 dias do plano Loja, sem cartão. Nos primeiros ~20 clientes, implantação concierge
  (XMLs de 90 dias carregados pelo Allan) faz parte do trial; no lançamento aberto vira opcional pago
  (PLAN-NEGOCIO §9.1).
- **Piloto:** gratuito por 60 dias em troca de depoimento em vídeo, métricas e feedback semanal.
- **Cobrança:** até ~20 clientes, Pix manual mensal com lembrete; integrar gateway de assinatura
  depois. Os limites dos planos precisam passar a ser lidos pelo sistema antes da tabela entrar no ar.
- **CNPJ:** obrigatório antes da primeira cobrança. Pedir ao contador parceiro o enquadramento para
  venda de software (nem toda atividade cabe em MEI).

Margem: servidor custa R$ 4–16 por cliente entre 20 e 100 clientes (PLAN-INFRA, consolidado em
PLAN-NEGOCIO §5.2); margem bruta estimada em ~82%. Falta só custos do CNPJ e pró-labore para o
ponto de equilíbrio.

## 7. Funcionalidades

### 7.1 Antes do beta (nov/2026–jan/2027)

Detalhadas em [`PLAN-PRE-BETA.md`](./PLAN-PRE-BETA.md). Ordem: F5 → F4 → F2 → F17 → F18 → F3 → F1.
Se faltar tempo, F3 cede antes de F17; F1 só entra se o beta for de moda.

| # | Funcionalidade | Por quê | Obrigatória? |
|---|---|---|---|
| F5 | **Cobrança e limites dos planos** | Sem isso não há como cobrar nem diferenciar planos | Sim |
| F4 | **Cupom pelo WhatsApp** (link `wa.me` com o cupom/DANFE, sem impressão) | Loja começa sem impressora fiscal; reduz custo de entrada | Sim |
| F2 | **Etiqueta com código de barras** (A4 e térmica; código interno para item sem EAN) | 42% dos itens da nota real vêm sem GTIN; sem etiqueta o PDV não lê | Sim |
| F17 | **Margem real** (§7.4) | É o argumento de venda do plano Loja | Sim |
| F18 | **Alerta de custo** (§7.4) | Idem | Sim |
| F3 | **Troca e vale-troca** (nota de devolução, crédito da loja, cupom de troca sem preço) | Toda loja troca; moda troca muito | Sim se moda; senão cede primeiro |
| F1 | **Grade cor/tamanho** (cada variação é um produto ligado a um modelo) | Primeira pergunta de toda loja de moda | Só se o beta for de moda |

### 7.2 Para o lançamento (fev–mar/2027)

F6 (condicional) entra no plano Loja e por isso é prioridade se o segmento for moda.

| # | Funcionalidade | Por quê |
|---|---|---|
| F6 | **Condicional** (cliente leva peças para provar; volta, compra ou devolve; estoque reservado) | Hábito forte em loja de roupa brasileira e mal atendido pelos ERPs genéricos |
| F7 | **Crediário próprio / caderninho** com lembrete de parcela pelo WhatsApp (link `wa.me`; mensagem automática pela API paga só como franquia/add-on, PLAN-NEGOCIO §9.2) | Muito comum em loja de bairro; encaixa no PLAN-FINANCEIRO (contas a receber) |
| F8 | **Painel do contador** (acesso dele às empresas indicadas: notas, XML do mês, alertas) | Torna o contador promotor do produto |
| F9 | **Peças paradas** (produtos sem venda há X dias, por grade) com sugestão de promoção | Dor real de moda: dinheiro parado em estoque |
| F10 | **Clientes que sumiram e aniversariantes** (lista pronta para mensagem no WhatsApp) | O CPF já vem no cupom; vira marketing de graça para a loja |

### 7.3 Depois (2027)

| # | Funcionalidade | Observação |
|---|---|---|
| F11 | Cashback por CPF | Fidelidade simples, sem cartão |
| F12 | Vitrine por link (catálogo do estoque para vender por Instagram/WhatsApp) | Muitas lojas já vendem por DM |
| F13 | Pix com QR dinâmico e baixa automática | Exige PSP; ver PLAN-FINANCEIRO §2.2 |
| F14 | PDV offline com contingência NFC-e | Concorrentes anunciam; internet cai em loja pequena |
| F15 | Assistente no WhatsApp do lojista ("quanto vendi hoje?", "o que está acabando?") | Diferencial de comunicação forte; só depois que a base estiver estável |
| F16 | Migração assistida (planilha ou exportação de outro sistema) | Reduz atrito de quem já usa Bling/Tiny |

### 7.4 Diferenciação: margem e compras (20/10/2026)

Origem e justificativa em [`PLAN-DIFERENCIACAO.md`](./PLAN-DIFERENCIACAO.md) §4. Base: o custo real
por item já calculado na conferência da nota de entrada (`nota_entrada_itens.preco_custo_calc`).

| # | Funcionalidade | Base existente | Quando |
|---|---|---|---|
| F17 | **Margem real** por produto, por venda e "lucro de hoje" no dashboard (hoje mostra só faturamento). Decisão aberta: custo médio ponderado (recomendado para margem) ou último custo | `preco_custo_calc` | **Antes do beta** |
| F18 | **Alerta de custo:** fornecedor subiu o preço, margem caiu de X% para Y%, sugestão de novo preço com um clique e etiqueta nova (F2). Usa o último custo | Custo da entrada nova × anterior | **Antes do beta** |
| F19 | **Comparação de fornecedores** por item: mesmo EAN em fornecedores diferentes, preço ao longo do tempo | `produto_fornecedor_codigos` + itens das notas | Depois do beta |
| F20 | **Lista de reposição:** vendas dos últimos 30 dias, dias de cobertura do estoque, último fornecedor e preço; envio da lista pelo WhatsApp ao representante | Vendas + estoque + notas | Depois do beta |
| F21 | **Fiscal configurado pelo contador:** padrões de NCM/CST/CFOP definidos no painel dele; o lojista não mexe em imposto | Padrões de impostos da empresa | Com F8 |
| F22 | **Mês fechado para o contador:** XMLs de entrada e saída, resumo e pendências (rejeições, notas sem manifestação) entregues no dia 1 | ZIP de XML + DistDFe | Com F8 |
| F23 | **Resumo diário do dono:** vendeu, lucrou, o que acabou, custos que subiram. Primeiro por e-mail ou link `wa.me`; pela API paga do WhatsApp só com franquia (PLAN-NEGOCIO §9.2) | F17, F18 | Logo após o beta |

### 7.5 Autosserviço (20/10/2026)

Origem: revisão crítica em [`PLAN-NEGOCIO.md`](./PLAN-NEGOCIO.md) §9. Necessárias para o lançamento
aberto (fev–mar/2027), não para o beta.

| # | Funcionalidade | Base existente | Quando |
|---|---|---|---|
| F24 | **Assistente de primeira configuração + checklist de ativação** na tela: certificado → CSC e numeração → primeira nota de compra → primeira venda → primeira margem vista. Mostra o que falta e por quê, em português | Telas de Configuração Fiscal já existem, soltas | Antes do lançamento aberto |
| F25 | **Cadastro da empresa pelo próprio cliente** com trial automático (hoje só pela rota da plataforma, protegida por chave) | `PlataformaNovaEmpresa` e o fluxo de 3 camadas do cadastro pela plataforma | Antes do lançamento aberto |
| F26 | **Gatilhos de upgrade:** prévia oculta da margem no Balcão, oferta ao abrir caixa além do limite, segunda loja com desconto | F5 (limites) e F17 (margem) | Com F17 |

Serviço associado (não é funcionalidade): **implantação concierge** — o cliente (ou o contador)
envia os XMLs de compra dos últimos 90 dias pelo upload em lote e recebe o estoque cadastrado com
custo real e preço sugerido em até 48 h.

Cada funcionalidade vira um PLAN próprio antes de implementar.

## 8. Parceria com contadores

Modelo proposto:
- Contador usa de graça o painel (F8) e a exportação de XML.
- **20% de comissão recorrente** enquanto o cliente indicado pagar, ou 1 mês grátis para o cliente
  por indicação, à escolha do contador.
- Kit pronto: vídeo de 1 minuto, texto para WhatsApp, PDF de uma página.
- **Primeira conversa com cada um dos 5:** "quantos clientes de varejo você tem, de que ramo, e
  quantos compram com nota?". A resposta define o segmento do beta (PLAN-PRE-BETA §1).
- Começar com **2 dos 5** escritórios: os que mais atendem o segmento escolhido. Meta: 3 lojas
  indicadas por escritório no beta.
- O contador pode fazer a configuração fiscal do cliente (certificado, CSC) — ele costuma ter os
  dados; isso tira a maior fricção da implantação.
- Acordo simples por escrito (comissão, prazo, quem dá suporte ao cliente final).

## 9. Cronograma

Varejo não troca de sistema em novembro e dezembro (Black Friday e Natal). O lançamento amplo fica
para o início do ano.

| Fase | Quando | Entregas | Critério de saída |
|---|---|---|---|
| 0. Base | Até 15/11/2026 | Bloqueadores do PLAN-PRODUCAO; busca de nome/INPI; conversa com os 5 contadores (carteira por ramo); **segmento do beta decidido** | Piloto em produção com nota real |
| 1. Piloto | Nov–dez/2026 | Empresa piloto operando; registro de cada problema; F5, F4, F2, F17, F18 (e F3/F1 conforme segmento) em desenvolvimento; teste da tese de margem com o dono do piloto (PLAN-DIFERENCIACAO §7) | 30 dias sem incidente grave |
| 2. Beta fechado | Jan/2027 | 5 a 10 lojas indicadas, preço de fundador, implantação concierge; CNPJ aberto | 70% das lojas vendendo pelo sistema após 30 dias |
| 3. Lançamento | Fev–mar/2027 | F24 assistente, F25 cadastro próprio, F26 gatilhos de upgrade; site, vídeos, anúncios locais, depoimentos | 20 clientes pagantes |
| 4. Escala | Abr/2027+ | F6–F10, F19–F23; ajudante no suporte com ~30 clientes ou 10 h/semana de suporte | Churn de logos ≤ 3%/mês |

## 10. Canais com ~R$ 1.000/mês

| Canal | Valor | Ação |
|---|---|---|
| Contadores | R$ 0 | Canal principal |
| Instagram Reels / TikTok | R$ 0 | 2 vídeos/semana de 30s: "a nota do fornecedor virou estoque com margem em 1 minuto", "o sistema avisou que o fornecedor subiu 15%", "cupom em 10 segundos" |
| Google Ads local | ~R$ 600 | "sistema para [segmento escolhido]" + cidade; uma página por segmento. Primeiros R$ 200 testam as duas mensagens (PDV com nota × margem real, PLAN-DIFERENCIACAO §7) |
| Visita presencial | ~R$ 200 | Ruas e galerias do segmento escolhido, associação comercial / CDL |
| Reserva | ~R$ 200 | Brindes para depoimento, testes de anúncio no Instagram |

Antes do lançamento: página de lista de espera com WhatsApp, para medir interesse e montar a fila do
beta.

## 11. Métricas

Funil completo e metas em PLAN-NEGOCIO §2.3.

- **North Star:** lojas ativas que viram a margem real em uma nota de compra na semana.
- **Ativação ("momento aha"):** primeira nota de compra virou estoque com margem e primeira venda no
  PDV, em até 7 dias (meta 70% dos trials).
- **Retenção:** churn de logos ≤ 3%/mês (5% é alerta), por coorte.
- **Suporte:** horas por cliente por semana (define quando contratar ajuda).
- **Canal:** clientes por contador; custo por cliente no Google Ads.
- **Uso dos diferenciais:** % das notas de entrada que viraram estoque sem digitação; % de lojas que
  reajustaram preço a partir de um alerta de custo.

## 12. Riscos

| Risco | Mitigação |
|---|---|
| Suporte sozinho estoura | Limitar beta a 10 lojas; vídeos curtos para dúvidas repetidas; autosserviço (F24/F25) no lançamento aberto; contratar com ~30 clientes |
| Vender para moda sem grade | Só abordar moda depois de F1; primeiro segmento sem dependência de grade |
| Tese de margem não convencer | Testar com o piloto e 10 lojistas antes de F19–F23 (PLAN-DIFERENCIACAO §7) |
| Anunciar o que não existe | Plano Loja depende de funcionalidades a construir; só vender com F17/F18 prontas (PLAN-EXECUTIVO §2) |
| Cobrar sem CNPJ | Abrir antes da primeira cobrança |
| Contador não indica | Painel, comissão e configuração fiscal feita por ele; começar com quem atende o segmento escolhido |
| Concorrente baixa preço | Competir por margem real, estoque sem digitação e atendimento, não por preço |

## 13. Fontes

- Bling: https://www.bling.com.br/planos-e-precos e comunicado de abril/2026 em ajuda.bling.com.br
- Olist/Tiny: https://olist.com/planos/
- Vhsys: https://www.vhsys.com.br/planos-e-precos/
- Mais PDV: https://maispdv.com/pdv-loja-roupas
- Conta Azul parceiros: https://contaazul.com/contadores/parceria/
- Faixa de preço para loja de roupa: https://negociocerto.org/blog/implementar-sistema-pdv-custo/
- MEI: PLP 186/2026 (Senado) trata do limite do MEI, não da emissão para PF.
