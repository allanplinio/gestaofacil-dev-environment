# PLAN-MDFE.md — Emitir MDF-e (modelo 58) pelo GestãoFácil

**Status:** PLANO, nada implementado (2026-11-01). Reescrito em 2026-11-01 depois de ler os documentos
oficiais que o Allan baixou em `docs/mdf-e/` (§12 lista o que foi lido e o que **falta**). Também foi
levantado contra o código das três bases e contra a tela de exemplo (`IMG_4159.jpeg`, emissor legado).
**Nada foi executado contra a SEFAZ nem contra o `sped-mdfe`.** O que ainda não está provado fica em §9.

**Documentos relacionados:** [`PLAN-DISTDFE.md`](./PLAN-DISTDFE.md) (molde: gateway + telas) ·
[`PLAN-API.md`](./PLAN-API.md) · [`DATA-MODEL.md`](./DATA-MODEL.md) · [`PLAN-REFORMA-PL010.md`](./PLAN-REFORMA-PL010.md)

**Convenção de citação:** `[VG §x]` = `MOC_MDFe_VisaoGeral_v3.00b.pdf`; `[A1 Fnn]` = regra de validação
`Fnn` do `MOC_MDFe_Anexo I_Leiaute e Regras Validação_v3.00b.pdf`; `[NT 2025.001]`, `[NT 2026.001]`,
`[NT CJ CNPJ]` = as NTs da mesma pasta. Número solto de 3 dígitos é o `cStat` de rejeição.

---

## 1. O que o MDF-e é, e o que isso muda para o sistema

MDF-e (modelo 58) é o manifesto do **transporte**: veículo, condutor, percurso e os documentos fiscais que
estão na carga. **Não substitui a NF-e**; acompanha a viagem. O ciclo de vida:

```
rascunho → transmitir → AUTORIZADO ──→ ENCERRADO (110112)           fim normal
                            ├────────→ CANCELADO (110111)           só até 24h [VG §6.1.1 K04, 220]
                            ├─ evento: incluir condutor (110114)    só rodoviário, até 99 [VG §6.3]
                            ├─ evento: incluir DF-e (110115)        só se indCarregaPosterior=1 [VG §6.4, 708]
                            └─ eventos de pagamento (110116/110118) só quando há terceiro (§4)
```

**Duas consequências que desenham o produto:**

1. **O MDF-e fica aberto até alguém encerrar, e o aberto bloqueia a próxima emissão.** [VG §2.1.8]:
   *"Enquanto houver MDFe pendente de encerramento, regras de validação poderão impedir a emissão de novos."*
   As rejeições de bloqueio, todas obrigatórias [A1 F85–F88]:
   - **611** já existe aberto para a mesma placa + tipo de emitente + UF de descarga;
   - **662** aberto na mesma placa no sentido oposto (carga/descarga invertidas);
   - **462** aberto há mais de **5 dias** na placa, com até 2 UF de percurso;
   - **686** qualquer aberto há mais de **30 dias** para o emitente;
   - **610** (placa, UF carga e descarga com data de emissão diferente) [VG §8.3].
2. **Não se pode "corrigir" um MDF-e andando.** Mudou veículo, carga ou documento no meio da viagem → **encerra e
   emite outro** [VG §2.1.8]. Só condutor (e DF-e, no carregamento posterior) têm evento de inclusão.

**Armadilha oficial a evitar** [VG §8.3]: o MOC descreve a prática de sistemas que só encerram o manifesto
*quando recebem* a rejeição de bloqueio (a rejeição devolve a chave e o protocolo do culpado). O ambiente
autorizador **pune**: mais de 5 dessas rejeições (462/610/611/686) em 1 hora e o complemento com chave/protocolo
passa a ser **suprimido por 1 hora**. Logo **não vamos "encerrar automaticamente ao rejeitar"**. O sistema
**consulta os não encerrados antes de emitir** (serviço oficial, §5.1) e mostra o aviso ao usuário.

---

## 2. O que já existe (verificado no código)

| Peça | Onde | Serve para |
|---|---|---|
| Padrão de gateway SEFAZ | `nfe-api/app/Services/Sefaz/SefazGatewayInterface.php`, `RealSefazGateway.php`, `FakeSefazGateway.php` | molde: interface + real + fake, `SefazContext`, circuit breaker, `SefazUnavailableException` |
| Fila assíncrona + retry | `nfe-api/app/Jobs/ProcessNfeJob.php` (`tries=0`, `backoff=30`), `ProcessCancelamentoJob`, `ProcessCartaCorrecaoJob` | molde dos jobs de emissão e de evento |
| Filas no Horizon | `nfe-api/config/horizon.php` (`supervisor-1`, `supervisor-nfce`) | **toda fila nova entra no `horizon.php`** (aviso no `ProcessNfeJob`) |
| Certificado A1 por CNPJ | `ClientCertificate`, `SefazContext::fromCertificate` | mesmo A1 assina o MDF-e |
| Emitente guardado | `client_certificates.emitente` (JSON: razão social, endereço, UF) | alimenta `emit`/`enderEmit` [A1 leiaute 29–45]. **Não tem RNTRC nem IE conferida para MDF-e** |
| Numeração | `NfeNumbering`, `POST /numeracao` | `modelo` já é coluna; **58 = valor novo** (constraint não conferida) |
| Webhook de status | `WebhookDispatcher`, `SendWebhookJob`, `POST /webhooks/nfe-emissao` (gestaofacil-api) | molde do retorno assíncrono |
| Reconciliação | `ReconciliarEmissoesPendentes` (a cada 5 min, `gestaofacil_scheduler`) | pega MDF-e que perdeu o webhook |
| Cliente da API | `gestaofacil-api/app/Services/NfeApiClient.php` | ganha os métodos `mdfe*` |
| DAMDFE (PDF) | `nfe-api/vendor/nfephp-org/sped-da/src/MDFe/Damdfe.php`, `Daevento.php` | já instalado |
| CNPJ alfanumérico | `Support\Cnpj`, `SchemasCnpjAlfa.php` | regras já resolvidas; ver §3 sobre o MDF-e |
| Autorização por área | `RequireArea` / `RequirePerfil` (`fiscal`, `notas`) | MDF-e: emitir em `notas`, cadastros em `fiscal` |
| Telas-molde | `NotasFiscais.tsx`, `NotaForm.tsx`, `InutilizacaoModal.tsx`, `NfeModais.tsx` | listagem, formulário longo, modais de evento |
| Origem dos documentos | `nfe_emissoes` (gestaofacil-api) com `chave_nfe`, `status` | **lista as NF-e da empresa para vincular ao manifesto** |

**Não existe (verificado):** nenhum código de MDF-e nas três bases; `sped-mdfe` não instalado;
nenhum cadastro de veículo/condutor/proprietário/RNTRC; `nfe_events` é `foreignUuid('nfe_id')` preso a `nfes`
(lição do PLAN-DISTDFE §2: **MDF-e precisa de tabelas próprias**); o `NfeXmlBuilder` é só NF-e/NFC-e.

---

## 3. A biblioteca e os schemas

`nfephp-org/sped-mdfe`. Segundo a busca web (2026-11-01, **não instalado, não testado**): última release
**V4.2.0 de 2025-05-08**; README manda `composer require nfephp-org/sped-mdfe:dev-master`; aparece como
layout 3.00; um **fork** de um dos donos do nfephp-org avisa que "não deve ser usado além de testes" (aviso do fork,
não do oficial).

**Por que isso preocupa, agora com as NTs na mão:** a V4.2.0 é de **maio/2025** e as NTs que mexem no schema são
**posteriores**: [NT 2025.001 v1.03] (ago/2025: `tpComp=04 Frete`, `tpValePed` só 01 e 04, `tpCarga=12 Granel
pressurizada`, `CIOT` opcional, regex de CNPJ/chave alfanumérica, `cStat` com 4 dígitos) e [NT 2026.001] (CIOT
obrigatório, produção **23/11/2026**). **A lib pode estar defasada.** Para ser conferido na Fase 0, não presumido.

**CNPJ alfanumérico — o que os documentos dizem** (e que o plano anterior deixava em aberto):
- [NT CJ CNPJ v1.00] (ENCAT, inclui MDF-e): **homologação 06/04/2026, produção 06/07/2026**. Primeiros CNPJ alfa
  previstos para jul/2026. Hoje (nov/2026) o ambiente já deve aceitar.
- [NT 2025.001 §4]: schema do MDF-e passa a aceitar `[A-Z0-9]{12}[0-9]{2}` (CNPJ) e `[0-9]{6}[A-Z0-9]{12}[0-9]{26}`
  (chave) em **todos** os campos de CNPJ e de chave, mas *"até que seja publicada NT … as letras não devem ser
  utilizadas"* — a NT Conjunta é essa NT. `cStat` passa a `[0-9]{3,4}`; o QR Code segue a mesma regra.
- Consequência: não é preciso um `SchemasCnpjAlfa` próprio **se o XSD do pacote for o recente** (NT 2025.001 v1.04).
  A Fase 0 confirma qual XSD a lib traz.

> **Regra do projeto (memória "Status Claims Must Be Verified"):** nada desta seção vira fato até a Fase 0 instalar
> o pacote, gerar XML, validar no XSD e autorizar na homologação.

---

## 4. Escopo: o que o documento oficial decide

### 4.1 Tipo de emitente decide quase tudo — e define o nosso caso

`tpEmit` [A1 F14–F17, leiaute 7]: **1** prestador de serviço de transporte · **2** transportador de **carga
própria** · **3** transportador que emitirá **CT-e globalizado**.

| Regra | Efeito |
|---|---|
| **F14** (638) | tpEmit=1 **não pode** ter grupo de **NF-e**; só CT-e |
| **F15** (639) | tpEmit=2 **não pode** ter **CT-e**; só NF-e |
| **F16/F17** (540/541) | tpEmit=3 sem CT-e e só intraestadual |

**Conclusão: documentos de NF-e ⇒ `tpEmit=2` (carga própria).** É o caso natural para um ERP de comércio que entrega
a própria mercadoria. **Transportadora de verdade (tpEmit=1 ou 3) exige CT-e**, que é outro documento (outra lib,
outro plano) e **fica fora**. Logo **o escopo é carga própria, NF-e** (§10 pergunta 3 pede a confirmação).

### 4.2 Proprietário diferente do emitente: o aviso da sua foto é o gatilho de tudo

Na foto: *"Preencher … apenas se o proprietário do veículo for DIFERENTE do emitente"*. No XML isso é `veicTracao/prop`, e o MOC
liga uma cadeia de obrigações **a partir dele**:

- **F18–F20** (743/744/745): informou `prop` com **CPF** ⇒ `tpTransp` obrigatório = **TAC (2)**; com **CNPJ** ⇒ **ETC (1)** ou
  **CTC (3)**; **sem `prop` ⇒ `tpTransp` não pode existir**.
- Com `tpTransp` informado, o emitente `tpEmit=2` passa a ser tratado como os tipos 1/3 em várias regras:
  - **CIOT** obrigatório (684) — **[NT 2026.001], homologação 21/09/2026, produção 23/11/2026** (3 semanas);
  - **pagamento do frete** `infPag` (302), **dados bancários** `infBanc` e CIOT para TAC/equiparado (303/304) [NT 2025.001 §2];
  - **NCM do produto predominante** (301) quando há um só DF-e [NT 2025.001 §2];
  - validações de componentes (`Σ vComp = vContrato`, 746), parcelas, adiantamento, contratante [A1 F52–F65].
- **Sem `prop`** (veículo do próprio emitente): nenhuma dessas obrigações entra.

**Decisão estrutural do plano — duas camadas:**

| Camada | Cobre | Entra em |
|---|---|---|
| **A. Carga própria, veículo da empresa** | `tpEmit=2`, sem `prop`, sem `tpTransp`, NF-e, rodoviário. Sem CIOT/pagamento/seguro | **v1** (Fases 1–6) |
| **B. Com terceiro (TAC/ETC/CTC)** | `prop` + `tpTransp`, **CIOT**, `infPag`, `infBanc`, `infContratante`, vale-pedágio, eventos 110116/110118 | **v1.1** (Fase 8), só se houver demanda |

A foto (campos de proprietário, CPF/CNPJ, RNTRC, IE, "Info. Pagamento") é de um emissor que faz **A e B**. O formulário
**já nasce com o bloco do proprietário opcional e recolhido** (aviso, não trava), mas na v1 ele só deixa **TAC sem CIOT** se a Fase 0
provar que passa; do contrário o bloco fica desligado até a camada B. Quem gera o CIOT não consta nos documentos lidos
(o MOC só tem o campo `infCIOT`) — **a camada B depende de resolver isso** (§10, pergunta 4).

### 4.3 Carregamento posterior (útil para entrega do dia a dia)

[VG §2.1.9, A1 F21–F27]: emitir **antes** de ter as notas, e incluir as NF-e depois por evento (110115). Restrições: só **carga
própria**, **operação interna na UF** (704), **um** município de carga e **um** de descarga, **iguais** (703), só rodoviário
(705), sem documentos no XML (706), e **a inclusão de DF-e tem de ocorrer em até 168 h** (707). Não encerra sem ao menos um DF-e
incluído (715). Cancelar depois de incluir DF-e de outro município de carga é proibido (710). **Entra na camada A como
opção** (é o fluxo "saí com o caminhão, as notas saem durante a rota"), mas é **Fase 2/5, não a primeira emissão**.

### 4.4 Fora do escopo (confirmado)

- Modais aéreo, aquaviário, ferroviário; CT-e e emissão por tpEmit 1/3; MDF-e de MDF-e (`infMDFeTransp`);
  contingência offline (prazo de envio 168 h [VG §11]); importação de MDF-e de terceiros;
  **Provedor de Assinatura e Autorização (PAA)** — [NT 2022.002 v1.02] é para quem delega a assinatura (MEI/pessoa física);
  o nosso emitente assina com **A1 próprio**, então **não se aplica** (confirmado: o texto diz que o contribuinte "poderá" usar PAA).

### 4.5 Sistema multiempresa: cada empresa (CNPJ) com a sua configuração

O GestãoFácil é **multiempresa**: uma mesma instalação serve muitas empresas, cada uma com seus dados isolados (`empresa_id` + `CompanyScope`). Não sabemos de antemão quais delas transportam carga, então o MDF-e é um recurso que **cada empresa liga e configura** para si. O desenho parte do princípio:
**o formulário mostra só o que a empresa usa, e pré-preenche o que ela repete a cada viagem.** Nada disso é regra fiscal; é conforto.

| O que varia | Exemplos | Como o sistema trata |
|---|---|---|
| Usa MDF-e ou não | loja de balcão nunca emite | **flag `habilitado`**; desligada, o menu **Transporte** e as rotas nem aparecem (mesmo molde do "habilitar" do DistDFe) |
| Veículo | 1 caminhão fixo, frota, ou nenhum próprio | cadastro de veículos; **se só existe 1 ativo, já vem selecionado** |
| Condutor | sempre o mesmo ou rodízio | cadastro; condutor padrão opcional |
| Terceiro (agregado, TAC, ETC) | comum no transporte, raro no varejo | **flag `usa_terceiros`**: só ela liga o bloco do proprietário e, depois, CIOT/pagamento (camada B). Desligada, o bloco **nem existe** na tela, o que evita o erro do aviso da sua foto |
| Emite antes de ter as notas | entrega com saída do dia | **flag `usa_carregamento_posterior`** (§4.3) |
| O que carrega | confecção, ferragens, alimentos | tipo de carga e produto predominante **padrão** da empresa |
| Interestadual ou só dentro da UF | | só afeta validação; **não é configuração** (vem do percurso) |

**Configuração por empresa (proposta, a aprovar — §10 pergunta 2).** Uma linha por empresa, `CompanyScope`, em tabela própria `configuracoes_mdfe` no gestaofacil-api:

| Campo | Tipo | Efeito |
|---|---|---|
| `habilitado` | bool | libera o recurso |
| `usa_terceiros` | bool | mostra o bloco de proprietário (camada B) |
| `usa_carregamento_posterior` | bool | libera a opção no formulário |
| `rntrc` | string(8), opc. | vai em `infANTT/RNTRC`; só a empresa que tem |
| `veiculo_padrao_id`, `condutor_padrao_id` | fk, opc. | pré-seleção |
| `tp_carga_padrao`, `produto_padrao_desc`, `produto_padrao_ncm`, `produto_padrao_gtin` | opc. | pré-preenche `prodPred` |
| `aut_xml_padrao` | CNPJ/CPF, opc. (até 10) | pré-preenche `autXML` (ex.: o contador baixa o XML) |
| `inf_complementar_padrao` | texto, opc. | pré-preenche `infAdic/infCpl` |
| `dias_alerta_aberto` | int, padrão 3 | aviso interno **antes** dos limites oficiais de 5 e 30 dias (que **não** são configuráveis) |

**Regra de uso, a mesma do PLAN-IMPOSTOS (decisão nº 4):** a configuração **só pré-preenche o formulário**; a emissão lê **o que o formulário enviou**,
nunca a configuração. Assim, mudar o padrão não altera nenhum MDF-e antigo nem rascunho, e o usuário **sempre vê** o que vai para a SEFAZ. Tudo opcional;
campo vazio na configuração = campo vazio no formulário.

**O que já existe e não precisa de campo novo:** IE, endereço completo e **código IBGE do município** do emitente já estão em `client_certificates.emitente`
(nfe-api), preenchidos na tela **Empresa** (`Empresa.tsx` tem `codigo_municipio`). UF e município de **carregamento padrão = o endereço do emitente**.
O que é novo de fato: `rntrc` e a tabela de configuração.

**O que o multiempresa exige (e como o plano já cobre ou passa a cobrir):**

| Ponto | Tratamento |
|---|---|
| Isolamento de dados | `veiculos`, `condutores`, `configuracoes_mdfe`, `mdfe_emissoes` e `mdfe_documentos` com `empresa_id` + `CompanyScope`; **teste de acesso entre empresas em cada um** (padrão do PLAN-PAGAMENTO-NFCE). Na nfe-api, `mdfes` filtra por `client_id` como `nfes` |
| Certificado, ambiente, série | já são **por CNPJ** (`ClientCertificate`, `nfe_numbering`: cnpj + série + modelo + ambiente). MDF-e usa `modelo='58'`, uma numeração por empresa |
| Bloqueios da SEFAZ (611, 662, 462, 686) e a cota de 5 rejeições/hora | são **por CNPJ/placa do emitente**: o problema de uma empresa **não** vaza para outra |
| Habilitação na SEFAZ da UF (cStat 203) | **por empresa**; vira item do checklist de onboarding de quem liga o recurso |
| Varreduras agendadas (aviso de MDF-e em aberto) | percorrem **só as empresas com `habilitado`**, uma consulta por CNPJ, com intervalo entre elas (a SEFAZ limita consultas) |
| Fila | MDF-e é volume baixo; vai na fila `default` do Horizon; se um dia pesar, ganha fila própria como a `nfce` |
| Liberação comercial | `habilitado` é da **empresa**. Se o MDF-e virar item de plano (a tabela `planos` tem coluna `features`, ainda sem uso que eu tenha achado), a flag passa a depender do plano. **Não decidido; fica para o PLAN-LANCAMENTO** |
| Filiais | cada **CNPJ** é uma empresa/emitente; MDF-e de matriz e de filial são manifestos de emitentes distintos. **Não verifiquei** como o sistema trata matriz e filial hoje |

**Não é genérico e fica fora (reavaliar com o primeiro cliente real):** camada B (terceiro com CIOT/pagamento), CT-e, outros modais (§4.4).

**Peso da carga:** `tot/qCarga` é obrigatório e **o sistema não guarda peso em nenhum lugar** (nenhum `peso` em models ou migrations do gestaofacil-api). Logo o
**peso bruto é digitado no manifesto**, sempre; o valor da carga (`vCarga`) e a contagem de NF-e (`qNFe`) são calculados das notas escolhidas. Se um dia
houver peso por produto, ele só vira sugestão.

---

## 5. Arquitetura proposta

| Camada | Responsabilidade |
|---|---|
| **nfe-api** | monta/valida/assina o XML, SEFAZ, eventos, **consulta de não encerrados**, DAMDFE, numeração modelo 58, webhook |
| **gestaofacil-api** | cadastros (veículo, condutor, proprietário), rascunho, validação de negócio, escolha das NF-e, alerta de em aberto, permissão por empresa |
| **gestaofacil-fe** | cadastros, formulário, painel de em aberto, eventos |

### 5.1 nfe-api

```
app/Models/Mdfe.php, MdfeEvent.php                 (tabelas mdfes, mdfe_events)
app/Services/Mdfe/MdfeXmlBuilder.php               (array → XML, espelho do NfeXmlBuilder)
app/Services/Sefaz/MdfeGatewayInterface.php        (separada da SefazGatewayInterface)
app/Services/Sefaz/RealMdfeGateway.php, FakeMdfeGateway.php
app/Jobs/ProcessMdfeJob.php, ProcessMdfeEventoJob.php, GenerateDamdfeJob.php
app/Http/Controllers/Api/V1/Mdfe*Controller.php
```

```
POST /mdfe                              emitir (202 + protocolo_id)
GET  /mdfe/{protocoloId}                status
GET  /mdfe/{protocoloId}/xml            procMDFe
GET  /mdfe/{protocoloId}/damdfe         PDF
POST /mdfe/{protocoloId}/encerrar       evento 110112 (cUF, cMun, dtEnc)
POST /mdfe/{protocoloId}/cancelar       evento 110111 (≤ 24 h)
POST /mdfe/{protocoloId}/condutor       evento 110114
POST /mdfe/{protocoloId}/dfe            evento 110115 (só indCarregaPosterior)
GET  /certificados/{cnpj}/mdfe/nao-encerrados   serviço "Consulta MDFe não encerrados" [VG §4.4]
```

O serviço de **não encerrados** devolve `cStat 111` (com a lista de chaves e protocolos) ou `112` (nenhum) [VG §4.4]; só o CNPJ/CPF do
próprio emitente consulta. A **consulta de situação** é limitada a **180 dias** da emissão [VG §4.3].

### 5.2 Tabelas (nfe-api)

- `mdfes`: `protocolo_id`, `id_externo` (único por client), `serie` (1–3 dígitos), `numero` (1–9 dígitos), `chave_acesso` (44), `ambiente`,
  `status` (`queued|processing|authorized|rejected|encerrado|cancelado`), `tp_emit`, `uf_ini`, `uf_fim`, `payload`, `xml_assinado`,
  `xml_autorizado`, `protocolo_sefaz`, `motivo_rejeicao`, `autorizado_em` (base do prazo de 24 h), `encerrado_em`.
- `mdfe_events`: `tipo` (`encerramento|cancelamento|condutor|dfe|pagamento`), `sequencia` (até **99** em condutor e DF-e; **1** em cancelamento/encerramento),
  `payload`, `status`, `protocolo`, `xml`, `mensagem_sefaz` (criar a coluna desde o início, como aprendemos em `add_mensagem_sefaz_to_nfe_events`).
- Numeração: `nfe_numbering` com `modelo='58'`.

### 5.3 gestaofacil-api

Tabelas com `empresa_id` + `CompanyScope`:
- `veiculos` — placa (regex `[A-Z]{3}[0-9][0-9A-Z][0-9]{2}` [A1 F89]), UF de licenciamento, RENAVAM (9–11), tara (1–6 dígitos), `capKG`, `capM3`, `tpRod`, `tpCar`,
  `cInt`, e se é **tração** ou **reboque** (até **3** reboques). Reboque exige `capKG`; tração não. `ativo`.
- `condutores` — nome (2–60) e CPF válido. Um MDF-e aceita de **1 a 10**.
- `proprietarios_veiculo` — só camada B (§4.2).
- `mdfe_emissoes` + `mdfe_documentos` (NF-e por município de descarga).
- `configuracoes_mdfe` (§4.5): uma linha por empresa; só pré-preenche o formulário.
- Dados do emitente (IE, endereço, `cMun` IBGE) **já existem** em `client_certificates.emitente` e são enviados no payload de cada MDF-e; **RNTRC** vem da `configuracoes_mdfe` e também vai no payload.

Serviços: `MdfeEmissaoService`, `MdfeReconciliador`, `MdfeAbertosService` (consulta oficial de não encerrados + aviso com os limites 5 e 30 dias).

### 5.4 gestaofacil-fe

```
/transporte/mdfe              listagem + painel "em aberto" (alerta 5 dias / 30 dias)
/transporte/mdfe/novo         formulário em abas
/transporte/mdfe/:id          detalhe, eventos, XML/DAMDFE
/transporte/veiculos | condutores | proprietarios
```

Formulário (nome das abas livre; **não copiar a foto**), com campos do leiaute [A1 leiaute 14–70, 124–148]:

| Aba | Conteúdo | XML |
|---|---|---|
| **Viagem** | UF e município(s) de carga (1–50), percurso (0–25 UF, ordem origem→destino [F90]), início previsto, tipo de carga, CEPs/coordenadas se lotação | `ide`, `infMunCarrega`, `infPercurso`, `prodPred`, `infLotacao` |
| **Veículo** | combo de veículo cadastrado (tração) + até 3 reboques + 1–10 condutores | `veicTracao`, `veicReboque`, `condutor` |
| **Documentos** | por município de descarga, **escolher NF-e da empresa** (lista de `nfe_emissoes` autorizadas); chave avulsa como exceção | `infMunDescarga/infNFe` |
| **Totais/Outros** | peso bruto, valor da carga, unidade (KG/TON), lacres, autorizados a baixar o XML (≤ 10), info. adicional | `tot`, `lacres`, `autXML`, `infAdic` |
| **Terceiro/Pagamento** (camada B) | proprietário, TAC/ETC, CIOT, contratante, pagamento, vale-pedágio | `prop`, `infCIOT`, `infContratante`, `infPag`, `valePed` |

`tot/qNFe` e `vCarga` são calculados das NF-e escolhidas; **`qCarga` (peso bruto) é digitado**, porque o sistema não guarda peso (§4.5).

**Lições de UX da foto:** veículo é cadastro reutilizável (combo com editar/criar); bloco do proprietário só quando diferente do emitente — **avisa, não trava**
(memória `feedback_avisar_nao_travar`); **Salvar** (rascunho) e **Transmitir** são ações separadas.

---

## 6. Fases (cada uma: revisar → testar → commitar → atualizar PROGRESS antes da próxima)

### Fase 0 — Prova de viabilidade (antes de qualquer tela)
Muita coisa que era "a confirmar" já está fechada por documento (§12). O que **só código prova**:
- 0.1 `composer require nfephp-org/sped-mdfe`; anotar versão resolvida, layout (3.00?), extensões PHP exigidas.
- 0.2 **Qual XSD a lib traz**: tem `tpComp=04`, `tpCarga=12`, regex alfa de CNPJ/chave, `cStat` de 4 dígitos, `CIOT` opcional? Se está **antes** da NT 2025.001 v1.04, decidir: atualizar o XSD (baixar o pacote oficial) ou descartar a lib.
- 0.3 Gerar um MDF-e **mínimo** (`tpEmit=2`, rodoviário, sem `prop`, 1 NF-e, 1 condutor), assinar e validar no XSD, **com CNPJ numérico e depois alfa**.
- 0.4 **Autorizar 1 MDF-e na homologação (PE)**, depois **encerrar**; outro, **cancelar**. Registrar o `cStat` real de cada passo.
- 0.5 Testar a **consulta de não encerrados** (`111/112`) e provocar `611` (placa repetida) para ver a mensagem real.
- 0.6 Se a camada B vai entrar: testar `prop` TAC e ver qual `cStat` aparece **sem** CIOT (esperado 684 só a partir de 23/11/2026 em produção; em **homologação já desde 21/09/2026**).
- **Saída:** seção "Resultados da Fase 0" aqui, e decisão sobre usar a lib.

### Fase 1 — nfe-api: emitir e consultar (camada A)
Migrations, models, `MdfeXmlBuilder`, gateway (interface + Fake + Real), `ProcessMdfeJob`, `POST /mdfe`, status, XML, webhook, numeração 58, **não encerrados**.
Testes no padrão `tests/Feature/SefazIntegration` (SEFAZ roteirizada) + Fake. Validação própria **antes** de enviar para as regras do §7.

### Fase 2 — nfe-api: eventos e DAMDFE
Encerrar (UF + município + data), cancelar (≤ 24 h), incluir condutor, incluir DF-e (carregamento posterior), `GenerateDamdfeJob` (+ DAEVENTO); testes dos estados inválidos
(609 já encerrado, 218 já cancelado, 220 passou de 24 h, 219 circulação registrada, 715 encerrar posterior sem DF-e).

### Fase 3 — gestaofacil-api: cadastros
Veículos, condutores; CRUD com `CompanyScope`; **teste de acesso entre empresas**; excluir só se nunca usado, senão inativar.

### Fase 4 — gestaofacil-api: emissão
`mdfe_emissoes`, `MdfeEmissaoService`, endpoints, webhook, reconciliador, `MdfeAbertosService`; validação de negócio; **comando agendado que avisa MDF-e aberto**, nunca que encerra sozinho (§1).

### Fase 5 — gestaofacil-fe
Cadastros, formulário, lista com painel de em aberto, modais de evento, XML/DAMDFE. **Conferência visual no Firefox é do Allan.**

### Fase 6 — E2E e gateway real
`gestaofacil-e2e`: cadastro → rascunho → transmitir (Fake) → encerrar. **MDF-e só em homologação** nos testes (o dev roda SEFAZ real, memória `reference_cce_e_gateway_real`).

### Fase 7 — Segurança e produção
Atualizar `PLAN-SEGURANCA.md`: isolamento por empresa dos cadastros, rate limit, **CPF de condutor/proprietário** (LGPD, sem log do payload cru). Primeiro MDF-e **real** com o Allan acompanhando; confirmar antes que a **empresa está habilitada para emitir MDF-e na SEFAZ da UF** (rejeição **203** *"Emissor não habilitado"* [VG §6]).

### Fase 8 — Camada B (só se confirmada a demanda)
`prop`/`tpTransp`, **CIOT**, `infPag`, `infBanc`, `infContratante`, vale-pedágio (`tpValePed` só 01 ou 04), eventos 110116/110118. Depende da pergunta 4 do §10.

---

## 7. Validações próprias (antes de ir à SEFAZ, em **uma** classe, no molde de `RegrasFiscais`)

Evitam rejeição e protegem a cota de 5 rejeições/hora [VG §8.3]. Cada uma cita a regra:

- `tpEmit=2` ⇒ só NF-e (639); `tpEmit=2` sem `prop` ⇒ sem `tpTransp` (745); com `prop` CPF ⇒ TAC (743), CNPJ ⇒ ETC/CTC (744).
- Placa no formato nacional `[A-Z]{3}[0-9][0-9A-Z][0-9]{2}` quando a viagem não é para o exterior (646).
- Percurso em ordem origem→destino (663). Município coerente com a UF: 2 primeiros dígitos do IBGE = UF (456, 612, 614).
- Carregamento posterior: um município de carga = descarga, mesma UF, interna (703, 704); inclusão em 168 h (707).
- Soma dos componentes = valor do contrato (746) — camada B.
- **Antes de transmitir**: consultar não encerrados; se houver bloqueio provável (mesma placa, mais de 5 dias, mais de 30 dias), **avisar**, não enviar.
- Cancelar: bloquear no cliente quando `autorizado_em` passou de 24 h (220); a SEFAZ pode liberar por evento do Fisco (`240170`), que **não temos como pedir**.

---

## 8. Riscos

| Risco | Prob. | Mitigação |
|---|---|---|
| `sped-mdfe` defasado (V4.2.0 é de mai/2025; NTs de ago/2025 e 2026 mudam schema/regras) | **alta** | Fase 0.2; plano B = atualizar XSD do pacote oficial ou montar o XML nós mesmos como fazemos na NF-e |
| **CIOT obrigatório em produção em 23/11/2026** para o caso com terceiro | certa para camada B | camada B fora da v1; formulário bloqueia `prop` sem CIOT em produção |
| Bloqueio por MDF-e aberto (462/611/662/686) | alta | consulta de não encerrados antes de emitir; painel de em aberto; **nunca** encerrar por rejeição |
| Cancelamento só até 24 h | média | aviso no botão com horas restantes; sem opção "libera prazo" |
| Empresa não habilitada para MDF-e na UF (203) | média | checklist de onboarding; erro traduzido |
| Sem cliente que use (nicho) | alta | pergunta 1; parar na Fase 0 se não houver |
| CPF de condutor/proprietário (LGPD) | média | só o exigido; sem log do payload cru |
| Dev usa SEFAZ real | certa | MDF-e só em homologação nos testes |

---

## 9. O que NÃO está provado

- Nada rodou: nem a lib, nem a SEFAZ. Os `cStat` acima vêm do MOC/NTs, não de execução.
- **O leiaute/regras vêm do MOC 3.00b de ago/2022** e das NTs lidas; as alterações de **NT 2024.001 e NT 2024.002** (listadas no portal) e o **XSD do pacote** (NT 2025.001 v1.04, 25/04/2026) **não foram lidos** (§12).
- Não li o **Anexo II (DAMDFE)** (`.docx`); a geração de PDF vem do `sped-da`, não testada.
- Constraint de `nfe_numbering.modelo` aceitando `58`: não conferido.
- Regras de bloqueio (462/611/…): lidas, **não reproduzidas** na homologação.
- A busca web anterior trazia uma suposta obrigatoriedade de MDF-e "a partir de **03/08/2026**" (Ato Conjunto RFB/CGIBS nº 4/2026): fonte secundária, **não confirmada nos documentos oficiais lidos** — descartada; conferir no `PLAN-REFORMA-PL010.md` se há layout novo com IBS/CBS.

---

## 10. Decisões que preciso do Allan

Lista refeita em 2026-11-01 com o princípio de sistema genérico (§4.5). O que a configuração por empresa resolve **saiu da lista**:
menu visível só para quem habilita, terceiro e carregamento posterior como opções ligáveis, onde guardar IE/município (já existem), e a interface do gateway
(decisão técnica minha, abaixo). Sobraram **quatro** decisões.

1. **Quando começar, e a Fase 0 já?** MDF-e só serve às empresas da plataforma que transportam carga, e hoje o foco comercial é comércio/moda (PLAN-LANCAMENTO). Como o sistema é multiempresa, ele pode esperar um cliente que precise. Vale a Fase 0 (prova barata, sem tela) agora, ou o MDF-e entra
   na fila depois de outra prioridade (PLAN-LANCAMENTO)? A Fase 0 sozinha **não cria campo, tela ou migration**: só instala a lib e emite na homologação.
2. **Aprova a tabela `configuracoes_mdfe` (§4.5)?** Ela cria campos novos (memória: perguntar antes). Responder: **aprovar como está**, **cortar campos** (diga quais) ou
   **começar só com `habilitado`, `rntrc` e padrões de veículo/condutor** e acrescentar o resto quando alguém pedir. *Minha recomendação: a 3ª opção.*
3. **Transportadora (CT-e) está fora?** Com NF-e só vale carga própria (§4.1). Empresa que **transporta para os outros** emite CT-e, que é outro documento e outro plano.
   Confirmando "fora", o produto serve a quem entrega **a própria mercadoria**.
4. **Camada B (terceiro com CIOT/pagamento) fica adiada até o primeiro cliente pedir?** Se sim, hoje só a flag `usa_terceiros` existe como futuro e o bloco não é construído.
   Quando o primeiro cliente aparecer, a pergunta **"quem gera o CIOT?"** vira obrigatória, porque os documentos lidos só descrevem o campo `infCIOT`.
   *Observação:* com o CIOT obrigatório em produção em **23/11/2026**, a camada B não deve entrar às pressas.

**Assumido por mim, a menos que você diga o contrário** (decisões técnicas, sem efeito visível):
- Gateway em **interface separada** `MdfeGatewayInterface` (a `SefazGatewayInterface` já tem 9 métodos de NF-e e o MDF-e usa outros webservices e outra lib).
- Carregamento posterior só a partir da **Fase 2/5**, atrás da flag, e não na primeira emissão.
- **Peso bruto digitado** a cada manifesto (§4.5).
- **Nunca** encerrar manifesto por reação à rejeição de bloqueio (§1).

---

## 11. Andamento e registro de execução

Branch `feature/mdfe` em `nfe-api`, `gestaofacil-api`, `gestaofacil-fe`, `gestaofacil-e2e` e `gestaofacil-dev-environment` (criadas em 2026-11-01).
**Portão de cada fase:** revisar → rodar os testes → commitar → marcar aqui e no `PROGRESS.md` → só então a próxima.

**Decisões aplicadas (as recomendadas, 2026-11-01, por pedido do Allan):** começar já; `configuracoes_mdfe` **mínima** (`habilitado`, `rntrc`, veículo e condutor padrão);
CT-e fora; camada B (terceiro/CIOT) adiada; gateway em interface separada; peso bruto digitado; nunca encerrar por rejeição. **Carregamento posterior:** na v1 só o **evento
110115 no backend** (nfe-api e gestaofacil-api); sem opção na tela e sem flag, porque a configuração mínima não a inclui.

- [x] **Fase 0 — prova de viabilidade** (concluída; o 0.4 foi feito no fim da Fase 2)
  - [x] 0.1 `composer require nfephp-org/sped-mdfe` → **V4.2.0** (a única dependência nova; `sped-common` já satisfazia). Layout **3.00**, schemas `PL_MDFe_300a` de **08/05/2025**
  - [x] 0.2 O XSD do pacote é **anterior à NT 2025.001**: CNPJ `[0-9]{14}`, chave `[0-9]{44}`, `Id` `MDFe[0-9]{44}`, `cStat` `[0-9]{3}`. Rejeita CNPJ alfanumérico (provado em teste)
  - [x] 0.3 MDF-e mínimo (`tpEmit=2`, rodoviário, sem `prop`, 1 NF-e, 1 condutor, **sem** `prodPred`) **monta, assina (certificado de teste) e valida** no XSD, com QR Code. Teste:
        `tests/Feature/Mdfe/ViabilidadeDaBibliotecaTest.php`. Com CNPJ alfa e um pacote derivado (mesma técnica do `SchemasCnpjAlfa`) os padrões de CNPJ e `Id` deixam de reclamar; **a validação completa com assinatura fica para a Fase 1**
  - [x] A biblioteca tem os serviços de **cancelar, encerrar, incluir condutor, incluir DF-e, consultar não encerrados, consultar situação, status e DistDFe** (`Tools.php`)
  - [x] 0.4 **Homologação (SVRS, empresa de PE, 05/11/2026)**: ver a Fase 2 abaixo
  - Lacuna aberta: o pacote derivado para CNPJ alfa é gerado do XSD do vendor (maio/2025), **não do pacote oficial** NT 2025.001 v1.04, que ainda falta baixar (§12)
  - Suíte da nfe-api: 568 passam, **3 falham, e as 3 já falhavam antes** (conferido desfazendo as mudanças): `CertificateExpirationTest` (limiares de 30/15/7 dias),
    `NaturezaOperacaoCrudTest` (isolamento entre clientes) e `NfePollingTest` (comparação de uuid). Qualquer falha além dessas é regressão do MDF-e
- [x] **Fase 1** — nfe-api: emitir e consultar (02/11/2026)
  - [x] Migration `mdfes` + `mdfe_logs`; models `Mdfe`/`MdfeLog`; numeração série 58 (`POST /numeracao` aceita `modelo: "58"`)
  - [x] `StoreMdfeRequest` (limites do Anexo I do MOC), `MdfeXmlBuilder`, `MdfeGatewayInterface` + `RealMdfeGateway` + `FakeMdfeGateway`, `ProcessMdfeJob`, webhook (`documento: "mdfe"`)
  - [x] Rotas: `POST /mdfe`, `GET /mdfe/{id}`, `GET /mdfe/{id}/xml`, `GET /certificados/{cnpj}/mdfe/nao-encerrados`
  - [x] CNPJ alfanumérico: pacote derivado do XSD do `sped-mdfe` (`SchemasCnpjAlfa`), testado de ponta a ponta com a SEFAZ roteirizada
  - [x] **Achado:** o `sped-mdfe` 4.2.0 arranca as letras da chave no QR Code (`preg_replace('/[^0-9]/')`); o builder entrega o `infMDFeSupl` pronto
  - [x] **Achado:** o circuito da NF-e liga a contingência SVC da NF-e ao abrir; o MDF-e ganhou `MdfeCircuitBreaker` próprio
  - [x] Testes: 63 novos em `tests/Feature/Mdfe`; suíte da nfe-api 631 passam, **as mesmas 3 falhas de antes**
  - **Não verificado:** nenhuma chamada à SEFAZ (o formato do retorno síncrono é suposição do MOC); certificado de teste, não real
- [x] **Fase 2** — nfe-api: eventos e DAMDFE (02–05/11/2026), com a homologação (0.4)
  - [x] Migration `mdfe_events` (índice único **parcial**: recusado não consome a sequência), `MdfeEvent`, `ProcessMdfeEventoJob`
  - [x] `POST /mdfe/{id}/encerrar`, `/cancelar` (≤ 24 h), `/condutor` (≤ 99); `GET /mdfe/{id}/eventos/{evento}/xml`; bloco `eventos` no status e no webhook
  - [x] Gateway real: encerra/cancela/inclui condutor com a SEFAZ roteirizada, evento assinado e validado no XSD, inclusive com CNPJ alfanumérico
  - [x] DAMDFE e DAEVENTO em PDF (síncronos, como o DACCE). **Achado:** o `Damdfe` do sped-da quebra sem `emit/IE`; o gerador imprime `ISENTO` na cópia
  - [x] **Achado:** `UFList::getCodeByUF` lança exceção com UF inexistente (daria 500); o request valida a UF antes
  - [x] **Decisão:** evento 110115 (inclusão de DF-e) **fora da v1**: sem carregamento posterior seria código inalcançável (PLAN §4.3 e decisão da v1)
  - [x] **Decisão:** `GenerateDamdfeJob` do plano virou geração síncrona (o XML já existe; mesmo desenho do DACCE)
  - [x] Testes: 110 em `tests/Feature/Mdfe`; suíte da nfe-api 677 passam, **as mesmas 3 falhas de antes**
  - [x] **0.4 Homologação real (05/11/2026, SVRS, CNPJ 11500611000115, tpAmb=2)**, com autorização do Allan, pelo mesmo caminho do código (`ProcessMdfeJob` + `RealMdfeGateway`):
    consulta de não encerrados **112**; MDF-e nº 2 **autorizado (100)** e **encerrado (135)**; MDF-e nº 3 **autorizado (100)**, **condutor incluído (135)** e **cancelado (135)**; consulta de situação **132** (encerrado) e **101** (cancelado);
    DAMDFE e DAEVENTO gerados dos XMLs reais (conferido o DAMDFE a olho). Serviço: `mdfe-homologacao.svrs.rs.gov.br`, envio **síncrono**, resposta `retMDFe` + `protMDFe` (idêntica ao que a SEFAZ roteirizada simula)
  - [x] **Achado da homologação:** o 1º envio (cavalo mecânico sem reboque) foi **recusado com 523**; o request passou a exigir reboque para `tipo_rodado=03`. O MDF-e nº 1 ficou `rejected` no banco de dev
  - [x] Dev: 3 manifestos (nº 1 rejeitado, 2 encerrado, 3 cancelado) e 5 eventos ficaram em `mdfes`/`mdfe_events` do banco de **dev** da nfe-api (homologação; sem efeito fiscal)
  - **Limitação conhecida:** o `lockForUpdate` do controller de eventos só é provado pelo índice parcial e por testes sequenciais; não há teste de concorrência real
- [x] **Fase 3** — gestaofacil-api: cadastros (05/11/2026)
  - [x] Migration `veiculos` (única por placa/empresa), `condutores` (único por CPF/empresa), `configuracoes_mdfe` (uma por empresa); models com `CompanyScope`; `Support\Cpf`, `Support\DominiosDoTransporte`
  - [x] `GET/PUT /transporte/configuracao`; CRUD `/transporte/veiculos` e `/transporte/condutores`; `RequireMdfeHabilitado` (403 `mdfe_desabilitado` quando a empresa não ligou o recurso)
  - [x] **Decisão (a confirmar com o Allan):** veículos e condutores ficam na área `notas` (quem emite cadastra na hora, como o "+" da tela de exemplo); só a configuração (ligar, RNTRC, padrões) é `fiscal`. O plano dizia "cadastros em fiscal"
  - [x] Excluir veículo/condutor apaga (e limpa o padrão); **a Fase 4 passa a recusar** quando um manifesto apontar para o cadastro
  - [x] Testes: 30 em `tests/Feature/Transporte` (isolamento entre empresas, perfis, gate de habilitação, unicidade, validações). Suíte da gestaofacil-api: 1369 passam; **as mesmas 7 falhas de antes** (conferido desfazendo as mudanças)
- [x] **Fase 4** — gestaofacil-api: emissão (05/11/2026)
  - [x] Migration `mdfe_emissoes`, `MdfeEmissao`, `NfeApiClient::mdfe*` (sem `nfe_requests`: o payload leva CPF de condutor), `MdfeEmissaoService` (rascunho, transmitir, reconciliar, eventos, status), `MdfeAbertosService`
  - [x] Rotas `/transporte/mdfe`: CRUD do rascunho, `transmitir`, `encerrar`, `cancelar` (≤ 24 h), `condutor`, `xml`, `damdfe`, arquivos do evento, `abertos`; webhook com `documento: "mdfe"`; `mdfe:reconciliar-pendentes` a cada 5 min
  - [x] **Bloqueios 611/662/462/686 conferidos antes de enviar** (409 `mdfe_bloqueado` com o manifesto a encerrar); a SEFAZ é a verdade, o que ela não lista mais sai de "aberto"; sem encerramento automático
  - [x] Valor da carga somado das NF-e (venda ou avulsa); NF-e só autorizadas, modelo 55 e da empresa; cadastros inativos recusados ao transmitir
  - [x] **Decisão:** o alerta de MDF-e em aberto é a tela/endpoint `abertos` (situação `ok`/`atencao` a partir de 3 dias/`bloqueando`), não um comando agendado de aviso: não há canal de notificação hoje, e `dias_alerta_aberto` saiu da configuração mínima
  - [x] Veículo/condutor com histórico não se excluem (409); rascunho não segura
  - [x] Testes: 66 em `tests/Feature/Transporte/MdfeEmissaoTest.php` (isolamento entre empresas, perfis, bloqueios, idempotência, webhook, eventos, arquivos). Suíte da gestaofacil-api: 1465 passam; **as mesmas 7 falhas de antes**
  - **Não verificado:** a emissão ponta a ponta entre as duas APIs (só com o nfe-api simulado); a numeração da série 58 não tem tela ("continuar a partir de X" para quem migra de outro sistema); sem teste de concorrência real da transmissão (o `lockForUpdate` e o 409 do segundo clique só têm teste sequencial)
- [x] **Fase 5** — gestaofacil-fe (05/11/2026): **código pronto, tela não conferida no navegador**
  - [x] Tipos, API (`transporteApi`), `useTransporteStore` e `RequireTransporte`: o grupo **Transporte** do menu e as telas só existem para quem ligou o MDF-e
  - [x] `/config-transporte` (ligar, RNTRC, veículo e condutor padrão), `/transporte/veiculos`, `/transporte/condutores`
  - [x] `/transporte/mdfe`: lista com filtros e painel **Em aberto** (ordem do mais urgente, aviso de bloqueio, abertos que só a SEFAZ conhece); `/novo` e `/:id/editar` (viagem, veículo e condutores, notas por município de entrega, carga); `/:id` (acompanha a cada 5 s, encerrar, cancelar ≤ 24 h, incluir condutor, DAMDFE e XML, eventos)
  - [x] 409 `mdfe_bloqueado` aparece com o link do manifesto a encerrar; 422 por campo; cavalo mecânico sem reboque barrado na tela (523)
  - [x] `npm run verificar:transporte` (regras puras) passa; `make test-fe` (tsc + build) passa
  - [ ] **Conferência visual no Firefox: é do Allan.** Nenhuma tela foi aberta
  - **Pendências:** a numeração da série 58 não tem tela; o formulário não tem rascunho automático (salva só pelo botão)
- [x] **Fase 6** — E2E (05/11/2026)
  - [x] `tests/e2e/fiscal/transporte-mdfe.spec.ts` (gateway **fake**, só com `E2E_GATEWAY_FAKE=1 make test-e2e-fiscal`): **9 passam**. Tela → gestaofacil-api → nfe-api (fila, worker, XML e XSD) → webhook de volta: emite pela tela e encerra; bloqueio **611** com link do manifesto aberto e liberação ao encerrar; rejeição `[E2E-REJEITA:611]` → "Corrigir e transmitir" sai com outro número; cancelar; incluir condutor; XML e DAMDFE; painel "Em aberto"; NF-e que não vale é recusada antes do nfe-api
  - [x] `tests/e2e/transporte-cadastros.spec.ts` (chromium e firefox, **não emite nada**): 8 testes × 2 navegadores = **16 passam**: menu só aparece depois de ligar, veículos e condutores pela tela, placa/CPF inválidos, unicidade por empresa (e a empresa B), vendedor/operador/admin, 401
  - [x] A guarda do E2E (`test-base.ts`) passou a **barrar** transmitir, encerrar, cancelar e incluir condutor do MDF-e em qualquer projeto que não seja o `fiscal`
  - [x] Suíte E2E normal completa: **283 passam, 13 pulados, 2 falham** (`senha.spec.ts` 077 e 003, só chromium; **já falhavam antes** e não têm relação com o MDF-e)
  - [x] **Achados que só o E2E mostrou:** (1) o fake de "não encerrados" devolvia sempre vazio e os bloqueios nunca disparavam (agora reflete os autorizados da empresa); (2) um diretório de `storage/app` ficou de **root** por causa da minha homologação manual e o worker "autorizava" sem gravar o XML, porque `Storage::put` devolve `false` em vez de lançar: os jobs do MDF-e agora lançam; (3) o `checkAuth` do front apaga o token em **qualquer** erro, inclusive requisição abortada por navegação no Firefox (o teste agora espera o menu carregar; o app **não** foi mudado)
- [x] **Fase 7** — segurança e produção (05/11/2026): registro em `PLAN-SEGURANCA.md` ("05/11/2026: MDF-e"), com o que está provado e o que não está
  - [ ] **Primeiro MDF-e em produção: não feito.** Pede o Allan acompanhando e a empresa habilitada para MDF-e na SEFAZ da UF (rejeição 203)
- [x] **Duplicar manifesto (05/11/2026, pedido do Allan depois da Fase 7)**: `POST /transporte/mdfe/{id}/duplicar` e botão **Duplicar** na tabela e no detalhe. Gera rascunho com a viagem igual e **as NF-e e o valor da carga em branco** (o município de entrega fica, sem as notas); nada vai à SEFAZ.
  - [x] Testes: 10 novos na gestaofacil-api (qualquer status, sem NF-e nem valor, original intacto e nada enviado ao nfe-api, outra empresa 404, vendedor 403, MDF-e desligado 403, 401); 2 no E2E fiscal (pela tabela, completando a cópia e transmitindo; pelo detalhe de um encerrado). Suíte da gestaofacil-api 1475 passam (**as mesmas 7 falhas de antes**); E2E fiscal do MDF-e **11 passam**
  - **Decidi manter na cópia** `inicio_viagem` e os lacres (só zerei o que é da NF-e, como pedido): a tela avisa para conferir antes de transmitir. Se preferir limpar também, é uma linha no `MdfeEmissaoService::duplicar`
- [x] **Tabela e detalhe com valor da carga e produto predominante (05/11/2026)**: colunas novas na lista de manifestos e as duas linhas no detalhe. O valor é calculado pela API (sem coluna nova): o enviado, o digitado ou a soma das NF-e. Textos de ajuda nos campos **Lacres** e **Quem pode consultar o manifesto (autXML)**, que estavam confusos. Testes: 4 na API (suíte 1478 passam, as mesmas 7 falhas antigas) e 1 no E2E fiscal (12 passam)
- [x] **Rejeitado continua rejeitado ao ser editado (06/11/2026, pedido do Allan)**: antes, salvar a correção de um manifesto rejeitado o devolvia a rascunho e apagava o número, o código e o motivo (o Allan perdeu o erro 663 que estava corrigindo). Agora só a **transmissão** muda o status; se o nfe-api recusar o reenvio, volta a rejeitado com o erro de antes. Testes: 5 novos na API (suíte 1483 passam, as mesmas 7 falhas) e o E2E de corrigir e transmitir cobre salvar sem perder o erro (12 passam)
  - **Não feito (não confirmado pelo Allan):** barrar na tela e na API um percurso que repete a UF de carregamento ou de descarregamento (a causa do 663 dele)
  - O manifesto nº 1 do banco de dev do Allan já tinha sido salvo pela regra antiga: está como rascunho, sem o erro. Não foi alterado
- [x] **Só rascunho se exclui (06/11/2026, a pedido do Allan)**: o rejeitado deixou de poder ser excluído (era regra minha, sem auditoria e deixava o nfe-api com um registro órfão): fica no histórico e se corrige, retransmite ou duplica. A exclusão do rascunho agora vai para a auditoria (`mdfe.excluido`). Testes: 2 novos na API (suíte 1485 passam, as mesmas 7 falhas) e 1 no E2E (13 passam). **Não feito:** "arquivar" para esconder rejeitados antigos (só se a lista encher)
- [ ] **Fase 8** — camada B (adiada, sem previsão)

---

## 12. Fontes lidas e lacunas (`docs/mdf-e/`)

| Arquivo | Lido | O que usei |
|---|---|---|
| `MOC_MDFe_VisaoGeral_v3.00b.pdf` | **sim**, seções de encerramento, eventos, cancelamento, condutor, DF-e, consulta, uso indevido | §1, §4.3, §5.1, §7 |
| `MOC_MDFe_Anexo I_Leiaute e Regras Validação_v3.00b.pdf` | **sim**, leiaute completo e regras F01–F112 (tipo de emitente, carregamento posterior, rodoviário, bloqueios) | §4, §5.3–5.4, §7 |
| `MDFe_Nota_Tecnica_2025_001_1.03.pdf` | **sim** | §3, §4.2 |
| `MDFe_Nota_Tecnica_2026_001.pdf` | **sim** (CIOT, prod. 23/11/2026) | §4.2, §8 |
| `DFe NTCJ 2025.001_CNPJ Alfa_v1.00.pdf` | **parcial** (cronograma e escopo; **não** li as regras de DV e código de barras) | §3 |
| `MDFe_Nota_Tecnica_2022_02_PAA_v1.02.pdf` (+ `-1.pdf`, **idêntico, é duplicata**) | **sim** (PAA) | §4.4 |
| `MOC_MDFe_Anexo II - DAMDFE_v3.00b.docx` | **não** | — |

**Falta baixar** (não está na pasta; o portal lista):
1. **Pacote de schemas XSD** — "NT 2025.001 v1.04 (25/04/2026)" — **o mais importante**: sem ele não dá para conferir a lib na Fase 0.2.
2. **NT 2024.001 v1.02** e **NT 2024.002 v1.01** (não sei o que alteram; podem mudar regras do rodoviário).
3. (opcional) **NT 2023.001** e **NT 2020.001 (MDF-e Integrado)**.
