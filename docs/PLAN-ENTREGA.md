# PLAN-ENTREGA.md — Qualidades do sistema e o que entregamos além dele

> **Atenção:** este documento trata de qualidades técnicas e serviços de entrega. Missão, visão,
> valores e promessa de marca estão em [`PLAN-MARCA.md`](./PLAN-MARCA.md).

**Status:** PLANO. Escrito em 2026-10-22. Organizado pelo *Total Product Concept* (Theodore Levitt,
"Marketing Success Through Differentiation — of Anything", HBR 1980) e pelo "produto completo" de
Geoffrey Moore (*Atravessando o Abismo*). Cada qualidade tem **situação**: só vira frase de venda o
que estiver "comprovado".

**Documentos relacionados:** [`PLAN-DIFERENCIACAO.md`](./PLAN-DIFERENCIACAO.md) ·
[`PLAN-NEGOCIO.md`](./PLAN-NEGOCIO.md) · [`PLAN-PRODUCAO.md`](./PLAN-PRODUCAO.md) ·
[`PLAN-SEGURANCA.md`](./PLAN-SEGURANCA.md) · [`PLAN-EXECUTIVO.md`](./PLAN-EXECUTIVO.md)

---

## 1. As quatro camadas do produto (Levitt)

| Camada | O que é | Para nós |
|---|---|---|
| **Genérico** | O mínimo para existir | Emitir nota, vender no PDV, controlar estoque |
| **Esperado** | O que o cliente pressupõe sem pedir | Não perder venda, nota sempre sai, dados guardados, suporte que responde |
| **Ampliado** | O que vai além do esperado e diferencia | Margem real, estoque pela nota, implantação feita por nós, contador junto, relatório do lucro |
| **Potencial** | O que pode vir a ser | Comparativo de margem com lojas parecidas, reposição inteligente |

Regra de Kano (PLAN-DIFERENCIACAO §3.6): **não vender o ampliado enquanto o esperado falhar.**

## 2. Qualidades do sistema

| Qualidade | Frase para o cliente | Situação (22/10/2026) | O que falta para poder prometer |
|---|---|---|---|
| **Fiscal correto** | "A nota sai certa, e se der erro a gente explica" | Emissão NF-e/NFC-e, cancelamento, CC-e, inutilização e contingência implementados; busca de notas de entrada testada em produção | PLAN-PRODUCAO fase E (ciclo completo com certificado real, primeira nota de produção) |
| **Estoque pela nota** | "A mercadoria chega e já está no estoque com o custo certo" | **Comprovado** (importação + DistDFe em produção) | Medir: % de itens que entram sem ajuste manual |
| **Margem real** | "Você vê quanto ganha em cada item" | Custo real já calculado na entrada; tela de margem **a construir** (F17/F18) | F17, F18 |
| **Simples** | "Sem treinamento: em 15 minutos a equipe usa" | Linguagem própria, perfis de acesso; não medido | Teste com 3 lojistas que nunca viram o sistema; cronometrar |
| **Rápido no balcão** | "Venda com cupom em segundos" | **Não medido** | Medir tempo do bipe ao cupom autorizado no piloto; definir meta |
| **Em qualquer aparelho** | "Funciona no computador, tablet e celular" | Telas responsivas por requisito; conferência em celular não registrada | Conferir PDV e conferência de nota no celular |
| **Sem instalar nada** | "Abre no navegador" | **Comprovado** (web) | — |
| **Seguro** | "Cada loja só vê os próprios dados; certificado guardado com criptografia" | Isolamento multiempresa e cifra de certificado tratados no PLAN-SEGURANCA; HTTPS de produção (A5) aberto | PLAN-PRODUCAO A5, B1–B4 |
| **Dados guardados** | "Backup todo dia, fora do servidor" | **Não pode ser prometido:** PLAN-PRODUCAO C1–C5 abertos (script de backup falha, sem cópia externa, sem teste de restauração) | C1–C5, com restauração testada |
| **Disponível** | "Se cair, a gente sabe antes de você" | Monitoramento (D3) aberto | D3 e alerta funcionando |
| **Dados são seus** | "Leve seus dados quando quiser" | ZIP de XML das notas existe; exportação de produtos/clientes/vendas **não verificada** | Exportação completa (CSV) |

Pendência de conferência: o PLAN-PRODUCAO mostra 33 itens abertos e 2 feitos em 22/10/2026. Se
parte já foi feita sem marcar, atualizar o documento antes de revisar esta tabela.

## 3. O que entregamos além do sistema

Pela jornada do cliente. **Custo** = horas do Allan por cliente; **escala** = como deixa de depender
dele.

### 3.1 Antes de assinar

| Entrega | Descrição | Custo | Escala |
|---|---|---|---|
| **Diagnóstico de margem grátis** | "Mande 3 notas de compra e mostramos a margem real de 10 itens seus." Usa o diferencial como isca: o lojista vê o valor antes de pagar | ~30 min | Vira tela pública de upload de XML com resultado automático (depois de F17) |
| **Calculadora de preço** | Planilha/página gratuita: custo da nota → preço com margem desejada (inclui desconto, IPI, frete, ST) | Uma vez | Material de anúncio e Instagram |
| **Demonstração com as notas dele** | 20 min, na etapa 1 (PLAN-NEGOCIO §9.1) | 20 min | Vídeo gravado na etapa 2 |

### 3.2 Na entrada (implantação)

| Entrega | Descrição | Custo | Escala |
|---|---|---|---|
| **Estoque pronto em 48 h** | XMLs de 90 dias (do contador) carregados e conferidos | ~3 h | Upload em lote guiado + F24 |
| **Ajuda com o certificado digital** | Indicar onde comprar (buscar parceria com uma certificadora para desconto) e instalar junto | ~30 min | Passo a passo em vídeo; contador faz |
| **Liberação da NFC-e na SEFAZ** | Passo a passo do CSC da UF do cliente, ou feito pelo contador | ~30 min | Guia por UF |
| **Numeração do sistema antigo** | Descobrir o último número emitido para não colidir (PLAN-PRODUCAO E4) | ~15 min | Pergunta no assistente F24 |
| **Equipe treinada** | Vídeo de 3 min "como vender no balcão" + 15 min ao vivo no primeiro dia | 15 min | Só vídeo |

### 3.3 No dia a dia

| Entrega | Descrição | Custo | Escala |
|---|---|---|---|
| **Suporte humano** | WhatsApp, resposta em até 1 h útil (PLAN-NEGOCIO §1) | Variável | Vídeos de 1 min para as 10 dúvidas mais comuns; ajudante com ~30 clientes |
| **Avisos antes do problema** | Certificado vencendo (já existe), nota rejeitada, SEFAZ fora do ar, fornecedor subiu preço (F18) | ~0 | Automático |
| **Acompanhamento da 1ª semana** | Allan olha se a loja vendeu, importou nota e viu margem; chama se travou | ~15 min | Checklist de ativação automático (F24) |

### 3.4 Todo mês

| Entrega | Descrição | Custo | Escala |
|---|---|---|---|
| **Relatório do lucro** | Margem do mês, itens que mais deram lucro, itens com margem caindo, peças paradas. Nos primeiros clientes, comentado pelo Allan em áudio de 2 min | ~10 min | Relatório automático (evolução do F23) |
| **Mês fechado para o contador** | XMLs de entrada e saída + pendências no dia 1 (F22) | ~0 | Automático |

### 3.5 Educação ("Escola do balcão")

Vídeos de 1 minuto e posts: como calcular preço, o que é margem x markup, como ler a nota do
fornecedor, quando o fornecedor está cobrando caro, como lidar com peça parada. Serve três vezes:
marketing (Instagram/TikTok), suporte (menos dúvidas) e retenção (o cliente aprende a usar o
diferencial).

### 3.6 Garantias

| Garantia | Situação |
|---|---|
| Sem fidelidade no mensal | Decidido (PLAN-NEGOCIO §9.3) |
| Preço travado 12 meses; reajuste ≤ IPCA com 60 dias de aviso | Decidido |
| Trial de 30 dias sem cartão | Decidido |
| **Dados são seus:** ao cancelar, 90 dias de acesso só leitura + ZIP de todos os XMLs + exportação em CSV | Proposta; exportação CSV a construir |
| **Guarda dos XMLs por 5 anos** (prazo legal) enquanto cliente | **Só prometer depois** de C1–C5 do PLAN-PRODUCAO |

### 3.7 Para o contador

Painel (F8), mês fechado (F22), configuração fiscal pelo painel (F21), comissão de 20%, kit de
divulgação (PLAN-LANCAMENTO §8).

## 4. Produto potencial (depois de ter base)

- **Comparativo de margem com lojas parecidas:** "sua margem em linhas e agulhas está 8 pontos abaixo
  da média de armarinhos da sua região". Só com dados agregados e anonimizados, consentimento
  explícito (LGPD) e base mínima por segmento (ex.: 10 lojas). Vira efeito de rede: cada loja nova
  melhora o comparativo — o tipo de vantagem que um concorrente genérico não copia rápido.
- **Reposição inteligente** com histórico de várias lojas do mesmo segmento.

## 5. Capacidade: quanto custa em horas

Implantação completa da etapa 1 ≈ **4 h 30 por cliente** (demo, estoque, certificado, SEFAZ,
treino, 1ª semana). Somado ao suporte, isso confirma o limite de ~3 clientes novos por semana
(PLAN-NEGOCIO §9.1). Ordem para automatizar, do que mais consome para o que menos:
1. Carga do estoque (3 h) → upload guiado.
2. Certificado e SEFAZ (1 h) → contador faz / guia por UF.
3. Diagnóstico de margem (30 min) → página automática.

## 6. Próximos passos

1. Atualizar o PLAN-PRODUCAO (o que já foi feito e não está marcado).
2. Fechar C1–C5 (backup) antes de qualquer cliente pagante — é a qualidade "esperada" que, se falhar,
   não tem desculpa.
3. Medir no piloto: tempo de venda no balcão, % de itens importados sem ajuste, tempo de implantação.
4. Montar o diagnóstico de margem grátis com as notas da empresa piloto (é também o teste da tese,
   PLAN-DIFERENCIACAO §7).
