# PLAN-DIRECAO.md — Direção do negócio (empresa nova, financeiro no centro)

**Status:** PROPOSTA PARA O ALLAN CONFIRMAR. Escrito em 2026-10-22 a partir das respostas dele.
Este documento **tem prioridade sobre** PLAN-LANCAMENTO, PLAN-NEGOCIO, PLAN-PRE-BETA,
PLAN-DIFERENCIACAO, PLAN-EXECUTIVO e PLAN-MARCA onde houver conflito; esses seis ainda partem de
"loja que troca de sistema" e serão reescritos depois que as decisões do §9 forem fechadas.

**Documentos relacionados:** [`PLAN-FINANCEIRO.md`](./PLAN-FINANCEIRO.md) (desenho do módulo, nada
implementado) · [`PLAN-PRODUCAO.md`](./PLAN-PRODUCAO.md) · [`PLAN-NEGOCIO.md`](./PLAN-NEGOCIO.md)

---

## 1. O que o Allan quer (organizado)

| Eixo | Decisão |
|---|---|
| Meta de curto prazo | **10 clientes pagantes** |
| Tempo disponível | ~2 h por dia (10 a 14 h por semana), sozinho |
| Natureza do negócio | Entregar valor com um sistema de gestão; **não é empresa de software** |
| Cliente | **Empresa nova**, de **comércio e de serviço** (não quem quer trocar de sistema) |
| Dono típico | Conhece o negócio, **não conhece gestão** |
| Entrada | O básico: nota fiscal, estoque, vendas (e **NFS-e Nacional** para serviço) |
| Núcleo de valor | **Financeiro**, e um sistema **inteligente**: o que pode ser alimentado sozinho, é |
| Princípio | "Para ganhar dinheiro, faça o outro ganhar" |
| Canal | Contadores parceiros; **o contador decide** o sistema do cliente novo, o Allan ajuda |
| Linhas em avaliação | Consultoria financeira, canal no YouTube, ferramentas de IA para escritório: **só depois dos primeiros 10** |

**Tese em uma frase:** *a empresa compra pela nota fiscal e fica pelo dinheiro organizado.*

## 2. O que a conferência dos dados mostrou

| Crença | Veredito | Consequência |
|---|---|---|
| "Toda empresa precisa de sistema para emitir nota" | **Em parte.** NF-e tem [emissor gratuito do Sebrae](https://sebrae.com.br/subsites/emissor-nf-e) (a [SEFAZ-PE não tem emissor próprio](https://www.sefaz.pe.gov.br/Servicos/Paginas/TeleSefaz.aspx)); NFS-e tem o **Emissor Nacional**, gratuito, no portal. Não achei emissor gratuito de NFC-e em PE | A obrigação abre a porta, mas o argumento de venda não é "você precisa de nós para emitir". É **"já que vai emitir, tenha o resto organizado"** |
| "Empresa nova é melhor alvo" | **Sim para onboarding, atenção para retenção.** Sem migração e sem sistema a vencer. Mas a mortalidade de empresa nova é alta (45% em 2 anos, em levantamentos que citam o Sebrae, número a conferir) | Esperar mais cancelamento por fechamento da empresa; meta de 3%/mês é otimista até medir |
| "Há muita empresa nova" | **Sim.** Sebrae: 4,39 milhões de pequenos negócios abertos de jan a set/2026, 77% MEI e ~23% ME/EPP ([fonte](https://simplifique.contmatic.com.br/blogs/abertura-de-pequenos-negocios-2026)) | Sem MEI, o alvo são ~1 milhão em 9 meses no Brasil, comércio e serviço juntos. Recorte por setor e por UF não encontrado |
| "Entregar mais vende" | **Entregar mais é barato; vender mais, não.** O custo real de uma funcionalidade é suporte, manutenção e risco | Construir pouco e bem; revelar funções por etapa de uso; **vender uma promessa só** |
| "Serviço está em alta" | **Plausível**, e há janela regulatória (§5) | NFS-e entra, mas não antes de o financeiro existir |
| "10 clientes" | Coerente com 10–14 h/semana (§3) | Meta de renda extra, não de largar o emprego |

## 3. Conta de capacidade

- **10 clientes × R$ 100–130/mês ≈ R$ 1.000 a 1.300 de receita bruta** (hipótese de preço do
  PLAN-NEGOCIO; infra ~R$ 80/mês, PLAN-INFRA). É renda extra, não salário.
- **Para largar o emprego:** depende da retirada. Com R$ 5.000/mês seriam cerca de 60 clientes
  (PLAN-NEGOCIO §5.1). Etapas: 10 → 30 (contratar ajuda) → 60.
- **Tempo:** implantação ~4 h por cliente (hipótese, PLAN-ENTREGA §5) e suporte ~15 min por cliente
  por semana. Para 10 clientes: ~40 h de implantação no total e ~2,5 h/semana de suporte. **O gargalo
  não é atender 10 clientes; é desenvolver.** Sobram só ~7 a 10 h/semana de construção, já com o
  portão de etapa (revisar → testar → commitar → PROGRESS).
- **Regra:** o que não ajuda a conseguir os 10 primeiros clientes não entra agora.

## 4. Produto: "o sistema que se alimenta sozinho"

Princípio do PLAN-FINANCEIRO §1, agora central: **o usuário só digita o que o sistema não consegue
saber.**

| Já alimentado sozinho (hoje ou planejado) | Como |
|---|---|
| Estoque e custo | Nota de compra chega pela SEFAZ (DistDFe, em produção) e vira estoque com custo real |
| Contas a pagar | **A construir:** ler as duplicatas do XML da compra (vencimento e valor) e criar os títulos. Hoje o leitor **não lê** `<cobr><dup>` (PLAN-FINANCEIRO Fase 4) |
| Entrada no caixa | **A construir:** venda do PDV em dinheiro/PIX/débito vira movimentação sozinha (Fase 3) |
| Contas a receber | **A construir:** nota emitida de serviço / venda a prazo vira título (Fase 5) |
| Serviço recorrente | **A construir:** nota + cobrança mensal automáticas (Fase 7) |
| Avisos | Certificado (existe); o resto a construir: "você tem R$ X a pagar sexta e o saldo cobre?" |

**O que sobra para o dono digitar:** despesas sem nota (aluguel, energia, salário) e exceções. Para
quem não conhece gestão, isso se mostra como tela guiada, não como contabilidade.

**Inteligência em duas camadas:** regras determinísticas (alertas, vencimentos, margem negativa) e
IA só onde ela ajuda de verdade (classificar despesa, explicar em português simples). Nada que o
dono não consiga conferir.

**Corte do PLAN-FINANCEIRO para a primeira entrega** (recomendação dele já era Fases 1–4 e 6;
mantenho): fundação (1), títulos e baixas (2), caixa com PDV (3), compras → contas a pagar (4) e
fluxo de caixa (6). Vendas a prazo (5), recorrência (7), régua de cobrança (8) e DRE (9) depois.
Ainda é grande para 7–10 h/semana: **estimar cada fase só depois de fechar as decisões D1–D18**.

## 5. Serviço: NFS-e Nacional

O que as fontes (blogs do setor, não texto oficial) dizem:
- LC 214/2025: municípios devem aderir ao padrão nacional desde 01/01/2026
  ([Focus NFe](https://focusnfe.com.br/blog/nfse-nacional/)).
- ME e EPP do Simples: obrigatoriedade do Emissor Nacional adiada para **01/11/2026**, pela
  Resolução CGSN 191/2026, segundo as fontes mais recentes
  ([Contmatic](https://simplifique.contmatic.com.br/blogs/nfse-padrao-nacional-2026)); confirmar no texto.
- Recife: Portaria SEFIN 42/2025 manda emitir pelo Emissor Nacional, em fases, de 11/2025 a 01/2026
  ([notícia](https://notagateway.com.br/?p=6655)); situação atual não confirmada.
- Há API de integração com o Emissor Nacional.

**Oportunidade:** milhares de prestadores novos vão precisar usar o padrão nacional ao mesmo tempo.
**Cuidado, o mesmo do NF-e:** o Emissor Nacional é **gratuito**. O valor não está na emissão, está no
que fica ao redor: cadastro de clientes, nota recorrente, cobrança, recebimentos e fluxo de caixa.

**Riscos e custo de construir**
- Bibliotecas PHP existem, mas são comunitárias e pouco adotadas; a oficial da NFePHP está
  abandonada ([Packagist](https://packagist.org/packages/nfephp-org/sped-nfse-nacional)). O `nfe-api`
  já usa `sped-common` (certificado e assinatura), então a base existe. É um módulo novo no nfe-api,
  com sua própria homologação.
- **Cobertura:** só funciona onde o município está ativo no padrão nacional. Um balanço da Receita
  (sem data) citava 330 emitindo, 342 configurados e mais de 3 mil sem convênio. **Começar pelo
  município do Allan e dos contadores parceiros**, conferido no portal antes de vender.
- Regra do Simples e das alíquotas do ISS por município e por serviço: depende do contador do cliente.

**Recomendação:** o financeiro vem antes da NFS-e, porque serve a comércio e a serviço. A NFS-e é a
segunda fase.

## 6. Posicionamento

- **Gancho:** *"Quanto sobra no fim do mês. Sem você digitar nada."* (alternativa: *"Sua empresa
  organizada sozinha"*). Ainda é hipótese: testar com 10 donos de empresa nova antes de fixar.
- **Cadeia de valor:** nota → custo → margem → contas a pagar → caixa → o que fazer. A margem por
  item (F17/F18) é o recorte de comércio dessa cadeia, não mais o gancho geral.
- **Por quê para o dono sem gestão:** o sistema diz o que fazer ("o item X dá prejuízo", "sexta você
  paga R$ 2.300 e o saldo não cobre"). Aqui a promessa "ganhar dinheiro com o cliente" fica
  concreta.
- **Para o contador:** menos retrabalho, mês fechado no dia 1, cliente organizado desde o primeiro
  dia. Ele não precisa trocar nada do que usa; recebe XML e relatórios.

## 7. Contadores

- **Canal, não cliente.** O contador escolhe o sistema do cliente novo, então o produto precisa fazê-lo
  parecer bom: abertura de empresa → cliente já entra com configuração fiscal feita por ele.
- **Entrar pelo menor atrito:** o escritório não troca nenhum software; só recebe XMLs e
  relatórios organizados.
- **Ferramentas de IA para o escritório:** investigar com os 3 ou 4 contadores onde o retrabalho
  mora (pergunta 8, em aberto). Só vale construir se for algo que o produto já gera como subproduto.

## 8. O que muda nos outros planos

| Plano | O que deixa de valer |
|---|---|
| PLAN-LANCAMENTO | Segmento "armarinho/moda que troca de sistema"; implantação com XMLs de 90 dias; calendário que evita nov/dez; promessa centrada em margem por item |
| PLAN-PRE-BETA | F1 grade, F3 troca, F6 condicional, F7 crediário próprio, F9, F10 saem do caminho. F5 cobrança continua primeiro. F2 etiqueta e F4 cupom por WhatsApp só se o cliente novo pedir |
| PLAN-NEGOCIO | Premissa de ARPU R$ 110 e churn 3%: reabrir; planos precisam incluir financeiro (e um plano de serviço) |
| PLAN-DIFERENCIACAO | Tese vira "sistema que se alimenta sozinho e diz o que fazer"; margem real vira a versão de comércio |
| PLAN-MARCA | Propósito continua; missão A ("saber quanto ganha em cada item") passa a "saber quanto sobra" |
| PLAN-FINANCEIRO | Ganha prioridade máxima; falta fechar D1–D18 |

## 9. Decisões para o Allan

| # | Decisão | Recomendo |
|---|---|---|
| R1 | Começar por comércio ou por serviço | **Comércio primeiro:** PDV, nota e estoque já existem; serviço depende da NFS-e (módulo novo) |
| R2 | Ordem de construção | 1) F5 cobrança; 2) financeiro núcleo (Fases 1, 2, 4 do PLAN-FINANCEIRO); 3) caixa + fluxo (3, 6); 4) NFS-e Nacional; 5) vendas a prazo e recorrência |
| R3 | Adiar grade, troca, condicional, crediário, peças paradas, clientes que sumiram | Sim |
| R4 | Consultoria, YouTube e ferramenta de IA para escritório | Decidir só com 10 clientes pagando; YouTube/vídeos curtos podem começar como conteúdo de apoio, 1 vídeo por semana, sem canal "oficial" |
| R5 | Prazo da meta de 10 clientes | Definir. Com construção de 7–10 h/semana, o financeiro mínimo chega depois do piloto; a meta de 10 pode ser alcançada vendendo antes só o básico (nota + estoque + vendas) com o financeiro como "em breve", se isso for honesto com o cliente |
| R6 | Dois pontos da conversa ainda sem resposta | Primeira dor financeira do dono novo: **hipótese "quanto sobra no mês"**; exemplos de retrabalho do escritório: **em aberto** |

## 10. Próximos passos

1. O Allan responde R1 a R6 (aceita as recomendações ou muda).
2. Reescrever os seis planos listados no §8 com a nova direção.
3. Fechar D1–D18 do PLAN-FINANCEIRO e cortar a primeira entrega em fases com estimativa de horas.
4. Conferir NFS-e: texto da Resolução CGSN, situação do município e do Recife no portal nacional.
5. Conversar com os contadores: quantas empresas novas abrem por mês, de qual setor, e o que elas
   usam hoje para emitir nota.
