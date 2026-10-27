# PLAN-EXECUTIVO.md — Plano comercial e precificação (resumo executivo)

> **EM REVISÃO (22/10/2026):** este resumo parte de "loja que troca de sistema". A direção atual
> (empresa nova, comércio e serviço, financeiro no centro) está em
> [`PLAN-DIRECAO.md`](./PLAN-DIRECAO.md), que prevalece.

**Status:** resumo de 2026-10-20 dos planos [`PLAN-LANCAMENTO`](./PLAN-LANCAMENTO.md),
[`PLAN-DIFERENCIACAO`](./PLAN-DIFERENCIACAO.md), [`PLAN-NEGOCIO`](./PLAN-NEGOCIO.md) e
[`PLAN-PRE-BETA`](./PLAN-PRE-BETA.md). Em caso de conflito, valem eles. Preços e metas são hipóteses
até haver clientes pagando. A coluna **Situação** diz o que existe hoje no código e o que ainda será
construído — **não anunciar como pronto o que está "a construir"**.

---

## 1. Posicionamento e proposta de valor

- **Nicho:** varejo físico de pequeno e médio porte **que compra com nota fiscal**. O primeiro
  segmento sai da carteira dos contadores parceiros; sem esse dado, armarinho / aviamentos /
  papelaria. **Moda, calçados e acessórios são a segunda onda**, quando a grade estiver pronta
  (PLAN-PRE-BETA §1).
- **Tese:** eliminar a maior barreira de troca de sistema — cadastrar o estoque — com a nota de
  compra virando estoque e custo real sozinha (DistDFe + XML), e usar esse custo para mostrar a
  **margem real por item**.
- **Promessa central:** *"Saiba quanto você ganha em cada item. A mercadoria chega, o estoque se
  cadastra sozinho com o custo certo. Vendeu, a nota sai. Seu contador recebe tudo pronto."*
- **Compromissos contra as dores dos concorrentes:** resposta humana no WhatsApp em até 1 hora útil;
  preço travado por 12 meses e reajuste nunca acima do IPCA, com aviso de 60 dias; PDV no navegador
  sem instalar nada; erro fiscal explicado em português.

## 2. Precificação e pacotes

- **Métrica de valor:** por loja (CNPJ), **usuários ilimitados**. Upgrade puxado por número de caixas
  e funcionalidades avançadas.
- **Notas fiscais ilimitadas em todos os planos** (nfe-api próprio; infra dimensionada no pior caso).
- **Cobrança:** mensal sem fidelidade, ou anual **à vista** (Pix/boleto) com 2 meses grátis. Sem
  parcelamento do anual no cartão.
- **Sem plano gratuito permanente** (descartado pelo custo de suporte fiscal). Trial de 30 dias do
  plano Loja, sem cartão.

| Plano | Mensal | Para quem | Inclui | Situação |
|---|---|---|---|---|
| Balcão | R$ 69 | Loja pequena, balcão único | 1 caixa PDV com NFC-e, NF-e, estoque, entrada de nota automática (DistDFe/XML), etiqueta | PDV, NF-e, NFC-e, estoque e entrada de nota **prontos**; etiqueta **a construir** (F2) |
| **Loja** — âncora | R$ 129 | Quem quer gestão de verdade | + margem real e alerta de custo, troca/vale-troca, grade cor/tamanho, condicional, 2 caixas | **Tudo a construir** (F17, F18, F3, F1, F6) |
| Loja+ | R$ 219 | Loja maior, vários caixas | + caixas ilimitados, crediário, reposição, comparação de fornecedores, suporte prioritário | **A construir** (F7, F20, F19) |
| Só Nota | R$ 49 | Indicado por contador; **não anunciado** | NF-e e NFC-e avulsas, XML para o contador | Pronto (falta só o limite por plano, F5) |

**Implicação:** no beta, o plano Loja só pode ser vendido com F17 e F18 prontos (margem é o
argumento). Grade, troca e condicional entram conforme o segmento do beta.

## 3. Go-to-market e canais

- **Rota:** liderada por parceiro (contadores) em duas etapas:
  1. **Primeiros ~20 clientes:** indicação → demonstração de 20 min com as notas reais do lojista →
     implantação concierge pelo Allan (XMLs de 90 dias carregados em até 48 h).
  2. **Lançamento aberto:** site → cadastro pelo próprio cliente (F25) → assistente de configuração
     (F24) → trial. Humano por exceção ou como implantação paga.
- **Canais (R$ 1.000/mês):**
  - **Primário — contadores:** painel do contador (F8/F22) + 20% de comissão recorrente ou desconto
    para o cliente indicado. Começar com 2 dos 5 escritórios.
  - **Secundário — Google Ads local (~R$ 600):** termos de alta intenção do segmento escolhido +
    cidade.
  - **Orgânico — Reels/TikTok:** "a nota do fornecedor virou estoque com margem em 1 minuto".
  - **Presencial (~R$ 200):** galerias, centros comerciais, associação comercial.
- **Tração inicial — preço de fundador:** plano Loja a R$ 79/mês fixos por 12 meses para os 20
  primeiros, em troca de depoimento em vídeo, feedback semanal e caso de sucesso.
- **Calendário:** piloto nov–dez/2026 · beta fechado jan/2027 · lançamento fev–mar/2027 (lojas não
  trocam de sistema na Black Friday e no Natal).

## 4. Retenção, CS e unit economics

- **Momento aha:** primeira nota de compra virou estoque com margem e primeira venda no PDV.
- **Time-to-value:** até 48 h (etapa 1, concierge); assistente F24 na etapa 2.
- **North Star:** lojas ativas que viram a margem real em uma nota de compra na semana.
- **Expansão (NRR):** prévia oculta da margem no Balcão, oferta ao abrir caixa além do limite,
  segunda loja com desconto, add-ons; downgrade em vez de cancelamento (F26).

| Métrica | Meta | Cenário base calculado | Observação |
|---|---|---|---|
| CAC payback | < 6 meses | ≈ 5,2 meses com o tempo do Allan valorado | Sem o tempo dele, ≈ 3,3 meses |
| Churn mensal de logos | **≤ 3% meta**, 5% é alerta | — | Benchmark SMB: 3–7%/mês |
| Margem bruta | > 80% | ≈ 82% | Infra própria, sem API fiscal por nota |
| LTV / CAC | ≥ 3× | ≈ 6× a 10× | Depende do churn real |

**Limite real:** horas de suporte, não dinheiro — com 10 h/semana, ~20 clientes recém-implantados
ou ~40 estáveis. Primeira contratação: suporte/implantação.

## 5. Decisões que dependem do Allan

1. Segmento do beta (perguntar a carteira de cada contador).
2. Ramo da empresa piloto.
3. Nome: GestãoFácil e Orby descartados (domínios ocupados; PLAN-LANCAMENTO §5). Finalistas
   **Lucral** e **Lucrário** (com raiz), **Vorna** (abstrato), todos com `.com.br` livre em
   22/10/2026 — falta escolher, registrar o domínio, consultar o INPI e testar com lojistas.
4. Custos fixos e pró-labore, para o ponto de equilíbrio.
5. Política de reembolso do anual (validar com contador/advogado).
