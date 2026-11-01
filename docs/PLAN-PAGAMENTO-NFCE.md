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

## 2b. Bandeira e parcelas do cartão (01/11/2026)

Decisão do Allan: a nota precisa da **bandeira**, não da operadora. A primeira versão (operadoras de cartão com CRUD e CNPJ da credenciadora, `empresa_id`, menu Configurações) foi **removida por inteiro**; a migration atual apaga as tabelas caso o banco de dev as tenha. O grupo recolhível **Configurações** do menu ficou (Fiscal, Contas bancárias, Usuários).

- **Bandeira:** `App\Enums\BandeiraCartao` (01 Visa, 02 Mastercard, 03 American Express, 04 Sorocred, 05 Diners Club, 06 Elo, 07 Hipercard, 08 Aura, 09 Cabal, 99 Outras). Lista fixa — a SEFAZ só aceita esses códigos. O XSD só impõe `[0-9]{2}`; quem confere o código é a API (`Rule::enum` no checkout e o service) e o nfe-api (`in:`). Obrigatória em crédito e débito, proibida nas outras formas. Sai em `card/tBand`. `GET /pdv/bandeiras-cartao` expõe a lista; o front espelha a constante.
- **Parcelas:** só no crédito, obrigatória, inteiro de 1 a 24 (`VendaPagamento::MAX_PARCELAS`). A NF-e **não tem campo para o número de parcelas** (conferido no XSD). Sai como: `indPag` 0 (1x, à vista) ou 1 (2x ou mais, a prazo) no `detPag` e o texto `Cartao de credito em Nx` anexado às informações complementares (`infCpl`), que a NFC-e imprime. Não se inventa vencimento nem valor de parcela (grupo `cobr` não usado).
- Colunas novas em `venda_pagamentos`: `bandeira_cartao` (2) e `parcelas`.

## 3. Etapas (cada uma: revisar → testar → commitar)

- **E1 nfe-api**: `StoreNfeRequest` + `NfeXmlBuilder` + teste de XML.
- **E2 gestaofacil-api**: migration, model, CRUD, listagem PDV, checkout, payload da nota + testes
  (incluindo acesso entre empresas) e ajuste dos testes existentes que pagavam PIX/cartão sem dados.
- **E3 gestaofacil-fe**: tela de contas, menu, campos na linha de pagamento do PDV.
- **E4 e2e**: ajustar `PdvPage`/helpers que usam PIX/cartão.

## 4. Pendências conhecidas

- Nota já emitida não muda se a conta for editada depois (a conta não é congelada na venda).
- Verificação visual da tela fica com o Allan (Firefox).
