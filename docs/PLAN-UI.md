# PLAN-UI.md — GestãoFácil UI (React)

**Documentos Relacionados:**
- [`REQUISITOS.md`](./REQUISITOS.md) — Escopo funcional v1
- [`PLAN-API.md`](./PLAN-API.md) — Endpoints e regras de negócio (sincronizado com fases aqui)
- [`DATA-MODEL.md`](./DATA-MODEL.md) — Schema (para entender validações e constraints)
- [`UX-DESIGN-NOTES.md`](./UX-DESIGN-NOTES.md) — Padrões de UX e performance

Este plano assume as telas e fluxos descritos em `REQUISITOS.md`, e consome a API descrita
em `PLAN-API.md`. As fases aqui seguem de perto as fases da API — dá pra desenvolver em
paralelo, mas cada tela só fica funcional de verdade depois que o endpoint correspondente
existe.

Convenção: usar Vite (não Create React App — mais leve, mais rápido de desenvolver,
consistente com a prioridade de "consumir pouco e ser rápido pra desenvolver").

**Alinhamento com PLAN-API.md:**
- Cada Fase N em PLAN-UI corresponde à Fase N em PLAN-API
- Telas só ficam funcionar quando endpoints existem
- Validações no frontend espelham regras de negócio em PLAN-API

---

## Fase 0 — Fundação do projeto

- [ ] Vite + React + TypeScript
- [ ] Roteamento (React Router)
- [ ] Cliente HTTP centralizado (axios ou fetch wrapper) com interceptor pra token de autenticação
- [ ] Context de autenticação (usuário logado, empresa atual, perfil)
- [ ] Layout base: menu lateral, cabeçalho, área de conteúdo
- **Commit:** "chore: project skeleton with routing and auth context"

---

## Fase 1 — Login

- [ ] Tela de Login (e-mail, senha)
- [ ] Tela de "Esqueci minha senha"
- [ ] Redirecionamento: sem token → tela de login; com token → dashboard
- [ ] Tratamento de erro: credenciais inválidas, empresa inativa (mensagens diferentes, conforme `REQUISITOS.md` seção 4)
- **Commit:** "feat: login flow"

---

## Fase 2 — Dashboard e navegação

- [ ] Tela inicial simples (resumo do dia: vendas recentes, produtos com estoque baixo — versão mínima, sem gráficos complexos ainda)
- [ ] Menu de navegação entre módulos (Produtos, Clientes, Vendas, Configurações)
- [ ] Indicação visual de qual empresa está logada (importante em multiempresa, mesmo que o usuário só tenha acesso a uma nesta fase)
- **Commit:** "feat: dashboard shell and navigation"

---

## Fase 3 — Configuração Fiscal

- [ ] Tela de upload de certificado (arquivo .pfx + senha) — campo de senha nunca reexibido depois de salvo
- [ ] Seleção de ambiente (Homologação/Produção) como ação separada do upload
- [ ] Indicador de status do certificado (válido, vencendo em breve, vencido, não configurado)
- [ ] **Atenção de UX:** deixar claro visualmente que trocar ambiente não pede a senha de novo, mas trocar de certificado (renovação) pede
- **Commit:** "feat: fiscal configuration screen"

---

## Fase 4 — Produtos e Estoque

- [ ] Lista de produtos (busca por nome/SKU, filtro por ativo/inativo):
  - Por padrão, mostra apenas produtos ativos
  - Checkbox "Mostrar inativos" para filtrar produtos inativos
  - Cada produto na lista indica se está ativo ou inativo
- [ ] Formulário de cadastro/edição de produto:
  - Nome, SKU, código de barras, NCM, unidade
  - Preço de compra (opcional, informativo)
  - Preço de venda
  - Status (ativo/inativo) com toggle
  - Botão [Inativar] na tela de detalhe (alterna para [Reativar] se inativo)
- [ ] Validação: ao tentar adicionar produto inativo em pedido, mostrar aviso mas permitir (pré-venda é válida)
- [ ] Tela de movimentações de estoque (histórico por produto)
- [ ] Formulário de ajuste manual de estoque (com campo de motivo obrigatório)
- **Commit:** "feat: produtos and estoque screens with inativar"

---

## Fase 5 — Clientes

- [ ] Lista de clientes (busca)
- [ ] Formulário de cadastro/edição
- **Commit:** "feat: clientes screens"

---

## Fase 6 — Vendas (PDV com NFC-e + Pedido com NF-e)

**Nota:** v1 implementa AMBOS:
- **PDV (Fase 6a):** Vendas rápidas no balcão com NFC-e (modelo 65)
- **Pedido (Fase 6b+):** Vendas administrativas com NF-e (modelo 55)

**Dependência crítica:** API nfe-api DEVE suportar NFC-e (modelo 65) antes do launch de GestãoFácil v1.

### 6a — Tela de PDV (com NFC-e)

Tela de maior atenção de UX — é usada em ritmo rápido, precisa ser eficiente pro operador.

- [ ] Busca de produto por nome/SKU/código de barras, com adição rápida ao carrinho
- [ ] Carrinho lateral (itens, quantidade editável, desconto por item)
- [ ] Seleção de cliente ou "Consumidor Final" (padrão)
- [ ] Tela de pagamento — suporte a múltiplas formas na mesma venda, com validação de soma == total
- [ ] **NFC-e Automática (modelo 65, B2C):**
  - PDV NUNCA pergunta qual tipo de comprovante emitir
  - Ao confirmar venda, NFC-e é enviada automaticamente à SEFAZ
  - Interface mostra status em tempo real: "Processando...", "✅ Autorizada", "❌ Rejeitada"
- [ ] Botão de fechar venda → chama a API, inicia emissão, mostra status da nota (processando/autorizada/rejeitada)
- [ ] Se emissão falhar: opção de [Reenviar] ou voltar pro carrinho
- [ ] **Alvo: venda simples em < 1 minuto** (ver `UX-DESIGN-NOTES.md`)

- **Commit:** "feat: PDV screen with NFC-e emission"

### 6a.1 — Resultado da venda em modal + acompanhamento da NFC-e (19/10/2026)

Origem: o caixa via "pendente" e precisava abrir outra página para saber se a nota saiu. A emissão continua
assíncrona (fila), então a tela é que passa a acompanhar. Implementado:

- [x] **Todo sucesso da frente de loja é um modal** ("Venda concluída"), não uma faixa no canto: "Venda salva com
      sucesso.", total, troco em destaque, situação da NFC-e e os botões *Nova venda* (foco inicial; Enter ou Esc
      fecham e devolvem o foco à busca) e *Imprimir comprovante*. Erro continua em faixa (`role="alert"`).
- [x] **Acompanhamento sem sair do caixa:** o modal consulta a nota a cada 1,5 s até sair de "pendente"
      (`useAcompanhamentoNfce`) e mostra *Emitindo NFC-e…* → *NFC-e autorizada · nº X* / *rejeitada: motivo*.
      O painel "Última venda" usa o mesmo resultado.
- [x] **SEFAZ demorando:** passados 10 s o modal diz que a venda está salva e a nota segue em processamento, com
      link para a tela da venda. A consulta desiste após 2 min (a nota segue valendo; o reconciliador de 5 min resolve).
- [x] **Endpoint do caixa:** `GET /pdv/vendas/{id}/nfce` (área `pdv`). `GET /nfe-emissoes` exige a área `notas`, que o
      **vendedor não tem** — usá-lo faria o modal ficar em "Emitindo…" para quem mais opera o caixa.
- [x] **Fila própria da NFC-e no nfe-api:** `ProcessNfeJob` do modelo 65 vai para a fila `nfce`, com supervisor
      dedicado no Horizon (`supervisor-nfce`: 2–4 processos em produção, 1 em dev) e alerta de espera em 15 s.
      Sem custo de infra novo (mesmo container e Redis). Toda fila nova precisa de supervisor em
      `config/horizon.php` — há teste que garante isso.
- [ ] **Decisão fiscal pendente:** o que o operador faz quando a SEFAZ passa de muito tempo (entregar o comprovante
      não fiscal? contingência offline da NFC-e?). O modal só informa; o fluxo de contingência não está implementado.
- **Testes:** (ver 6a.2 para a impressão) Pest (nfe-api: fila e supervisores; gestaofacil-api: `PdvNfceAcompanhamentoTest`, inclui vendedor e
  isolamento entre empresas) e E2E (`pdv-venda`, `pdv-pagamentos`, `fiscal/nfce-pdv`, `fiscal/regime-naturezas`).

### 6a.2 — Impressão: cupom fiscal quando há NFC-e (19/10/2026)

Defeito: o botão e a impressão automática sempre imprimiam o comprovante "Não é documento fiscal", mesmo com a NFC-e
emitida. Agora o botão do caixa (no modal e no painel "Última venda") imprime:

| Situação | Botão | O que sai |
|---|---|---|
| NFC-e pedida e **autorizada** | 🖨️ Imprimir cupom fiscal | DANFCE (PDF do nfe-api), pelo iframe escondido |
| NFC-e pedida, **pendente** | *Aguardando a autorização…* (desligado) | nada: ainda não existe cupom fiscal |
| NFC-e pedida que **não saiu** (rejeitada, erro) | 🖨️ Imprimir comprovante (sem valor fiscal) | comprovante, com o status da nota |
| Venda **sem** NFC-e (escolha do operador) | 🖨️ Imprimir comprovante | comprovante sem valor fiscal |

- "Imprimir cupom ao finalizar" marcado: com NFC-e espera a autorização e imprime o cupom fiscal sozinho; se a nota
  não sair **não imprime nada sozinho** (o operador decide pelo botão). Sem NFC-e imprime o comprovante, como antes.
- Endpoint `GET /pdv/vendas/{id}/danfe` (área `pdv`; o vendedor não tem `notas`): PDF, 202 enquanto gera, 404 sem nota.
- **Impressão direta (sem a janela de confirmação): uma página web não consegue.** `print()` sempre abre a janela do
  navegador, por segurança. O que dá para fazer é configurar o navegador do computador do caixa:
  - **Firefox:** `about:config` → `print.always_print_silent` = `true` (imprime na impressora padrão do sistema) e
    `print.show_print_progress` = `false`.
  - **Chrome/Edge:** abrir com `--kiosk-printing` (atalho do caixa) e deixar a impressora térmica como padrão.
  - Sem configurar nada, o cupom vai direto para a janela de impressão, sem passar por nova aba.
  - Não foi testado em impressora real; conferir no equipamento do caixa. Se o PDF não imprimir pelo iframe no
    Firefox, o código abre o PDF numa aba (plano B). Alternativa definitiva, se precisar: agente local de
    impressão (ex.: QZ Tray) — fora do escopo desta entrega.
- **Achado:** o DANFCE exige o QR Code, que o sped-nfe insere ao **assinar**. O `FakeSefazGateway` guarda a nota sem
  assinar, então no E2E o cupom fiscal falha ("Empty input"); com o gateway real a nota é assinada. Antes não havia
  nenhum teste do DANFCE: `nfe-api/tests/Feature/Danfe/DanfceTest.php` agora prova que a NFC-e assinada vira PDF.
  Nunca foi gerado um DANFCE a partir de uma NFC-e autorizada na SEFAZ real neste projeto: **conferir na primeira
  emissão em homologação.**

### 6a.3 — Nota fiscal na lista de pedidos (19/10/2026)

- [x] Coluna **Nota fiscal** em `/vendas`: situação da nota (Autorizada, Pendente, Rejeitada…) e `NFC-e/NF-e nº X`, ou
      "Sem nota". `GET /vendas` passa a mandar `nfe_emissao` (só id, modelo, status, número e série) em cada pedido,
      então vale também para o vendedor, que não tem a área `notas`.
- Pendência conhecida: `Vendas.tsx` ainda busca a nota de cada pedido por `GET /nfe-emissoes` para o menu de ações
  (várias chamadas, e falha em silêncio para o vendedor). A coluna usa esse resultado quando existe e, senão, o que a
  lista mandou. Dá para aposentar essa busca e alimentar o menu também por `nfe_emissao`; não foi feito por não ter
  sido pedido.

---

### 6b — Formulário de Pedido

- [ ] Seleção de cliente (obrigatório, busca/criação rápida)
- [ ] Busca de produto por nome/SKU, adição rápida à tabela de itens
- [ ] Tabela de itens (produto, quantidade, preço unitário, desconto por item, subtotal)
- [ ] Cálculo automático de total (com desconto global opcional)
- [ ] Seleção de múltiplas formas de pagamento (opcional em v1, pode ser "marcar depois")
- [ ] Opção de lançamento de estoque (agora / quando atender / nunca)
- [ ] Botão "Criar Pedido" → vai para tela de detalhe

### 6b — Tela de Detalhe de Pedido (com status de NFe)

- [ ] Dados da venda (cliente, itens, pagamento, total)
- [ ] Status do pedido (Em aberto / Atendido / Cancelado) com ações:
  - Se `em_aberto`: botões [Atender] [Cancelar]
  - Se `atendido`: botões [Cancelar] [Emitir NFe] [Reimprim/Download]
  - Se `cancelado`: aviso + link pra estorno de estoque se houver

- [ ] **Status de NFe** (seção bem visível):
  - Se não emitida: botão [Emitir NFe]
  - Se em processamento (queued/processing): spinner "Processando..."
  - Se autorizada: 
    - ✅ Autorizada em [data/hora]
    - Chave: `XXXX...XXXX` (copiável)
    - Links: [Download XML] [Download DANFE/PDF]
    - Ação: [Cancelar NFe] [Emitir Carta de Correção]
  - Se rejeitada:
    - ❌ Rejeitada em [data/hora]
    - Motivo: [mensagem do SEFAZ]
    - Ação: [Reenviar] [Cancelar e recriar pedido]
  - Se em contingência SVC:
    - ⚠️ Badge "Contingência SVC ativa"
    - Aviso: "Chave de acesso mudou por indisponibilidade da SEFAZ"
    - Chave anterior: `XXXX...` / Chave atual: `YYYY...`

- [ ] **Avisos operacionais (topos de página):**
  - Se empresa está em Homologação: banner vermelho "AMBIENTE: HOMOLOGAÇÃO"
  - Se certificado vence < 15 dias: banner amarelo "Certificado expira em N dias"
  - Se API retornou erro recentemente: banner vermelho "Erro ao emitir última nota"

- [ ] **Ações de NFe (Pedido tem opções, PDV é automático):**
  - **Se Pedido:** [Emitir NFe] → modal com 3 opções de comprovante:
    1. **Emitir NF-e (modelo 55)** — Nota fiscal com valor fiscal, envia à SEFAZ (padrão pré-selecionado)
    2. **Apenas cupom não-fiscal** — Imprime recibo sem valor fiscal, sem SEFAZ
    3. **Nenhum comprovante** — Finaliza sem gerar nada
    - Após seleção, retorna 202 "Enviado para processamento" (se NF-e)
    - Inicia polling automático a cada 5s (atualiza status em tempo real)
  - **Se PDV:** [Emitir NFC-e] é automático (não há modal, sempre modelo 65)
    - Mostra status em tempo real após confirmar venda
  - [Cancelar NFe] → modal com justificativa obrigatória + validação de prazo legal
  - [Emitir Carta de Correção] → modal com seleção de campo + valor correto
    - Campos disponíveis: "CNPJ do cliente", "Endereço do cliente", "Descrição do item", etc.

### 6c — Tela de Cancelamento de NFe

Modal de confirmação com:
- Motivo obrigatório (50-120 caracteres)
- Validação: é possível cancelar? (prazo legal < 30 dias)
- Se não: mensagem explicativa e nenhum botão de confirmar

### 6d — Tela de Carta de Correção

Modal com:
- Campo do tipo `<select>`: qual campo está errado (CNPJ, endereço, descrição item, etc.)
- Campo de texto: qual é o valor correto
- Histórico de CC-es já emitidas (se houver) com sequência

### 6e — Lista de Pedidos (com filtro avançado)

- [ ] Tabela de vendas (cliente, total, situação do pedido, status da NFe)
- [ ] **Filtros avançados:**
  - Situação: checkboxes (Em aberto, Atendido, Cancelado) — múltipla seleção
  - Período: data início e fim (date picker)
  - Cliente: **autocomplete com paginação** (cuidado: se houver muitos clientes, paginar resultados pra não ficar lento)
    - Busca enquanto digita (debounce 300ms)
    - Mostra máximo 10 resultados por vez
    - Opção de "Ver mais" se houver mais resultados
  - Usuário que criou (somente Administrador vê este filtro)
  - Ordenação padrão: mais recente primeiro
- [ ] **Coluna "NFe"** com ícones:
  - ❌ nenhuma (cinza)
  - ⏳ processando (spinner)
  - ✅ autorizada (verde)
  - ❌ rejeitada (vermelho)
  - ⚠️ contingência (amarelo)
  - ❌ cancelada (cinza + tachado)
- [ ] Clique na linha abre detalhe

- **Commit:** "feat: pedido creation, emissão, cancelamento, CC-e UI"

---

## Fase 7 — Área do Usuário (Senha e Preferências)

- [ ] Tela de Perfil do Usuário (acessível via menu/avatar no header)
- [ ] Formulário de alteração de senha (senha atual obrigatória, nova senha + confirmação)
- [ ] Validação de segurança: nova senha != senha anterior
- [ ] Confirmação de sucesso com toast notification
- [ ] Opcional: autosave de preferências (tema claro/escuro, idioma futura)
- **Commit:** "feat: user account area with password change"

---

## Fase 8 — Configuração Fiscal

**Objetivo:** Gerenciar certificado, ambiente (homolog/produção) e monitorar validade.

- [ ] Tela de Status de Certificado:
  - Se não configurado: banner informativo + botão [Upload de Certificado]
  - Se configurado:
    - Exibir: CNPJ, validade (data), status (válido / vencendo / vencido)
    - Badge "Homologação" em vermelho se `ambiente=2`
    - Botão [Trocar Ambiente] (home ↔ prod)
    - Botão [Renovar Certificado]

- [ ] Modal de Upload de Certificado:
  - Input de arquivo (.pfx obrigatório)
  - Input de senha (única vez)
  - Checkbox "Já testei em Homologação?" (informativo)
  - Botão [Enviar] → processa via API, mostra resultado
  - Se sucesso: mostra dados do certificado (CNPJ, validade)
  - Se erro: mensagem clara (formato inválido, senha errada, CNPJ incompatível)

- [ ] Seção de Inutilização de Numeração:
  - Botão [Inutilizar Números]
  - Modal com:
    - Tipo de documento (NF-e 55)
    - Série (se aplicável)
    - Número inicial
    - Número final (ou deixar em branco para número único)
    - Motivo (campo obrigatório, 50-120 chars)
    - Botão [Confirmar] (após confirmar, não pode desfazer)
  - Histórico de inutilizações abaixo (tabela: série, números, motivo, data, usuário)

- [ ] **Avisos operacionais:**
  - Se certificado vence < 30 dias: aviso em destaque
  - Se certificado vence < 7 dias: aviso crítico em vermelho
  - Link pra renovação (pode abrir formulário de upload)

- **Commit:** "feat: fiscal certificate management and inutilização"

---

## Fase 9 — Dashboard de NFe e Avisos

**Objetivo:** Visibilidade operacional de emissões, certificado e avisos críticos.

- [ ] Tela de Dashboard de NFe:
  - **KPIs (cards bem visíveis):**
    - Notas autorizadas hoje
    - Notas rejeitadas hoje
    - Taxa de sucesso (% de notas autorizadas / total enviadas)
    - Notas em contingência SVC (se houver)
  
  - **Alertas críticos (acima dos KPIs, se houver):**
    - Certificado expira em N dias (vermelho < 7, amarelo < 15)
    - Ambiente: Homologação (banner vermelho, bem visível)
    - Última emissão falhou (com botão [Reenviar])
  
  - **Gráfico simples (opcional em v1, pode ser v2):**
    - Notas autorizadas por dia (últimos 30 dias)
    - Proporção: autorizada vs rejeitada vs contingência
  
  - **Lista recente de notas:**
    - Últimas 10 vendas com NFe (data, cliente, status, chave)
    - Link pra detalhe de cada venda
    - Ícones de status (✅ autorizada, ❌ rejeitada, ⏳ processando, ⚠️ contingência)

- [ ] **Integração com Fase 8:**
  - Se certificado vence < 15 dias, avisar no dashboard
  - Botão direto [Renovar Certificado] redirecionando pra Fase 8

- [ ] **Notificações por toast:**
  - "NFe autorizada: [chave]" (sucesso)
  - "NFe rejeitada: [motivo]" (erro — com botão Reenviar se possível)
  - "Certificado expira em 15 dias" (warning)

- **Commit:** "feat: NFe dashboard with KPIs and alerts"

---

## Fase 10 — Perfis e Permissões

- [ ] Definir 3 perfis: **Administrador, Operador, Vendedor**
  - Administrador: acesso total (Produtos, Clientes, Vendas, Configuração Fiscal, Gestão de Usuários, Dashboard)
  - Operador: Produtos, Clientes, Vendas, Dashboard — sem acesso a Fiscal
  - Vendedor: PDV/Pedido (criar), próprios clientes/histórico — sem acesso a Configuração

- [ ] Middleware de autorização por perfil no frontend (redirect se acesso negado)
- [ ] UI adapta-se: menu mostra/esconde itens baseado no perfil

- **Commit:** "feat: role-based access control in UI"

---

## Fase 11 — Gestão de Usuários (Administrador)

- [ ] Tela de Lista de Usuários (apenas Administrador acessa):
  - Tabela com nome, email, perfil, empresa, status (ativo/inativo)
  - Botões: [Editar] [Inativar] (ou [Ativar] se inativo)

- [ ] Formulário de criar/editar usuário:
  - Nome, email, perfil (dropdown), ativo/inativo (toggle)
  - Ao criar: enviar email de convite com link pra "Definir Senha" (similar a "Esqueci Senha")
  - Ao editar: não mostra campo de senha (mudar via "Esqueci Senha")

- [ ] Tela de "Definir Senha" (link único do email de convite):
  - Email + nova senha + confirmação
  - Token de expiração (24h)
  - Redireciona pra login após sucesso

- **Commit:** "feat: user management (Administrador only)"

---

## Fase 12 — Planos e Cobrança (Versionado para futura integração)

**Nota:** v1 pode deixar isso pronto no backend mas escondido na UI. Apenas preparar estrutura.

- [ ] (Backend ready) Modelos de Planos com preços
- [ ] (Backend ready) Endpoint de upgrade/downgrade de plano
- [ ] (UI — v2 ou quando integrar pagamento) Tela de Planos visível (listar planos, preços, features)
- [ ] (Futura integração) Botão [Upgrade] que redireciona pra Stripe/PagSeguro

- **Commit (v1):** "chore: scaffold for billing management (feature flag or hidden)"

---

## Emissão Avulsa de NF-e/NFC-e (concluída em 22/09/2026)

Tela para emitir NF-e (55) ou NFC-e (65) **sem passar pela venda**: o usuário entra em
*Notas fiscais → Nova nota*, preenche e emite. O fluxo `/vendas/:id/emitir` continua existindo.
Backend: `PLAN-API.md`, "Emissão Avulsa". Referência visual: tela de nota do Bling, enxugada de
~150 campos para ~25 sempre visíveis.

### Telas

```
/notas                                   ← lista, ampliada
  ├─ [Nova NF-e] / [Nova NFC-e] → /notas/nova[?modelo=65]
  ├─ ação "Editar"              → /notas/:id/editar   (rascunho)
  └─ ação "Corrigir e reenviar" → /notas/:id/editar   (rejeitada, com o motivo no topo)
```

Não há tela de detalhe: acompanhamento e ações ficam na lista, e o clique na linha abre um modal.
Permissão: área `notas`.

- [x] **Formulário** (`pages/NotaForm.tsx`): cabeçalho (modelo, natureza, série, próximo número,
      status do certificado), destinatário, itens, transporte, totais, pagamento, informações
      complementares e opções avançadas (presença, consumidor final). Rodapé fixo com o total.
- [x] **Regras puras em `utils/notaFiscal.ts`** (validação, rateio, totais, rótulo do campo),
      separadas da tela e com a mesma regra do backend, para a prévia bater com o que é enviado.
- [x] **Lista**: modelo, série/número, destinatário, total, status (com motivo resumido da
      rejeição), data e menu de ações por status. Modal de detalhes com chave, protocolo, motivo
      completo (frase traduzida + texto da SEFAZ), histórico de envio e dados da inutilização.
- [x] **Acompanhamento**: enquanto houver nota pendente ou descartando na página, a lista consulta
      só essas linhas a cada poucos segundos e para depois de alguns minutos; daí em diante fica a
      ação "Consultar agora".
- [x] Rascunho (salvar, editar, excluir), correção e reenvio de rejeitada, descarte do número.

### Validação ao emitir

**O botão Emitir nunca fica desabilitado por validação.** Num formulário com muitos campos, um
botão desabilitado não diz o que falta. Ao clicar:

1. A tela confere o que o Serviço de NF-e vai exigir e, se faltar algo, **não envia**.
2. Um alerta no topo lista o que falta em linguagem do usuário ("Item 2 › NCM: informe o NCM",
   "Pagamentos somam R$ 90,00, total da nota é R$ 100,00"). Cada linha leva ao campo, e o campo
   fica marcado.
3. Problemas de configuração entram no mesmo alerta, com link para Config. NF-e (certificado
   vencido, nenhuma série do modelo, natureza inativa, CSC ausente na NFC-e).
4. O 422 do backend vira o mesmo alerta, por campo.
5. Avisos que **não** impedem o envio ficam em amarelo, visíveis enquanto o usuário preenche
   (estoque menor que a quantidade da nota).
6. Enquanto envia, o botão mostra "Enviando…" e ignora novos cliques; o backend também devolve
   409 para um segundo pedido da mesma nota.

Na nota rejeitada, o motivo traduzido fica no topo com o campo marcado, modelo e série ficam
travados (o reenvio mantém o número) e o botão principal vira "Reenviar".

### Celular e computador

Mesma tela nas duas larguras, com o layout ajustado pelos breakpoints do Tailwind.

| Parte | Computador | Celular |
|---|---|---|
| Campos | Duas ou três colunas | Uma coluna |
| Itens | Tabela | Cartão por item (qtde e preço no cartão, resto em "Detalhes do item") |
| Lista de notas | Tabela com menu de ações | Cartão por nota com menu de ações |
| Rodapé | Fixo, com total e botões | Fixo; "Emitir" em destaque, resto no menu "Mais" |
| Modais | Janela central | Tela cheia |
| Alerta | Topo do formulário | Topo; cada item rola até o campo e dá foco |

- Teclado certo por campo (numérico para CPF/CNPJ, CEP, NCM, telefone e quantidade; decimal para
  valores; e-mail para e-mail), alvos de toque de 44 px e CEP preenchendo endereço, município e
  código IBGE.
- Conferido em 360, 390, 768 e 1280 px, sem rolagem horizontal.

### Falta

- Testes automáticos: o projeto ainda não tem ferramenta de teste (decidido em 22/09/2026). A tela
  é coberta pelo roteiro manual nas quatro larguras e pelos testes de backend.
- Nota de devolução (documento referenciado) não entra por esta tela.

---

## Padrões Gerais & Componentes Reutilizáveis

- **Input com autocomplete** (cliente, produto, certificado CNPJ)
- **Tabela com paginação** (vendas, produtos, usuários)
- **Modal confirmação** (cancelar venda, inativar produto, inutilizar números)
- **Badge status** com ícones (venda: em_aberto/atendido/cancelado; NFe: queued/processing/authorized/rejected/cancelled/contingency)
- **Toast notifications** (sucesso, erro, warning com timeout auto)
- **Loading skeleton** (enquanto carrega dados)
- **Breadcrumb navigation** (facilita orientação em telas aninhadas)
- **Dropdown/Menu context** (ações rápidas por item)

---

## Responsividade (Mobile First)

- [ ] Layout adapta: desktop (sidebar + main), tablet (drawer colapsável), mobile (hamburger menu)
- [ ] Tabelas em mobile → cards empilhados (swipe pra mais detalhes)
- [ ] Botões mínimo 48x48px pra toque
- [ ] Inputs com font-size 16px+ pra não disparar zoom em iOS
- [ ] Modais: full-screen em mobile, centered em desktop

---

## Débito Técnico Consciente (Mesmo padrão da API)

- Sem live collaboration em pedidos (um usuário edita por vez)
- Sem histórico completo de edições em v1 (apenas timestamps)
- Sem relatórios avançados (apenas dashboard simples)
- Sem integração com impressoras (fica pra v2)
- Sem busca global cross-module (busca dentro de cada módulo)
- **Uma série por modelo na tela de Numeração** — decidido em 23/09/2026

### Numeração: uma série visível por modelo (decisão de 23/09/2026)

O backend suporta **várias séries** para o mesmo `(cnpj, ambiente, modelo)` — a chave do
`nfe_numbering` inclui a série, e `GET /numeracao/{cnpj}` devolve a lista inteira do ambiente
atual. Isso existe porque série é o mecanismo de numeração paralela: o uso clássico é **uma
série por caixa** no PDV, para dois terminais não emitirem o mesmo número ao mesmo tempo.

A tela de *Config. NF-e → Numeração* mostra **uma** série por modelo, e a emissão a partir de
venda usa **a menor série configurada** (`NfeEmissaoService::resolverSerie` → `$series[0]`
sobre a lista ordenada). A tela exibe essa mesma menor série, para não mostrar uma série
diferente da que vai sair na nota.

**Por que está aceito:** o sistema atende um caixa por instalação. Com um caixa, uma série por
modelo resolve, e escolher série na emissão seria configuração sem uso.

**Gatilho para mudar:** o primeiro cliente com **mais de um caixa** (ou mais de um ponto de
emissão simultâneo). Aí é obrigatório:

- a tela listar **todas** as séries do ambiente e modelo, não só a menor;
- deixar escolher/editar cada uma, em vez de tratar o campo como se fosse edição da única;
- a emissão receber **qual** série usar (do caixa/terminal), em vez de assumir a menor.

**Armadilha conhecida enquanto isso não muda:** salvar uma série diferente **cria outra**, não
renomeia a atual — e como a tela mostra a menor, parece que não salvou. Se a menor não for a
desejada, as outras ficam configuradas mas nunca são usadas. A tela avisa quando há mais de uma
série no modelo.


---

## Tela Notas na SEFAZ (`/notas-sefaz`) — decisões de interface (2026-10-19)

- **Período:** faixa dos 12 últimos meses com a quantidade de notas de cada um (ponto amarelo = aguardando ciência), seletor "Anteriores…", atalhos (30 dias, 90 dias, este ano, todo o período) e intervalo livre De/Até.
  Não usa `input type=month` (Firefox não suporta). Abre no mês atual ou no mais recente que tem nota.
- **Ações com dica ao passar o mouse** que diz o que vai à SEFAZ e se desfaz: Dar ciência, Confirmar recebimento, Recusar, Ignorar, Restaurar, Importar itens, ciência em massa.
- **Estados que a tela explica em vez de deixar clicar à toa:** ambiente de dev sem SEFAZ, empresa em homologação, intervalo mínimo entre buscas (contagem regressiva), XML ainda não liberado ("Importar itens (em N min)").
- **Botão desabilitado** não muda de cor no hover, em todo o sistema.
- **CPF/CNPJ:** campos de CNPJ com teclado de texto e maiúsculas (CNPJ alfanumérico); CPF numérico.
- **Troca de ambiente** (Config. fiscal › Certificado) salva sozinha, com confirmação ao ir para produção.
