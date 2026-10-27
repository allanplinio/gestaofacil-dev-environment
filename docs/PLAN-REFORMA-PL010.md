# Plano: Reforma Tributária (IBS/CBS) na emissão — layout PL_010

Status: **executado** (14–15/10/2026). Branch `feat/reforma-pl010` em `nfe-api`, `gestaofacil-api` e
`gestaofacil-fe`. Sem envio à SEFAZ. Registro de progresso: `PROGRESS.md` (seção "Reforma tributária").

## 1. Provas de conceito (feitas antes do plano)

Feitas no container `nfe_api`, em cópia do repo (`/tmp/nfecopy`), com o teste `PocPl010Test`
(arquivo de apoio fora do repo: `scratchpad/PocPl010Test.php`).

| # | Teste | Resultado |
|---|---|---|
| P1 | Builder atual com `nfe.schemes = PL_010` (sem IBS/CBS) | Gera XML e **valida no XSD PL_010_V1.30** |
| P2 | Mesmo XML + grupo `IBSCBS` por item | **Valida no XSD PL_010_V1.30** |
| P3 | Controles negativos (sem `cClassTrib`; tag renomeada; elemento inválido) | Rejeitados: o XSD está sendo aplicado |

Conclusões: a sped-nfe 5.2.8 (a mais nova no Packagist) **não precisou de atualização**. O XSD PL_010 não torna
IBS/CBS obrigatórios; a obrigatoriedade real vem de regra das notas técnicas, fora do XSD.

## 2. Escopo

**Dentro (feito):**
- nfe-api: NF-e/NFC-e com grupo IBS/CBS por item quando informado; padrão continua PL_009_V4.
- nfe-api: contrato `itens.*.ibs_cbs` opcional, só formato (sem cálculo).
- gestaofacil-api: nota avulsa repassa o bloco quando preenchido. Nada no cadastro.
- gestaofacil-fe: bloco recolhido por item na nota avulsa, com ícone ⓘ por campo.

**Fora (decisões, ver seção 5):** cadastro de `cClassTrib` no produto, cálculo automático, layout por
emitente, totais e obrigatoriedade por CST, eventos e DANFE com IBS/CBS.

## 3. Fases e resultado

Cada fase: revisar → testar → commitar → PROGRESS.

| Fase | Projeto | Commit | Testes | Situação |
|---|---|---|---|---|
| F0 baseline | nfe-api | — | 357 passam, 23 puladas, 4 falhas pré-existentes | ✅ |
| F1 layout configurável | nfe-api | `a1e4f99` | 3 novos (PL_010 NF-e, NFC-e, PL_009 inalterado) | ✅ |
| F2 contrato `ibs_cbs` | nfe-api | `eb84bfb` | 7 novos (formato, bloco vazio, campos obrigatórios) | ✅ |
| F3 builder monta o grupo | nfe-api | `cc2a587` | 5 novos (XSD, vNF inalterado, soma no IBSCBSTot, recusa em PL_009) | ✅ |
| F4 documentação | nfe-api | `1299a50` | suíte completa | ✅ |
| F5 repasse na nota avulsa | gestaofacil-api | `5823931` | 4 novos; suíte com as 7 falhas da baseline | ✅ |
| F6 tela da nota avulsa | gestaofacil-fe | `ce0f2ed` | `type-check` + build; checagem das regras puras com esbuild (11 casos) | ✅ (visual pendente) |
| F7 fechamento | os três | — | ver seção 6 | ✅ |

Resultado final das suítes (14–15/10/2026):
- **nfe-api:** 372 passam, 23 puladas, 4 falhas. As 4 são as da baseline (CertificateExpiration, CircuitBreakerRecovery,
  NaturezaOperacaoCrud, NfePolling). Nenhuma nova.
- **gestaofacil-api:** 623 passam, 1 pulada, 7 falhas. As 7 são as da baseline: ClienteTest (2),
  NaturezaOperacaoTest (1), NfeEmissaoTest "prevent double emit" (1) e NfeEmissaoTest modelo 55/65 (3). Nenhuma nova.
- **gestaofacil-fe:** `tsc --noEmit` sem erro e build de produção ok.

**Atenção sobre a branch do nfe-api:** `feat/reforma-pl010` nasceu de `fix/danfe-xml-download` (HEAD em uso), que
tem 9 commits não mergeados em master. O PR dessa branch leva esses 9 junto (decisão D6).

## 4. Revisão do plano (brechas) e o que mudou na execução

1. **Troca de layout é global** (`NFE_SCHEMES`). Mitigado: padrão PL_009_V4; teste garante saída idêntica.
   Troca por emitente continua D3.
2. **`Tools::availableVersions` só tem 4.00.** *Resolvido na leitura do código:* a sped-nfe usa o `schemes` da
   config quando ele vem preenchido (`Common/Tools.php:316`); o mapa é só o padrão. O envio à SEFAZ em PL_010
   continua sem teste real (D5).
3. **Obrigatoriedade por regra de negócio:** não implementada, de propósito (D7).
4. **Bug provável na lib** (`vCBS` vs `gCBS_vCBS`): a execução mostrou que o `IBSCBSTot` da lib **soma certo**
   (teste de dois itens: vBCIBSCBS 150, vIBS 0,15, vCBS 1,35). O problema aparece no `vItem` (ver item 5).
5. **Descoberta nova: a lib decide `vItem`/`vNFTot` pelo ano do servidor.** `TraitCalculations::calculateTtensValues2`
   só soma IBS/CBS/IS no `vItem` quando `date('Y') > 2026`. Hoje (2026), `vItem` = valor do item sem IBS/CBS e
   `vNFTot` = `vNF`. Em 2027 o comportamento muda sozinho, sem deploy. Isso pode estar certo ou não: depende da
   regra da nota técnica para 2026 e 2027. **Decisão D8, obrigatória antes da homologação.**
6. **Cache do XML gerado**: nota com IBS/CBS já emitida não muda; o reenvio segue o fluxo atual (CLAUDE.md, "Regras
   que costumam morder"). Sem mudança aqui.
7. **Mesmo item, duas telas:** o bloco vale só para a nota avulsa. Venda e pedido não têm o campo (fica para quando
   D2 for decidida).
8. **Teste de tela:** não há teste automático de front no repo (CLAUDE.md do fe). Conferência visual em 360/390/768/1280
   px continua manual, com Firefox.
9. **Dependência do `errosDoPayload` e `ibsCbsValido`** foi para `tests/Pest.php`, para funcionar com o arquivo de
   teste rodado sozinho (achado na execução, não no plano).

## 5. Decisões pendentes (não implementadas)

- **D1 — Cálculo de IBS/CBS:** hoje o usuário digita base, alíquotas e valores. A tela pode calcular como sugestão,
  ou a API pode calcular. Escolha sua.
- **D2 — Onde guardar `cClassTrib`:** campo no cadastro de produto (migração em `produtos`) ou só na linha da nota.
- **D3 — Layout por emitente/ambiente:** `NFE_SCHEMES` é global. Pode virar campo do cadastro do certificado.
- **D5 — Envio à SEFAZ em PL_010:** precisa de certificado de homologação e de confirmar a versão de WS aceita por UF.
- **D6 — Base do branch `nfe-api`:** manter em `fix/danfe-xml-download` (como está) ou abrir PR contra `master`
  só com os commits desta feature (exige rebase).
- **D7 — Obrigatoriedade e regras por CST/operação** (quando IBS/CBS vira obrigatório). Fora do escopo.
- **D8 — `vItem` e `vNFTot` por ano** (item 5 acima). Confirmar na nota técnica o que vale em 2026 e em 2027, e se
  a lib precisa de ajuste ou de override. Não é só de código: é regra.
- **D9 — Campos de Venda e Pedido:** o bloco só existe na nota avulsa. Estender para a emissão por venda é decisão de produto.

## 6. Fechamento (F7)

- [x] Suítes dos três projetos rodadas no estado final (resultados na seção 3).
- [x] Cada fase revisada, testada e commitada.
- [x] `PROGRESS.md` atualizado (seção "Reforma tributária").
- [ ] Conferência visual da nota avulsa (360/390/768/1280 px) — manual.
- [ ] Homologação real com a SEFAZ (D5 e D8).
- [ ] Decisões D1, D2, D3, D6, D7, D8, D9 com você.

## 7. Limites do que foi verificado

- Validação contra o XSD PL_010_V1.30 da sped-nfe 5.2.8 (não contra o XSD oficial publicado pela SEFAZ).
- Nenhuma nota enviada à SEFAZ; `NFE_SEFAZ_GATEWAY=fake` em todos os testes.
- Regras de negócio das notas técnicas (obrigatoriedade, cálculo, totais por ano) não foram conferidas no texto oficial
  deste ambiente.

## 8. Evolução (atualizada em 15/10/2026)

| Item | Situação |
|---|---|
| F0–F6 (código, testes, commits) | ✅ concluído nas três branches |
| Push das branches `feat/reforma-pl010` | ✅ feito nos três repositórios (`origin`) |
| Pull requests em draft | ⏸ **não abertos**: `gh` não instalado e sem token no ambiente |
| Publicação de `feat/importacao-xml` (base do gestaofacil-api e gestaofacil-fe) | ⚠ não estava no remoto; o push de `feat/reforma-pl010` levou também os commits dela. Decisão pendente (D10) |
| Conferência visual da nota avulsa | ⏸ manual |
| Homologação SEFAZ | ⏸ depende de D5 e D8 |

Onde fica cada documento: o plano e o `PROGRESS.md` ficam **na raiz** do diretório de projetos, não dentro
dos repositórios (regra do `gestaofacil-api/CLAUDE.md`: planos vivem fora dos repos). Nada a commitar nessa pasta,
pois ela não é um repositório git.

## 9. Dúvidas para decidir depois

Ordem de prioridade para destravar a homologação:

1. **D8 — `vItem`/`vNFTot` por ano.** A sped-nfe soma IBS/CBS no `vItem` só depois de 2026 (data do servidor).
   Qual é a regra da nota técnica para 2026 e para 2027? Precisamos de override da lib ou de ajuste nosso?
2. **D5 — Homologação real.** Temos certificado de homologação para o CNPJ de teste? Qual UF? Qual versão de WS
   a SEFAZ aceita para PL_010?
3. **D10 — Base dos PRs do gestaofacil.** Publicamos `feat/importacao-xml` (para o PR ficar limpo) ou desfazemos o
   push dessas duas branches até ela ser publicada/mergeada?
4. **D6 — Base do PR do nfe-api.** Abrir contra `fix/danfe-xml-download` (4 commits no diff) ou contra `master`
   (13 commits, com os 9 não mergeados)?
5. **D2 — Onde guardar `cClassTrib`.** No produto (migração) ou só na nota? Isso decide se a tela de venda e
   pedido também recebe o bloco (D9).
6. **D1 — Cálculo de IBS/CBS.** O usuário digita tudo, a tela sugere valores, ou a API calcula?
7. **D3 — Layout por emitente.** `NFE_SCHEMES` continua global ou vira campo do cadastro do certificado?
8. **D7 — Obrigatoriedade por CST/operação.** Quando IBS/CBS deixa de ser opcional em cada caso?
9. **D9 — Venda e pedido.** Estender o bloco para a emissão por venda agora ou depois da nota avulsa validada?

Para pegar o fio depois: começar por 1 e 2 (são regra e ambiente, não código).
