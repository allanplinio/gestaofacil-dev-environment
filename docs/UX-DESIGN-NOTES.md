# Notas de Design & UX — GestãoFácil

Este documento complementa `REQUISITOS.md` com diretrizes de design, princípios de UX e considerações de usabilidade baseadas em benchmarks (Bling) e boas práticas de PDV.

---

## 1. PDV: Prioridade para Velocidade

O PDV é o "coração" do varejo. A experiência deve ser **extremamente rápida** — cada segundo perdido multiplicado por 100+ transações por dia = frustração crescente.

### Princípios de velocidade no PDV

#### 1.1 Busca de produto deve ser **quase instantânea**

- **Input de busca**: campo sempre visível, com foco automático ao abrir PDV
- **Sugestões em tempo real**: conforme o usuário digita, mostrar produtos que batem (SKU, código de barras, nome)
- **Código de barras**: ler diretamente, sem cliques extras
- **Teclado otimizado**: permitir Tab entre campos sem mouse
- **Histórico**: últimos produtos vendidos aparecem primeiro (80/20 rule — 20% dos produtos compõem 80% das vendas)

#### 1.2 Carrinho deve ser visível e rápido de editar

- Produtos aparecem **imediatamente** no carrinho assim que são adicionados
- Aumentar quantidade: input direto ou +/- botões grandes
- Remover item: clique único ou swipe (mobile)
- **Sem modais ou telas intermediárias** — tudo inline no carrinho
- Total atualiza em tempo real conforme itens são adicionados/modificados

#### 1.3 Cliente (opcional) deve ser rápido

- Campo de cliente com **busca** (não dropdown — rápido demais para scrollar)
- "Consumidor Final" **pré-selecionado** — um clique/Enter tira o campo
- Se digitar algo que não existe, oferece criar rápido (nome + CPF) ou deixa em branco
- Histórico de clientes recentes

#### 1.4 Pagamento deve ter **mínimo de cliques**

- Tipo de pagamento: **botões atalho** pré-configurados (Dinheiro, Crédito, Débito, PIX) — não dropdown
- Ao clicar em um tipo, campo de valor já vem preenchido com o saldo devedor
- Se valor pago > total, calcular troco automaticamente
- Múltiplos pagamentos: **adicionar mais um** botão rápido, não nova tela

#### 1.5 Finalização sem bloqueios

- Ao confirmar venda, já mostra opcões de próxima ação imediatamente
- Não aguardar emissão de nota para confirmar venda — é assíncrona
- Imprimir cupom deve ser 1 clique
- Botão "Nova venda" já limpa tela e coloca foco no campo de busca

### Fluxo ideal do PDV (alvo: < 1 minuto para venda simples)

```
[Buscar produto] → [Add ao carrinho] → [+Qtd se necessário] → 
[Selecionar cliente ou deixar em branco] → 
[Escolher forma de pagamento] → 
[Confirmar venda] → 
[Emitir nota agora? Imprimir cupom? Nova venda?]
```

**Métrica de sucesso**: operador experiente completa venda de 1-3 produtos em < 45 segundos.

---

## 2. Pedido: Tela Completa e Detalhada

Em contraste, Pedido é uma tela "de escritório" — permite mais detalhes, validações e controles.

### Diferenciais do Pedido vs PDV

| Aspecto | PDV | Pedido |
|--------|-----|-------|
| **Cliente** | Opcional, rápido | Obrigatório (exceto Consumidor Final em NFC-e) |
| **Observações** | Sem campo | Campo livre (instruções especiais, personalizações) |
| **Lançamento de estoque** | Automático ao finalizar | Controlado: fazer depois, agora, ou não fazer |
| **Edição após venda** | Impossível (cancelar e criar nova) | Possível enquanto não Atendida |
| **Cálculos extras** | Raramente | Descontos por item, frete, juros |
| **Histórico visual** | Não tem | Mostra datas, quem criou, quem atendeu |

### Tela de Pedido — o que incluir

- **Cabeçalho**: Cliente (com busca/criar), data de criação, referência (número interno)
- **Items**: tabela com nome do produto, quantidade, preço unitário, desconto, subtotal
- **Descontos**: global (% ou valor) + linha separada explicando
- **Frete/extras**: campos opcionais para despesas adicionais
- **Observações**: campo de texto livre
- **Lançamento de estoque**: radio buttons (Não lançar, Lançar agora, Lançar quando atender)
- **Total**: destaque visual (número grande, cor clara)
- **Botões de ação**: Cancelar, Salvar, Atender (ou Confirmar), Emitir nota

---

## 3. Gaps Identificados (comparado com Bling e boas práticas)

### 3.1 Funcionalidades de NFe faltando na v1

**Carta de Correção (CCe)**: Quando há erro na nota já emitida (não crítico), emite uma CCe instead de cancelar + nova.
- **Considerar para v2**: permite corrigir erros de digitação sem perder número de série

**Inutilização de numeração**: Quando um número de serie fica vago (pulado acidentalmente), precisa inutilizar pra SEFAZ
- **Considerar para v2**: impacto pequeno, mas importante pra regulatório

**Contingência**: Se SEFAZ cai, empresa pode emitir nota em modo offline e sincronizar depois
- **Fora de escopo v1**: deixar para fase posterior

### 3.2 Estoque

**Reserva de estoque em Pedido**: Quando pedido é criado, reservar quantidade pra evitar venda dupla
- **Considerar para v2**: funcionalidade importante pra gestão, mas aumenta complexidade

**Previsão de entrada**: Quando há compra pendente, avisar "em 3 dias chega novo estoque"
- **Fora de escopo**: integração com módulo de Compra (futuro)

### 3.3 Operações com NFe Já Emitida

**Carta de Correção (CCe)**: Quando nota autorizada tem informações erradas (CNPJ cliente, endereço, descrição)
- **DEVE estar em v1**: operação comum do dia a dia
- Acessar via: Detalhe da venda > botão "Emitir Correção"
- Selecionar campo errado > inserir valor correto > enviar para SEFAZ

**Inutilizar numeração**: Quando número de série fica vago (vendedor começou NFe e desistiu)
- **DEVE estar em v1**: requisito legal + operação rotineira
- Acessar via: Configuração Fiscal > "Inutilizar Numeração"
- Informar número ou range > envia para SEFAZ com motivo

### 3.4 Buscas e Filtros

**Filtro avançado em lista de pedidos**: por cliente, por período, por status, por usuário que criou
- **Deve estar em v1**: é crítico pra encontrar pedidos rapidamente

**Busca global**: digitar em qualquer lugar (cliente, número de venda, SKU) e trazer resultados
- **Considerar para v2**: nice-to-have, mas aumenta UX

### 3.5 Integração com impressoras

**Cravação de impressora**: PDV deve conhecer qual impressora usar (térmica pra cupom, a4 pra nota)
- **Considerar v1**: se houver tempo, é importante pra operação real

---

## 4. Prototipagem & Testes de Usabilidade

### Antes de codificar PDV, testar com usuário real (vendedor/caixa)

- [ ] **Teste de velocidade**: cronometrar venda simples (3 produtos, 1 cliente, dinheiro)
- [ ] **Teste de código de barras**: simular leitura rápida (batch de codes)
- [ ] **Teste de recuperação de erro**: vendedor entra quantidade errada, remove produto, voltar atrás
- [ ] **Teste de divisão de pagamento**: 50 reais + 25 cartão = 75 total (validar que calcula certo)
- [ ] **Teste mobile**: tablet 10", smartphone 6", com toque (sem mouse)

### Métricas de sucesso

- **Tempo para venda**: < 1 minuto (3 produtos, 1 cliente, dinheiro)
- **Taxa de erro**: < 5% de vendas precisam ser canceladas por digitação
- **Satisfação**: usuário sente-se "rápido" usando o sistema (NPS ou simples pergunta)

---

## 5. Responsividade — Layout Strategy

### Desktop (1280px+)
- Sidebar esquerdo com menu de navegação
- Conteúdo principal à direita
- PDV: carrinho à direita, busca/cliente à esquerda (tela cheia para produtos)

### Tablet (768-1280px)
- Menu collapsa em ícones (drawer on swipe)
- Carrinho do PDV pode ficar em abas (produtos | pagamento)
- Formulários adapta-se: 2 colunas → 1 coluna

### Mobile (< 768px)
- Menu em drawer/hamburger
- Stacked layout (tudo em 1 coluna)
- PDV: carrinho sempre visível ao rodar pra horizontal (landscape mode)
- Botões grandes (48x48px mínimo pra toque)

### PDV em Mobile — POC Priority
- [ ] Testar entrada de código de barras (camera input ou USB scanner)
- [ ] Testar pagamento rápido (touchscreen)
- [ ] Testar responsividade em landscape (mais útil pra balcão)

---

## 6. Fluxos Críticos — Prototipo de Wireframes

### PDV — Fluxo esperado

```
┌─────────────────────────────────────┐
│  GestãoFácil - PDV                  │
├──────────────┬──────────────────────┤
│              │                      │
│   BUSCA      │   CARRINHO           │
│  [Produto]   │   ┌────────────────┐ │
│              │   │ Feijão 5kg  x2 │ │
│   Sugestões: │   │ R$ 25,00       │ │
│   • Feijão   │   │                │ │
│   • Fé...    │   │ Pão Francês x1 │ │
│   • Feijã... │   │ R$ 5,00        │ │
│              │   │                │ │
│              │   ├────────────────┤ │
│              │   │ TOTAL: R$ 55,00│ │
│              │   └────────────────┘ │
├──────────────┴──────────────────────┤
│ Cliente: Consumidor Final [v]       │
├─────────────────────────────────────┤
│ [Dinheiro] [Crédito] [Débito] [PIX] │
│ Valor recebido: [55,00]             │
│ Troco: [Automático]                 │
├─────────────────────────────────────┤
│ [Cancelar] [Finalizar] [Emitir NFe] │
└─────────────────────────────────────┘
```

### Pedido — Fluxo esperado

```
┌──────────────────────────────────────────┐
│ GestãoFácil - Novo Pedido                │
├──────────────────────────────────────────┤
│ Cliente: [Buscar/Criar]                  │
│ Data: [Auto - hoje]                      │
├──────────────────────────────────────────┤
│ Itens:                                   │
│ ┌─────────────────────────────────────┐  │
│ │ Produto   │ Qtd │ Preço │ Desconto │  │
│ ├─────────────────────────────────────┤  │
│ │ Feijão 5k │  2  │ 12,50 │   -     │  │
│ │ Pão Franc │  1  │  5,00 │   -     │  │
│ │ [+ Produto]                         │  │
│ └─────────────────────────────────────┘  │
│                                          │
│ Observações: [Entregar amanhã cedo]     │
│ Desconto geral: [   ] %                 │
│ Frete: [   ]                            │
│ TOTAL: R$ 30,00                         │
│                                          │
│ Lançar estoque:                          │
│ ( ) Não lançar  (●) Agora  ( ) Depois   │
├──────────────────────────────────────────┤
│ [Cancelar] [Salvar] [Atender]            │
│            [Emitir NFe]                  │
└──────────────────────────────────────────┘
```

---

## 7. Validações e Feedback de Erro

### PDV — Evitar bloqueios, favorecer continuidade

- ✅ Produto não existe? "Produto não encontrado — continue digitando ou [Enter] pra novo"
- ✅ Estoque zerado? Avisar mas deixar adicionar (venda em pré-venda é válida)
- ✅ Valor pago < total? Calcular restante automaticamente
- ❌ Nunca travar o PDV esperando resposta do servidor — cache/offline-first pra dados críticos

### Pedido — Validações antes de atender

- ✅ Cliente obrigatório? Validar só ao atender
- ✅ Falta info de CFP/CNPJ pra nota? Avisar só quando tentar emitir
- ✅ Estoque insuficiente? Avisar mas deixar criar pedido (ajuste depois)

---

## 8. Padrões de Design & Componentes Reutilizáveis

### Componentes core necessários

- **Input com sugestão/autocomplete** (cliente, produto, estoque)
- **Tabela rápida** (carrinho, pedidos, movimentações)
- **Modal confirmação** (cancelar, deletar, emitir)
- **Badge status** (Em aberto, Atendido, Cancelado, etc)
- **Toast notification** (venda salva, nota emitida, erro)
- **Loading skeleton** (enquanto carrega lista de produtos)

### Atalhos de teclado (PDV)

| Tecla | Ação |
|-------|------|
| `Tab` | Próximo campo |
| `Shift+Tab` | Campo anterior |
| `Enter` | Buscar produto / Adicionar ao carrinho / Confirmar |
| `Esc` | Limpar busca / Cancelar ação |
| `F1` | Abrir cliente |
| `F2` | Abrir pagamento |
| `F12` | Abrir observações |

---

## 9. Resumo: O que diferencia GestãoFácil do Bling em v1

| Feature | Bling | GestãoFácil v1 |
|---------|-------|---------|
| PDV rápido | ✅ Otimizado | ✅ **Foco total aqui** |
| Pedido completo | ✅ Robusto | ✅ Básico mas funcional |
| Emissão NFe | ✅ Integrada | ✅ Integrada (API externa) |
| Carta de correção | ✅ | ❌ v2 |
| Inutilização | ✅ | ❌ v2 |
| Reserva de estoque | ✅ | ❌ v2 |
| Relatórios | ✅ Vários | ❌ v2 |
| Mobile responsivo | Parcial | ✅ Full + POC PDV mobile |

**Diferencial GestãoFácil v1**: Foco laser em PDV rápido + Pedido funcional + responsividade mobile desde o início.

---

## 10. Priorização para MVP

### Must-have (bloqueia v1)
- [ ] PDV funcionando e rápido (< 1 min por venda)
- [ ] Pedido criação/edição/atendimento
- [ ] Emissão de NFe básica
- [ ] Responsividade desktop + mobile

### Nice-to-have (se sobrar tempo)
- [ ] Atalhos de teclado no PDV
- [ ] POC PDV em mobile
- [ ] Integração com impressora
- [ ] Histórico de últimos produtos/clientes

### v2
- [ ] Carta de correção
- [ ] Inutilização
- [ ] Reserva de estoque
- [ ] Relatórios avançados
- [ ] Financeiro
- [ ] Planos com cobrança
