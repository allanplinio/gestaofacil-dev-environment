# PLAN-NEGOCIO.md — Estratégia comercial, precificação e números

**Status:** PLANO. Escrito em 2026-10-20 seguindo o template de plano de negócios SaaS (GTM,
precificação, unit economics, retenção, custos). **Todos os números são hipóteses** até haver
clientes pagando; os que vêm de benchmark estão marcados com a fonte. Custos fixos reais do Allan
ainda não foram informados (§5.1).

**Documentos relacionados:** [`PLAN-LANCAMENTO.md`](./PLAN-LANCAMENTO.md) ·
[`PLAN-DIFERENCIACAO.md`](./PLAN-DIFERENCIACAO.md) · [`PLAN-PRE-BETA.md`](./PLAN-PRE-BETA.md)

---

## 1. Auditoria das frustrações com concorrentes

Feita no Reclame Aqui em 20/10/2026. São queixas de usuários; as respostas das empresas são versão
delas. Amostra pequena: serve para achar padrões, não para medir.

| Dor recorrente | Evidência | Nosso compromisso |
|---|---|---|
| **Suporte lento / inalcançável** | Bling: 544 reclamações em 6 meses, resposta média ~10 dias, queixas de telefone lotado. Tiny/Olist: "chamados que demoram", "atendimento engessado" | **Atendimento humano no WhatsApp, resposta em até 1 hora útil.** Só prometer o que uma pessoa sustenta; rever ao contratar ajuda |
| **Reajuste de surpresa** | Vhsys: reajuste de 41% na renovação. Bling: queixa de mensalidade dobrada (empresa nega) | **Preço travado por 12 meses; qualquer reajuste avisado com 60 dias e nunca acima do IPCA para quem já é cliente** |
| **PDV pensado para e-commerce, ruim no balcão** | Tiny: PDV exigia extensão e cadastro completo do consumidor na NFC-e; "não atende loja física". Bling: PDV travando na frente de caixa | **Feito para o balcão:** roda no navegador sem instalar nada; NFC-e sem cadastro do consumidor quando não precisa |
| **Nota que não sai e ninguém resolve** | Bling: rejeições (ex.: 213, CNPJ × certificado) sem solução pelo suporte | **Erro fiscal explicado em português e resolvido junto** pelo WhatsApp; checagem de certificado na implantação |

Esses quatro compromissos entram na página de venda, lado a lado com a tese de margem
(PLAN-DIFERENCIACAO). Fontes no §9.

## 2. Go-to-market

### 2.1 Rota ao mercado: híbrida, liderada por parceiro

> Revisado no §9.1: a demonstração e a implantação humanas valem para os primeiros ~20 clientes; no
> lançamento aberto o caminho padrão é cadastro e trial pelo próprio cliente.

| Modelo da literatura | Encaixe aqui |
|---|---|
| PLG puro (autosserviço) | **Não agora.** Fiscal exige certificado, CSC e numeração; o lojista não configura sozinho. Vira meta depois que a implantação estiver automatizada |
| Inside sales | **Sim, leve:** demonstração por vídeo/WhatsApp de 20 minutos feita pelo Allan |
| Canal de parceiros | **Principal:** contadores indicam, sistema dá painel e comissão |
| Enterprise / MEDDIC | **Não se aplica.** Ticket de R$ 70–220, decisão de uma pessoa (o dono) |

Fluxo: contador indica → Allan faz demonstração de 20 min com as notas reais do lojista → trial de
30 dias com implantação concierge → assinatura.

### 2.2 Papéis (Predictable Revenue, adaptado a uma pessoa)

| Papel clássico | Hoje | Primeira contratação |
|---|---|---|
| SDR (prospecção) | Contadores fazem; Allan visita lojas | Não contratar |
| AE (fechamento) | Allan | Não contratar |
| CS / suporte (implantação, retenção) | Allan | **Primeira vaga**, com ~30 clientes ou quando suporte passar de 10 h/semana |

Em SMB de ticket baixo quem segura a receita é o pós-venda, não o vendedor.

### 2.3 Funil AARRR

| Etapa | Definição aqui | Meta inicial (hipótese) |
|---|---|---|
| Aquisição | Lead com loja real (indicação, anúncio, visita) | 15 leads/mês no beta |
| Ativação | **Primeira nota de compra virou estoque com margem e primeira venda no PDV** ("momento aha") | 70% dos trials em até 7 dias |
| Retenção | Loja que vendeu pelo sistema em 3 das 4 semanas do mês | Churn de logos ≤ 3%/mês |
| Indicação | Cliente ou contador que indicou alguém | 1 em cada 5 clientes |
| Receita | Trial que virou assinatura | 50% |

**North Star Metric:** *lojas ativas que viram a margem real em uma nota de compra na semana.* Junta
uso do PDV, entrada de nota e o diferencial.

**Time-to-Value alvo:** até 48 h da assinatura do trial ao estoque carregado com custo (implantação
concierge, PLAN-DIFERENCIACAO §5).

## 3. Precificação

### 3.1 Métrica de valor: preço por loja, não por usuário

Revisão do PLAN-LANCAMENTO §6 e do PLAN-PRE-BETA §3 (decisão de 20/10/2026):
- **Cobrança por loja (CNPJ/estabelecimento), usuários ilimitados.** Cobrar por usuário leva a loja
  pequena a compartilhar senha, o que quebra a auditoria por perfil que o sistema já tem.
- **Planos se diferenciam por funcionalidade e por número de caixas**, não por usuário nem por volume
  de vendas.
- **Notas ilimitadas em todos os planos.** Concorrentes sobre API fiscal pagam por nota; nós não
  (conferir custo de servidor antes de anunciar).
- Sem cobrança por uso na v1. Candidato futuro a componente por uso: mensagens automáticas no
  WhatsApp (F23) se passarem a usar API paga.

### 3.2 Planos

| Plano | Mensal | Anual (≈17% off, 2 meses grátis) | Para quem | Inclui |
|---|---|---|---|---|
| Só Nota | R$ 49 | R$ 490/ano | Indicado por contador; não é anunciado | NF-e e NFC-e avulsas, XML para o contador |
| Balcão | R$ 69 | R$ 690/ano | Loja pequena, 1 caixa | + PDV, estoque, entrada de nota automática, etiqueta |
| **Loja** — "mais escolhido" | R$ 129 | R$ 1.290/ano | Âncora | + **margem real e alerta de custo**, troca, grade, condicional, até 2 caixas |
| Loja+ | R$ 219 | R$ 2.190/ano | Loja maior | + caixas ilimitados, reposição, comparação de fornecedores, crediário, suporte prioritário |

- **Âncora:** o plano Loja é o destacado; é onde está o diferencial (margem).
- **Entrada:** Balcão a R$ 69 fica na faixa dos emissores simples (Emitte R$ 59,90–119,90) entregando
  PDV e estoque.
- **Trial:** 30 dias do plano Loja, sem cartão. Freemium descartado (suporte é o custo dominante).
- **Fundador:** 20 primeiros no plano Loja por R$ 79/mês por 12 meses.

## 4. Unit economics (cenário base, hipotético)

### 4.1 Premissas

| Item | Valor | Origem |
|---|---|---|
| ARPU (receita média por cliente/mês) | R$ 110 | Mix estimado: maioria Loja, alguns Balcão, fundadores a R$ 79 |
| Churn mensal de logos | 3% | Benchmark SMB: 3–7%/mês (§9). Usar o piso como meta, testar 5% como cenário ruim |
| Custo direto por cliente (servidor rateado + backup + envios) | R$ 20/mês | Infra do `PLAN-INFRA.md` dá R$ 4–16,40 por cliente entre 20 e 100 clientes (§5.2); arredondado para cima para cobrir e-mail/WhatsApp. Tempo de suporte fora (§6) |
| Comissão do contador | 20% da mensalidade, só nos clientes indicados | PLAN-LANCAMENTO §8 |
| Anúncios | R$ 600/mês trazendo 2–3 clientes | Hipótese a medir no lançamento |

### 4.2 Resultados

| Métrica | Cálculo | Base (3%) | Ruim (5%) |
|---|---|---|---|
| Margem bruta | (110 − 20) / 110 | 82% | 82% |
| Vida média do cliente | 1 / churn | 33 meses | 20 meses |
| **LTV** | ARPU × margem / churn | ≈ R$ 3.000 | ≈ R$ 1.800 |
| CAC por anúncio | R$ 600 / 2,5 clientes + tempo de demonstração | ≈ R$ 300 | ≈ R$ 300 |
| CAC via contador | Sem custo inicial; comissão recorrente reduz a margem desse cliente para ~64% | ≈ R$ 0 inicial | — |
| **LTV / CAC (anúncio)** | | ≈ 10× | ≈ 6× |
| **Payback do CAC** | 300 / (110 × 0,82) | ≈ 3,3 meses | ≈ 3,3 meses |

Referências da literatura: LTV/CAC ≥ 3×, payback < 12 meses, margem bruta 70–85%. **O cenário passa
com folga — mas só porque o tempo do Allan não entra como custo.** O gargalo real não é dinheiro, é
horas de suporte (§6).

### 4.3 MRR

Acompanhar mensalmente separado em: novo, expansão (upgrade de plano), contração (downgrade, ex.:
Loja → Só Nota), perdido (churn). **NRR > 100%** é meta para depois do primeiro ano, via upgrade para
Loja+ e lojas com mais caixas.

| Clientes ativos | MRR (ARPU R$ 110) |
|---|---|
| 20 | R$ 2.200 |
| 50 | R$ 5.500 |
| 100 | R$ 11.000 |
| 200 | R$ 22.000 |

## 5. Custos e margem

### 5.1 O que falta o Allan informar
- Domínio e e-mail (servidor e backup já estão no `PLAN-INFRA.md`, §5.2).
- Certificado e custos do próprio CNPJ (contador, impostos do Simples — enquadramento a confirmar).
- Ferramentas (WhatsApp Business, gateway de cobrança quando houver).
- Quanto precisa tirar por mês (pró-labore) para o negócio "se pagar".

Com isso: ponto de equilíbrio = (custos fixos + pró-labore) / (ARPU × margem bruta). Exemplo só para
ordem de grandeza: com R$ 1.000 de custos fixos e R$ 5.000 de pró-labore, ≈ 61 clientes.

### 5.2 COGS

Infraestrutura, do [`PLAN-INFRA.md`](./PLAN-INFRA.md) §3 e §5 (valores de lá; fases 2 e 3 são
estimativas não cotadas):

Clientes de cada fase seguem os gatilhos do PLAN-INFRA §6 (migra a 70% da capacidade):

| Fase | Clientes | Infra total/mês | Por cliente | Peso no ARPU de R$ 110 |
|---|---|---|---|---|
| 0 — piloto | 1 | ~R$ 50 | R$ 50 | 45% |
| 1 | 2 a 20 | ~R$ 80 | R$ 40 → R$ 4 | 36% → 4% |
| 2 | 21 a 41 | ~R$ 305 | R$ 14,50 → R$ 7,40 | 13% → 7% |
| 3 | 42 a 100 | ~R$ 690 | R$ 16,40 → R$ 6,90 | 15% → 6% |

Leitura: com 10 ou mais clientes a infra fica abaixo de ~15% da receita mesmo nos saltos de fase, e **"notas ilimitadas" se
sustenta** — o PLAN-INFRA já dimensiona pelo pior caso de 4.400 notas/mês por cliente. Nos saltos de
fase o custo por cliente sobe; absorver na margem, não no preço (mesma conclusão do PLAN-INFRA §5).

Demais custos diretos: envio de e-mail/WhatsApp e o **tempo de suporte**. Certificado
digital é do cliente. Sem API fiscal de terceiros (nfe-api é próprio; não é vendido —
decisão de 20/10/2026).

## 6. Capacidade (o verdadeiro limite)

| Suporte por cliente/semana | Clientes que 10 h/semana atendem |
|---|---|
| 30 min (implantação recente) | 20 |
| 15 min (estável) | 40 |
| 5 min (madura, com vídeos de ajuda) | 120 |

Ações para baixar o tempo por cliente: implantação concierge bem feita (menos dúvidas depois),
mensagens de erro em português, vídeos de 1 minuto para as 10 dúvidas mais repetidas, painel do
contador (dúvida fiscal vai para ele).

## 7. Retenção

- **Onboarding:** checklist de ativação (certificado ok → primeira nota de compra → primeira venda
  → primeira margem vista) com o Allan acompanhando os 7 primeiros dias.
- **Sinal de risco:** loja sem venda há 5 dias úteis → mensagem do Allan no mesmo dia.
- **Antes de cancelar:** oferecer downgrade (Só Nota) ou pausa de 1 mês.
- **Churn medido em logos e em receita**, por coorte de mês de entrada.

## 8. Decisões abertas

| # | Decisão | Recomendo |
|---|---|---|
| N1 | Prazo de resposta prometido no suporte | 1 hora útil |
| N2 | Teto de reajuste para clientes | IPCA, aviso de 60 dias, 12 meses travado |
| N3 | Caixas por plano | Balcão 1, Loja 2, Loja+ ilimitado |
| N4 | Usuários por plano | Ilimitados em todos |

## 9. Revisão crítica do modelo (6 pontos, 20/10/2026)

Revisão externa do modelo comercial; cada ponto conferido contra este plano e o código.

| # | Ponto | Procede? | O que muda |
|---|---|---|---|
| 1 | Onboarding manual corrói CAC e alonga o TTV | **Sim, para escalar.** Não para os 20 primeiros: implantação feita à mão é o que ensina o que automatizar (PLAN-DIFERENCIACAO §3.8). Hoje **não há cadastro pelo próprio cliente** — a empresa só nasce pela rota `/plataforma/empresas`, protegida por chave | Onboarding em duas etapas (§9.1). Novas F24 e F25 |
| 2 | Cobrança por usuário leva a senha compartilhada | **Sim — já corrigido** em §3.1 (por loja, usuários ilimitados) | Nada |
| 3 | Recurso com custo por uso em plano ilimitado destrói a margem | **Parcial.** Nota fiscal não tem custo por nota (nfe-api próprio; infra dimensionada no pior caso, §5.2) e a busca na SEFAZ é gratuita. O F4 usa link `wa.me`, sem custo. **O risco real é o F23** (resumo diário) se for pela API paga do WhatsApp, e um gateway de Pix no futuro | Regra de add-on/franquia (§9.2) |
| 4 | Anual parcelado no cartão vira inadimplência mascarada | **Sim.** | Anual só à vista (§9.3) |
| 5 | Sem trilha de expansão, NRR fica < 100% | **Sim** — §4.3 citava NRR sem mecanismo | Gatilhos de upgrade no produto (§9.4) |
| 6 | Demonstração humana não fecha com ticket de R$ 50–150 | **Parcial.** A demo de 20 min com o Allan custa pouco em dinheiro (CAC com tempo valorado ≈ R$ 470, payback ≈ 5 meses, ainda < 12). O problema é **capacidade**, não payback | Demo humana só na etapa 1 e depois só no Loja+ ou a pedido do contador (§9.1) |

### 9.1 Onboarding e canal em duas etapas

| | Etapa 1 — primeiros ~20 clientes | Etapa 2 — lançamento aberto |
|---|---|---|
| Entrada | Indicação do contador, demo com o Allan | Site → **cadastro pelo próprio cliente** (F25) → trial |
| Configuração fiscal | Allan junto com o lojista | **Assistente na tela** (F24); o **contador** pode fazer pelo painel (F21) — ele costuma ter o certificado e os dados fiscais |
| Carga do estoque | Concierge: XMLs de 90 dias carregados pelo Allan | Upload em lote pelo cliente/contador, com conferência guiada na tela |
| Atendimento humano | Proativo nos 7 primeiros dias | Por exceção: dúvida pontual, plano Loja+, ou concierge como **serviço pago** (taxa única de implantação — também cobre o custo do piloto, PLAN-INFRA §9) |

Cálculo do item 6: hora do Allan valorada em R$ 50 × (20 min de demo + ~3 h de implantação) ≈
R$ 170 por cliente, somados aos ~R$ 300 de anúncio ≈ R$ 470 de CAC; payback ≈ 470 / (110 × 0,82) ≈
5,2 meses. Passa no critério de < 12 meses, mas **3 h por cliente limita a ~3 clientes novos por
semana** junto com o suporte. É isso que obriga a etapa 2.

### 9.2 Recursos com custo variável

- **Inclusos sem limite:** NF-e, NFC-e, busca de notas na SEFAZ, links `wa.me`, e-mail transacional
  normal.
- **Franquia + excedente ou add-on:** mensagens automáticas pela API oficial do WhatsApp (F23,
  lembretes de crediário do F7), Pix com baixa automática (F13, repassar a tarifa do PSP).
  Definir a franquia **depois** de cotar o custo por mensagem; antes disso, F23 pode sair por e-mail
  ou por link `wa.me`, sem custo.
- Regra geral: nenhum recurso com custo por uso entra como "ilimitado" sem a conta mostrar que a margem
  bruta continua ≥ 70% no cliente que mais usa.

### 9.3 Anual e cancelamento

- **Anual somente à vista** (Pix ou boleto), com os 2 meses grátis. Sem parcelamento no cartão.
- **Mensal sem fidelidade** — é um compromisso de venda contra a dor dos concorrentes (§1).
- Cancelamento do anual: acesso mantido até o fim do período pago; política de reembolso (ex.:
  integral até 30 dias, depois nenhum) **a validar com o contador/advogado** antes de publicar.

### 9.4 Expansão (NRR)

Gatilhos dentro do produto, sem vendedor:
- **Prévia da margem no Balcão:** o plano Balcão mostra que existe margem calculada para as notas
  importadas, mas com o valor oculto — "veja quanto você ganha em cada item: teste o Loja por 7 dias".
  O diferencial vira o motor de upgrade.
- **Segundo caixa:** abrir o 2º caixa no Balcão ou o 3º no Loja oferece o upgrade.
- **Nova loja (outro CNPJ):** cobrança por loja faz cada filial nova ser receita nova; oferecer a
  segunda loja com desconto.
- **Add-ons:** implantação concierge, mensagens automáticas (§9.2).
- **Descida em vez de cancelamento:** Loja → Balcão → Só Nota mantém receita (contração, não perda).

## 10. Fontes

Reclamações (Reclame Aqui, consultado em 20/10/2026):
- [Bling — página da empresa](https://www.reclameaqui.com.br/empresa/bling/) ·
  [aumento de mensalidade e suporte](https://www.reclameaqui.com.br/bling/aumento-abusivo-da-mensalidade-do-bling-e-falta-de-suporte-adequado_sSmd9jr2Ogsq9O92/) ·
  [PDV instável](https://www.reclameaqui.com.br/bling/sistema-extremamente-instavel-impossivel-usar-o-pdv-para-frente-de-caixa-ou_oMsX6Cdm0qnHGFit/) ·
  [não emite NF](https://www.reclameaqui.com.br/bling/bling-nao-deixa-eu-emitir-nf_aKdc23SudFSGwS8o/)
- [Olist — loja física, PDV e NFC-e](https://www.reclameaqui.com.br/olist-oficial/sistema-nao-atende-necessidade-do-cliente-loja-fisica-que-precisa-de-pdv-e_ogF73huzLzcV5dky/) ·
  [pior sistema para pequenos negócios](https://www.reclameaqui.com.br/olist-oficial/pior-sistema-para-pequenos-negocios_0xaDcBbi9R2C0vNN/)
- [Vhsys — lista de reclamações](https://www.reclameaqui.com.br/empresa/vhsys-informacoes/lista-reclamacoes/?status=ALL) ·
  [PDV lento](https://www.reclameaqui.com.br/vhsys-informacoes/pdv-lento_yqn-TlczqLcTTvYM/)

Benchmark de churn SMB (blogs/fornecedores, sem dado brasileiro de varejo):
- [Kalungi — SaaS churn benchmarks](https://kalungi.com/blog/saas-churn-rate-benchmarks) ·
  [Voxbooster — SaaS churn 2026](https://www.voxbooster.com/pt-BR/blog/saas-churn-statistics-2026/)

Literatura do template: Aaron Ross (*Predictable Revenue*), Jason Lemkin (SaaStr), David Skok
(*For Entrepreneurs* — unit economics), Mark Roberge (*The Sales Acceleration Formula*), Dave
McClure (AARRR).
