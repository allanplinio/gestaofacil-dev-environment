# PLAN-PRE-BETA.md — Funcionalidades antes do beta (F1 a F5)

**Status:** **PLANO — nada implementado.** Escrito em 2026-10-20, conferido contra o código de
`gestaofacil-fe`, `gestaofacil-api` e `nfe-api` na mesma data. Decisões abertas no §8; as marcadas
"recomendo" são a proposta, não o combinado.

**Documentos relacionados:** [`PLAN-LANCAMENTO.md`](./PLAN-LANCAMENTO.md) (§7 lista F1–F16) ·
[`PLAN-FINANCEIRO.md`](./PLAN-FINANCEIRO.md) · [`PLAN-SEGURANCA.md`](./PLAN-SEGURANCA.md) ·
[`DATA-MODEL.md`](./DATA-MODEL.md)

Cada fase passa pelo portão de etapa (revisar → testar → commitar → PROGRESS) e atualiza o
PLAN-SEGURANCA antes da seguinte.

---

## 1. Segmento: a ordem depende dele

O PLAN-LANCAMENTO assumiu moda porque foi o público citado. Revisando contra o que o produto faz
melhor hoje, **moda não é obviamente o melhor primeiro segmento**:

| Critério | Moda | Armarinho / aviamentos / artesanato / papelaria / utilidades |
|---|---|---|
| Compra com NF-e | **Parcial.** Parte relevante compra de confecção informal (polos, atacado sem nota) — a confirmar com os contadores | Sim, de distribuidores formais |
| Itens por nota de compra | Dezenas | **Centenas** (a nota real da Roma Aviamentos tem 313 itens) |
| Valor da busca automática + importação de XML | Médio | **Muito alto** — digitar 313 itens é o que faz a loja desistir de sistema |
| O que falta construir | Grade, etiqueta, troca, condicional | Etiqueta (muitos itens sem EAN: 42% "SEM GTIN" na nota real) |
| Concorrência específica | Alta (sistemas de moda já anunciam grade) | Baixa; atendidos por ERP genérico |
| Alcance por anúncio / Instagram | Alto | Médio |

**Recomendo:**
1. Lançar como **sistema para loja de balcão que compra com nota**, com página de venda por segmento.
2. Primeiro segmento = **o que os contadores parceiros mais atendem**. Pergunta a fazer a cada um:
   "quantos clientes de varejo você tem, de que ramo, e quantos compram com nota?". Isso custa uma
   conversa e troca palpite por dado.
3. Se não houver dado melhor: começar por **armarinho / aviamentos / artesanato / papelaria**, porque
   o produto já resolve a dor principal e falta só a etiqueta (F2). Moda vira a segunda onda, quando a
   grade (F1) estiver pronta.

**Efeito na ordem:** F5, F4, F2, F17, F18 e F3 servem a qualquer segmento e vêm primeiro. **F1
(grade) só é pré-requisito se o beta for de moda.**

## 2. Ordem e calendário

| Fase | Item | Tamanho | Quando | Por quê nesta ordem |
|---|---|---|---|---|
| 1 | F5 — Assinatura, limites e cobrança | M | Nov/2026 | Sem ela não se cobra ninguém no beta |
| 2 | F4 — Cupom pelo WhatsApp | P | Nov/2026 | Pequeno, visível, serve a todo segmento |
| 3 | F2 — Etiqueta com código de barras | M | Dez/2026 | Liga direto na nota de entrada (pilar de venda) |
| 4 | F17 — Margem real | M | Dez/2026 | Argumento de venda do plano Loja; dados já existem (`preco_custo_calc`). Especificação em [`PLAN-DIFERENCIACAO.md`](./PLAN-DIFERENCIACAO.md) §4 |
| 5 | F18 — Alerta de custo | P | Dez/2026 | Depende de F17 e usa F2 (etiqueta nova no reajuste) |
| 6 | F3 — Troca e vale-troca | G | Dez/2026–Jan/2027 | Tem parte fiscal que depende do contador |
| 7 | F1 — Grade cor/tamanho | G | Dez/2026–Jan/2027 | Só se o beta for moda; mexe em produto, estoque, PDV e importação |

Tamanhos são relativos (P < M < G). O calendário é apertado para uma pessoa que também dá suporte ao
piloto. Se escorregar, a ordem de corte é: F1 sai (se o beta não for moda), depois F3 cede antes de
F17/F18 — exceto se o beta for de moda, quando F3 e F1 ficam e o beta atrasa.

---

## 3. F5 — Assinatura, limites e cobrança

### O que existe
- `planos`: `preco_mensal`, `limite_vendas_por_mes`, `limite_usuarios`, `features` (array),
  `recomendado`, `ativo`. Seeder cria 3 planos com preço 0. **Nenhum código lê os limites.**
- `empresas`: `plano_id`, `proxima_cobranca`, `ativo`.
- Cadastro de empresa pela plataforma (`PlataformaNovaEmpresa`).

### O que construir
1. **Situação da assinatura** por empresa: `trial` → `ativa` → `em_atraso` → `suspensa` →
   `cancelada`, com data de fim do trial e histórico de mudanças.
2. **Limites que fazem sentido no varejo** — recomendo **não** limitar vendas por mês (pune a loja
   no mês bom e é imprevisível). Limitar por:
   - número de **caixas** (`pdv_secoes`). **Usuários ilimitados** em todos os planos (revisão de
     20/10/2026, PLAN-NEGOCIO §3.1: limitar usuário leva a loja a compartilhar senha);
   - **funcionalidades** por plano via `features` (`grade`, `etiqueta`, `troca`, `nfe_55`,
     `condicional`…).
   Um único ponto de leitura (`PlanoService::permite($empresa, 'grade')`) usado por API e front; o
   front esconde, a API recusa.
3. **Cobrança manual primeiro:** tela da plataforma onde o Allan registra pagamento (Pix), que move
   `proxima_cobranca`. Lembrete por e-mail/WhatsApp 5 dias antes e no vencimento. Gateway de
   assinatura (Asaas, Efí etc.) só depois de ~20 clientes.
4. **Inadimplência sem travar a loja de surpresa** (regra "avisar, não travar"):
   - dia 1–10 de atraso: faixa de aviso para o admin, tudo funciona;
   - dia 11–20: aviso para todos os usuários;
   - após dia 20: `suspensa` — **não abre venda nova**, mas consulta, XML, DANFE e exportação para o
     contador continuam liberados. Os dados são da loja.
   - nunca suspender no meio do expediente: a mudança vale a partir das 03:00.
5. **Trial de 30 dias** com plano Loja completo; no fim, escolhe plano ou entra em `suspensa` com a
   mesma regra de dados liberados.

### Testes
Cada transição de situação; limite de caixas/usuários na API (não só no front); suspensa ainda
baixa XML; trial vencendo à noite não bloqueia até 03:00.

---

## 4. F4 — Cupom pelo WhatsApp

### Abordagem
**Sem API do WhatsApp** na primeira versão: botão "Enviar pelo WhatsApp" na conclusão da venda abre
`https://wa.me/55<telefone>?text=<mensagem>` no WhatsApp Web/app do computador da loja. Custo zero,
sem conta Business, sem aprovação da Meta. A loja envia do próprio número, que é o que o cliente
conhece.

### O que construir
1. **Link público do cupom:** rota sem login que serve o DANFE NFC-e (ou o DANFE da NF-e) em PDF por
   um token aleatório longo, só leitura, com validade (recomendo 180 dias). Não expõe id sequencial.
2. **Mensagem** com nome da loja, valor, link do PDF e a **URL de consulta do QR Code** da NFC-e (vem
   no XML autorizado, `infNFeSupl/qrCode`) — o cliente consulta na SEFAZ mesmo sem o PDF.
3. **Telefone na hora da venda:** o `ClienteRapidoModal` já aceita telefone. Adicionar campo
   "WhatsApp do cliente" direto na conclusão da venda, sem obrigar cadastro completo.
4. **Imprimir passa a ser opcional:** configuração da empresa "imprimir cupom" (sempre / perguntar /
   nunca). A loja pode começar sem impressora.
5. Mesmo botão em Vendas e Notas fiscais, para reenviar.

### Cuidados
- LGPD: telefone salvo só no cliente, com texto curto explicando o uso; nada de lista de marketing
  automática a partir daqui (isso é F10, com consentimento).
- Rota pública com limite de requisições e sem indexação (`noindex`, token fora de log).
- Conferir com o contador da UF se o envio digital dispensa a impressão do DANFE NFC-e quando o
  consumidor concorda (regra varia por estado).

---

## 5. F2 — Etiqueta com código de barras

### O que existe
`produtos.codigo_barras`. A importação de XML já casa `cProd` com `codigo_barras` (nota real: 42%
dos itens vêm "SEM GTIN").

### O que construir
1. **Código interno para quem não tem EAN:** gerar EAN-13 de **circulação restrita** (prefixo 2,
   faixa reservada para uso interno da loja) com dígito verificador. Único por empresa.
2. **Modelos de etiqueta:**
   - folha A4 (modelos Pimaco mais comuns; começar com 2–3 tamanhos);
   - **térmica** em rolo (ex.: 40×25 mm), gerada como PDF no tamanho exato da etiqueta e impressa pelo
     driver da impressora pelo navegador. Sem agente local, sem ZPL na v1.
   - conteúdo configurável: nome curto, preço, código de barras, (tamanho/cor quando houver F1).
3. **Três pontos de entrada:**
   - **ao conferir nota de entrada:** "imprimir etiquetas desta nota" com quantidade = quantidade
     recebida (o gancho de venda: chegou, conferiu, etiquetou);
   - na lista de produtos, por seleção;
   - na troca de preço (etiqueta nova só dos alterados — `produto_preco_historico` já registra).
4. **Leitura no PDV:** o leitor USB já funciona como teclado; conferir que o código interno é
   encontrado pela busca do PDV.

### Testes
Dígito verificador; unicidade por empresa; PDF com dimensões exatas; código interno nunca colide com
EAN real (prefixo 2).

---

## 6. F3 — Troca e vale-troca

### Parte fiscal (decisão com o contador antes de codar)
Na troca, a mercadoria volta. O caminho formal é a loja emitir **NF-e de entrada de devolução**
(modelo 55, `tpNF=0`, `finNFe=4`, CFOP 1.202 / 1.411 conforme o caso, referenciando a chave da
NFC-e). **O `nfe-api` já monta nota de entrada e `refNFe`** (`NfeXmlBuilder.php:80` e `:101`).
Alguns estados aceitam procedimento simplificado. Recomendo: implementar o caminho formal, com a
opção da empresa de registrar troca "só no estoque" quando o contador disser que é aceito.

### O que construir
1. **Devolução a partir da venda:** escolher a venda (por número, cupom ou cliente), marcar itens e
   quantidades devolvidos, motivo; estoque volta via `EstoqueService` (como o cancelamento já faz).
2. **Destino do valor:**
   - **troca imediata** — abre venda nova com o crédito já aplicado;
   - **vale-troca** — crédito no cadastro do cliente (ou vale ao portador com código) com validade;
   - **estorno** — registra devolução de dinheiro/Pix.
3. **Nova forma de pagamento "Crédito da loja"** no PDV — hoje só há `dinheiro`, `credito`, `debito`,
   `pix`. Na NFC-e vira `tPag=05` (crédito loja).
4. **Cupom de troca sem preço** (para presente): impressão/link com os itens e prazo de troca, sem
   valores. Diferencial barato, muito pedido em moda e presentes.
5. **Política da loja:** prazo de troca configurável, impresso no cupom.

### Testes
Devolução parcial; devolver mais do que vendeu (recusa); vale usado em duas vendas até zerar; vale
vencido; nota de devolução referenciando NFC-e; estoque volta uma vez só.

---

## 7. F1 — Grade cor/tamanho (se o beta for moda)

### O que existe
Estoque é a coluna `produtos.estoque_atual`; PDV, pedido, NF-e, importação de XML e movimentação
trabalham com `produto_id`.

### Abordagem recomendada
**Cada variação é um produto** (linha em `produtos`) ligado a um **modelo** (`produto_grupos` ou
`produto_pai_id`), com `cor` e `tamanho`. Assim PDV, NF-e, estoque e importação continuam
funcionando sem reescrita — cada variação já tem código de barras, estoque e `cProd` próprios. O
alternativo (tabela de variações com estoque próprio) obriga a mexer em todos esses fluxos.

### O que construir
1. **Cadastro em matriz:** escolhe cores × tamanhos, o sistema cria as variações com o preço e os
   impostos do modelo; edição por exceção (preço diferente no GG, por exemplo).
2. **Grades prontas** (P-M-G-GG, 34–46, 33–44) e grades da empresa.
3. **Estoque em tabela** cor × tamanho na tela do produto e na movimentação.
4. **PDV:** leitor de código acha a variação direto; busca por nome abre a matriz para escolher.
5. **Importação de XML:** item do fornecedor casa com uma variação (por `cProd`/EAN); o vínculo
   fica salvo para as próximas notas (`produto_fornecedor_codigos` já existe).
6. **Etiqueta** (F2) com cor e tamanho; **relatório** de vendas e estoque por grade.
7. Nome na nota: "Modelo – Cor – Tamanho" no `xProd`.

### Testes
Criação em matriz idempotente; variação herda impostos do modelo; estoque por variação no PDV;
importação que casa variação; relatório soma o modelo.

---

## 8. Decisões abertas

| # | Decisão | Recomendo |
|---|---|---|
| D1 | Segmento do beta | Definir pela carteira dos contadores; sem dado, armarinho/aviamentos/papelaria |
| D2 | O que limita os planos | Caixas e funcionalidades; usuários ilimitados; não vendas/mês |
| D3 | Prazos de inadimplência | 10 / 20 dias, suspensão às 03:00, dados sempre liberados |
| D4 | Validade do link público do cupom | 180 dias |
| D5 | Troca: nota de devolução sempre ou opção "só estoque" | Formal por padrão, opção liberada pela empresa com aval do contador |
| D6 | Vale-troca nominal ou ao portador | Nominal por padrão; ao portador como opção |
| D7 | Modelo da grade | Variação = produto ligado a um modelo |
| D8 | Etiqueta térmica | PDF no tamanho da etiqueta; ZPL/agente local só se aparecer impressora que não funcione |

## 9. Perguntas para o Allan

1. Qual o ramo da empresa piloto? (A única nota de compra real do projeto é de uma loja de
   artesanato/aviamentos em PE — se for ela, reforça o §1.)
2. Os contadores atendem mais que ramo de varejo?
3. Alguém do piloto ou dos contadores já pediu alguma destas cinco, ou outra?
