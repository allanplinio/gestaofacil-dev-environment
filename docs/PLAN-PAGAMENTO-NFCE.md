# PLAN-PAGAMENTO-NFCE.md — Conta do PIX e documento do cartão na NFC-e

**Status:** implementado (2026-10-31), ver PROGRESS.md. Pedido do Allan: no PDV, PIX exige escolher a conta
bancária que recebeu; cartão (crédito/débito) exige o nº do documento do comprovante; as duas
informações saem na nota.

## 1. O que a SEFAZ aceita (conferido em `sped-nfe` `TraitTagPag::tagdetPag` e no `NfeXmlBuilder`)

`detPag` → grupo `<card>` (já emitido hoje para tPag 03/04/17/18, só com `tpIntegra=2`):

| Campo XML | Uso aqui |
|---|---|
| `card/cAut` (1–20 car.) | **nº do documento do comprovante** (crédito e débito) |
| `card/CNPJ` | CNPJ da **instituição** (banco/IP) da conta que recebeu o PIX — opcional na conta |

Fora do escopo: bandeira (`tBand`), CNPJ da credenciadora, `idTermPag`, TEF (`tpIntegra=1`).

## 2. Decisões

1. **Tabela própria `contas_bancarias`** (não `contas_financeiras` do PLAN-FINANCEIRO, que não existe
   ainda). Quando o financeiro for feito, ela vira o `tipo=banco` de lá — migrar, não duplicar.
2. **Conta é cadastro por empresa** (`empresa_id`, CompanyScope). Apelido obrigatório; banco, CNPJ da
   instituição, agência e conta opcionais. Excluir só se nunca usada; senão, **inativar**.
3. **Gestão = área `fiscal` (admin)**. **Listagem para o PDV** = `GET /pdv/contas-bancarias` (área `pdv`,
   só ativas), porque o vendedor não tem acesso à gestão.
4. **Venda grava** `venda_pagamentos.conta_bancaria_id` (PIX) e `documento_cartao` (crédito/débito).
5. **Checkout PDV passa a exigir**: PIX → conta ativa da empresa; crédito/débito → documento (1–20
   caracteres, letras e números). Campo de outra forma é rejeitado (não grava lixo).
6. **Escopo PDV**: pedido de venda (`/vendas/{id}/pagamentos`) não muda; a emissão lê os campos se existirem.
7. **Nota**: `NfeEmissaoService::construirPagamentos` manda `autorizacao` (cartão) e `cnpj_instituicao`
   (PIX); `nfe-api` valida e o `NfeXmlBuilder` grava `cAut` / `card/CNPJ`.

## 3. Etapas (cada uma: revisar → testar → commitar)

- **E1 nfe-api**: `StoreNfeRequest` + `NfeXmlBuilder` + teste de XML.
- **E2 gestaofacil-api**: migration, model, CRUD, listagem PDV, checkout, payload da nota + testes
  (incluindo acesso entre empresas) e ajuste dos testes existentes que pagavam PIX/cartão sem dados.
- **E3 gestaofacil-fe**: tela de contas, menu, campos na linha de pagamento do PDV.
- **E4 e2e**: ajustar `PdvPage`/helpers que usam PIX/cartão.

## 4. Pendências conhecidas

- Nota já emitida não muda se a conta for editada depois (a conta não é congelada na venda).
- Verificação visual da tela fica com o Allan (Firefox).
