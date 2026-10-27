# PLAN-DISTDFE.md — Buscar e manifestar notas de entrada direto na SEFAZ

**Status:** **CONCLUÍDO em 2026-10-20 — Fases 1 a 6 implementadas, testadas e enviadas ao remoto (ver §14 e §14.6).** O que resta **não é código**, está em §14.7: conferência visual no Firefox (do Allan), perguntas ao contador, primeiro teste real com CNPJ alfanumérico e a virada do dev para produção. *(Histórico: v1 documentado e parado em 2026-10-02; as seções §0–§13 abaixo são o plano original e a §12 já foi cumprida.)* Levantado contra o código das três bases e contra a NT 2014.002.

**Documentos relacionados:** [`PLAN-IMPORTACAO-XML.md`](./PLAN-IMPORTACAO-XML.md) (§11 registra
esta feature como "próximo passo natural") · [`PLAN-API.md`](./PLAN-API.md) · [`DATA-MODEL.md`](./DATA-MODEL.md)

> **Pré-requisito:** a §13 do `PLAN-IMPORTACAO-XML.md` deve estar fechada antes da Fase 3 deste
> plano. Este plano **alimenta** o `ImportacaoNotaService` com XML de outra origem; se a conferência
> ainda tem lacunas, elas serão herdadas e multiplicadas (agora as notas chegam sozinhas).

---

## 1. O que este plano resolve

Hoje a nota de entrada só existe se **alguém pedir o XML ao fornecedor** e subir o arquivo
(`ImportarNotaEntrada.tsx` → `POST /notas-entrada/importar`). Isso é o atrito real: o fornecedor
manda o PDF da DANFE e não o XML, manda por WhatsApp, ou não manda.

A SEFAZ já tem todas essas notas. O webservice `NFeDistribuicaoDFe` entrega ao destinatário
**todos os documentos emitidos contra o CNPJ dele**, sem precisar de número, chave ou do
fornecedor. O que este plano constrói:

1. **Varredura** — a aplicação pergunta à SEFAZ "o que entrou de novo para o meu CNPJ?" e recebe
   a lista.
2. **Manifestação** — o destinatário dá ciência, o que é o que **libera o XML completo**.
3. **Importação** — o XML completo cai no `ImportacaoNotaService` que já existe, e o resto do
   fluxo (de-para, fator, custo, lançamento) não muda nada.

**O que este plano explicitamente NÃO faz:** buscar nota pelo número. Não existe. A chave de toda
consulta é a chave de acesso de 44 dígitos, cujo `cNF` são 8 dígitos **aleatórios escolhidos pelo
emitente** — não há como derivar a chave a partir de CNPJ + série + número + mês. A varredura por
NSU resolve o problema sem precisar da chave.

**O que este plano também NÃO entrega: histórico.** Duas regras da NT (§3.4 e §3.5, v1.10 em diante):

1. Os documentos ficam disponíveis por **até 90 dias** após a recepção pelo Ambiente Nacional. Com
   `ultNSU = 0`, volta no máximo **os últimos 3 meses**.
2. **Cliente novo não tem NSU retroativo.** *"No caso de novos usuários desse serviço (distNSU), a
   geração de NSU ocorrerá a partir do primeiro acesso. Não haverá geração de NSU retroativo."* O
   primeiro acesso devolve `137`, e só depois de 1 hora (§3.4, Obs1) as notas **emitidas daí em diante**
   passam a aparecer. A mesma coisa vale para quem **fica mais de 60 dias sem consultar**: a geração de
   NSU para e retoma na próxima consulta, **sem recuperar o intervalo** (§3.6).

Consequência: uma empresa de 20 anos, ou de 2 meses, **começa do zero** na distribuição, a menos que
outro sistema (contador, ERP) já esteja consultando o CNPJ há menos de 60 dias. Não existe "carga
inicial" do passado. Todo o histórico entra por XML (upload atual e Fase 6). Por isso o **primeiro
acesso deve acontecer cedo** (onboarding, §8 Fase 1.11), para a SEFAZ começar a gerar NSU. Texto para
o cliente: *"o sistema passa a receber automaticamente as notas emitidas a partir da ativação; as
anteriores você importa por arquivo"*.

---

## 2. O que já existe (verificado no código)

| Peça | Onde | Serve para |
|---|---|---|
| `sped-nfe` com distDFe pronto | `nfe-api/vendor/nfephp-org/sped-nfe/src/Tools.php:384` | `sefazDistDFe(int $ultNSU, int $numNSU, ?string $chave, string $fonte = 'AN')` — os três modos (distNSU, consNSU, consChNFe) numa só chamada |
| `sped-nfe` com manifestação pronta | `Tools.php:677` | `sefazManifesta($chave, $tpEvento, $xJust, $nSeqEvento)`; constantes em `Tools.php:35-38` |
| Download por chave | `Tools.php:1258` | `sefazDownload($chave)` — `consChNFe` pronto contra o ambiente nacional; serve ao passo 3 da §7.2 |
| Envio de evento genérico | `nfe-api/app/Services/Sefaz/RealSefazGateway.php:158` (`enviarEvento`) | aceita 135/136/155, devolve `procEventoNFe` via `Complements::toAuthorize` — **reaproveitável inteiro** pela manifestação |
| Certificado por CNPJ | `nfe-api/app/Models/ClientCertificate.php`, `SefazContext::fromCertificate` | distDFe e manifestação exigem o A1 do destinatário, que já está guardado |
| Circuit breaker + tradução de falha | `RealSefazGateway::call()` (`:178`) | mesmo tratamento de timeout/5xx |
| Worker de fila | `gestaofacil-dev-environment/docker-compose.yml:208` (`nfe_worker`, Horizon) | **só na nfe-api** |
| Leitor de XML de terceiro | `gestaofacil-api/app/Services/Compras/LeitorXmlNfe.php:13` | o docblock diz: *"Aceita a raiz `nfeProc` (com protocolo) ou a `NFe` nua"* — **o `procNFe` do distDFe entra sem uma linha de alteração** |
| Pipeline de importação | `ImportacaoNotaService::importar(string $xmlConteudo, User $usuario)` (`:32`) | recebe **string**, não arquivo. O controller só faz `$request->file('xml')->get()` antes (`NotaEntradaController.php:188`) |
| Aviso de destinatário divergente | `ImportacaoNotaService::avisos()` (`:117`) | já compara `dest/CNPJ` com `empresas.cnpj` |
| Telas de entrada | `gestaofacil-fe/src/pages/{NotasEntrada,ImportarNotaEntrada,ConferenciaNotaEntrada}.tsx` | a tela nova entra ao lado, não em cima |

**O que não existe (verificado):**

- `grep -ril "distdfe\|DistribuicaoDFe"` nas três bases → **só o `PLAN-IMPORTACAO-XML.md`**. Zero código.
- `nfe_events` é `foreignUuid('nfe_id')->constrained('nfes')` (migration `...000004:13`) — está preso
  a nota **que nós emitimos**. Manifestação é sobre nota de terceiro, que nunca estará em `nfes`.
  **Precisa de tabela própria** (§5).
- `gestaofacil-api` **não tem worker de fila** (`app/Jobs` vazio; só `nfe_worker`, da outra API, e
  `QUEUE_CONNECTION=redis` sem consumidor), **mas tem scheduler**: o serviço `gestaofacil_scheduler`
  (`docker-compose.yml:153`, `php artisan schedule:work`) já roda `nfe:reconciliar-pendentes` a cada
  5 min (`routes/console.php`). *Correção v1.3 (2026-10-19): a versão anterior dizia que não havia
  scheduler.* Um comando agendado roda síncrono, sem fila — basta para uma varredura diária (D4).

---

## 3. Como o webservice funciona de verdade

Não é "consultar e pronto". Três mecânicas determinam o desenho inteiro.

### 3.1 NSU: a varredura é incremental e tem contador

Cada documento de interesse do CNPJ recebe um **NSU** (número sequencial) no ambiente nacional.
Você guarda o último que leu e pergunta "o que veio depois disso?".

```
sefazDistDFe(ultNSU: 1234)  →  até 50 documentos + <ultNSU> + <maxNSU>
   loop enquanto ultNSU < maxNSU
   parar assim que ultNSU == maxNSU (cStat 138) — sem chamada extra só para ouvir o 137
   cStat 137 "Nenhum documento localizado" também encerra
   ao encerrar (138 com ultNSU == maxNSU, ou 137): liberado_em = agora + 1h
```

A resposta traz cada documento em `<docZip>`, que é **base64 + gzip** (`gzdecode(base64_decode(...))`).
O atributo `schema` diz o que é: `resNFe` (resumo), `procNFe` (XML completo), `resEvento`,
`procEventoNFe`. O `sped-nfe` **não** desempacota isso — não há nenhum `gzdecode` no pacote
(`grep -rn "docZip\|gzdecode" vendor/nfephp-org/sped-nfe/src/` → zero). O desempacotamento é nosso.

**O contador `ultNSU` é estado crítico.** Perdido, você rebaixa tudo e reprocessa; avançado por
engano, você **perde notas em silêncio** — elas nunca mais aparecem na varredura.

### 3.2 Antes de manifestar, só vem o resumo

Esta é a regra que define a UI, e é a NT 2014.002 literalmente: os documentos só ficam disponíveis
se o destinatário se manifestar com *Ciência da Operação*, *Confirmação da Operação* ou *Operação
não Realizada*. **Antes da manifestação, só o resumo da NF-e** (`resNFe`: chave, CNPJ e nome do
emitente, valor total, data, situação) — o suficiente, de propósito, para o destinatário decidir
se manifesta.

**Exceção importante:** o **evento de cancelamento é distribuído mesmo sem manifestação**. Ou seja,
se o fornecedor cancelar uma nota, nós ficamos sabendo — inclusive de nota que já lançamos (§7.3).

Consequência: o fluxo é de dois passos e a tela nova é uma **caixa de entrada**, não um botão de
busca.

```
varredura → resumos pendentes → [usuário manifesta] → varredura → procNFe → ImportacaoNotaService
```

### 3.3 Consumo indevido (656): bloqueio de 1 hora que se renova se você insiste

Este é o maior risco operacional do plano, e é por isso que o controle de intervalo **não pode
ficar na mão do usuário**. Conferido na NT 2014.002 v1.12 e v1.40, §3.11.4 (a tabela abaixo marca o
que é da NT e o que não é):

| Regra | Efeito |
|---|---|
| Até **50 documentos** por requisição *(NT §3.2)* | loop até `ultNSU == maxNSU` ou `cStat 137` |
| Depois do `137` (ou `ultNSU == maxNSU`), nova consulta antes de **1 hora** *(NT §3.5, §3.11.4.1-1)* | `cStat 656` → **CNPJ bloqueado por 1 hora**, desbloqueio automático |
| Consultar **fora de sequência** — não usar o `ultNSU` devolvido na chamada anterior *(NT §3.11.4.1-2)* | `656` ("Deve ser utilizado o ultNSU nas solicitações subsequentes") |
| **Vários sistemas** do mesmo ator consultando o mesmo CNPJ de 14 dígitos *(NT, "Atenção")* | todos devem seguir a mesma sequência ascendente, senão é uso indevido |
| Insistir durante o bloqueio *(NT, Observação)* | o `656` volta e **o relógio de 1 hora reinicia** |
| Consultas `consChNFe`/`consNSU` acima do limite *(NT §3.11.4.2)* | `656` "ultrapassou o limite de **20 consultas por hora**" — **o texto da NT é ambíguo** (por chave/NSU, ou total por hora?). O plano trata como **total por CNPJ** (B7) |
| ~~Acumular **50 bloqueios** → bloqueio permanente~~ | **NÃO está na NT** (v1.12 e v1.40: `grep -i permanent` = 0). Vinha de blog. **Não confirmado**: tratar como hipótese, não como regra |

Um usuário ansioso clicando "buscar notas" dez vezes não é hipótese remota — é o comportamento
padrão. **O cooldown tem que ser servidor-side, persistido, por CNPJ, e barrar a chamada antes de
sair para a SEFAZ.** Ele mora junto do `ultNSU` (§5.1).

Texto-base conferido: `NT2014.002 - v1.12 - WsNFeDistribuicaoDFe.pdf` (na raiz do projeto) e a
[v1.40 de 07/2026](https://www.reformatributaria.com/wp-content/uploads/2026/07/NT2014.002_v1.40-WsNFeDistribuicaoDFe-CNPJ-alfa.pdf)
(cópia de terceiro; o oficial é o Portal Nacional da NF-e).

Fontes: [NT 2014.002 (portal NF-e)](https://www.nfe.fazenda.gov.br/portal/exibirArquivo.aspx?conteudo=BttMW6T7ib8%3D) ·
[NT 2014.002 v1.02c (PDF)](https://inventti.com.br/wp-content/uploads/2020/08/NT2014_002_v1.02c_WsNFeDistribuicaoDFe.pdf) ·
[regras de consumo indevido](https://blog.nstecnologia.com.br/regras-de-consumo-indevido-para-dfe/) ·
[rejeição 656](https://focusnfe.com.br/blog/rejeicao-656/)

### 3.4 Os quatro eventos de manifestação

| Evento | `tpEvento` | Significado | Justificativa |
|---|---|---|---|
| Ciência da Operação | `210210` | "tomei conhecimento de que existe" — **não** declara recebimento | não |
| Confirmação da Operação | `210200` | declara que a operação ocorreu e a mercadoria entrou | não |
| Desconhecimento da Operação | `210220` | "não reconheço esta nota contra mim" | não |
| Operação não Realizada | `210240` | reconheço a nota, mas a operação não se concretizou (devolução, recusa) | **sim** (`Tools.php:689` corta em 255 chars) |

Todos os quatro liberam o XML, menos o Desconhecimento. Ciência é a mais neutra e é a que serve ao
nosso objetivo (destravar o XML para importar). **Mas manifestar tem efeito fiscal e é irreversível**
— Ciência só pode ser registrada uma vez (`nSeqEvento=1`, ver comentário em `Tools.php:36`).

---

### 3.5 Defesa contra bloqueio — requisitos (revisão v1.2)

O bloqueio permanente é o único dano irreversível do plano (§3.3). Os requisitos abaixo (B1–B20) valem para
**toda** chamada à SEFAZ desta feature, e cada um virou item da Fase 1. Os números (1 h, 20 por
chave, 50 bloqueios) são os da NT 2014.002 e das fontes da §3.3 e **devem ser reconferidos** (§12);
os limites internos abaixo são **mais conservadores que os da SEFAZ de propósito**.

| # | Regra | Por quê |
|---|---|---|
| B1 | **Fail closed.** Na dúvida, não chama. Sem linha de estado, estado ilegível ou relógio estranho, a resposta é "tente depois", nunca uma chamada | o custo de não chamar é esperar; o de chamar errado é bloqueio |
| B2 | **Margem no cooldown:** `liberado_em = agora + 1h + 5 min` (configurável) | diferença de relógio entre nós e a SEFAZ; consulta "exatamente na hora" ainda pode dar 656 |
| B3 | **Erro de rede/5xx/timeout também arma cooldown** (curto, com backoff: 5, 15, 60 min). Nunca repetir na hora | a SEFAZ pode ter contado a consulta mesmo sem resposta chegar a nós |
| B4 | **656 não é repetido:** grava `liberado_em` (usa o horário da mensagem se vier, senão `agora + 1h + margem`), incrementa `bloqueios`, responde 429 | insistir durante o bloqueio reinicia o relógio (§3.3) |
| B5 | **Teto por requisição:** no máximo N lotes (ex.: 10 = 500 docs) por clique, com pausa de 1–2 s entre lotes. Se não acabou, o `ultimo_nsu` já confirmado fica salvo e o próximo clique continua (sem 1 h, pois não houve `137`) | evita estourar o timeout HTTP com carga inicial grande e evita rajada |
| B6 | **Orçamento por CNPJ+hora**, em qualquer modo (NSU + chave), configurável e abaixo do limite da SEFAZ. Estourou: 429 local | proteção que não depende de cada rota lembrar da regra |
| B7 | **Consultas pontuais (`consChNFe` + `consNSU`) com contador próprio e orçamento TOTAL por CNPJ/hora**, não por chave: o texto da NT (§3.11.4.2) diz "limite de 20 consultas por hora" e é ambíguo, então assume-se o pior caso. Teto interno ex.: **8 por hora no total**. Tabela `dfe_consultas_chave (cnpj, chave, ultima_consulta, tentativas)` para espaçar a mesma chave; após a ciência, **preferir esperar o XML chegar na próxima varredura** (a NT §3.11.3 passo 6: a manifestação gera um NSU novo com a NF-e) e usar `consChNFe` só como atalho; resultado negativo fica em cache | o usuário clicando "tentar de novo" esgota o limite, e a leitura da NT pode ser a mais restritiva |
| B8 | **Trava global (kill switch)** por CNPJ *(a NT só prevê bloqueio de 1 h com desbloqueio automático; o "permanente" não está nela — mantido como cautela barata)*: `bloqueios >= 3` (conservador; era 5 na Fase 5) desliga a feature para o CNPJ, grita no log/alerta e só volta por ação administrativa | segundo a NT o bloqueio é de 1 h e se renova com insistência; parar cedo evita a renovação em cadeia. O limite "permanente de 50" é de fonte não oficial |
| B9 | **Egress compartilhado:** a NT fala em bloqueio **do CNPJ**, não de IP; o plano antigo citava "CNPJ/IP" (fonte de blog). Mesmo assim a `nfe-api` sai por um IP só: manter limite global de consultas de distribuição por minuto entre CNPJs e jitter (Fase 5) como cautela barata. **Não confirmado** que haja bloqueio por IP | custo baixo, benefício possível |
| B10 | **Estado fora do banco descartável:** o cooldown também é espelhado no Redis (TTL) e verificado junto com o banco. Banco de dev/e2e recriado (overlay do `gestaofacil-e2e`) não pode zerar `liberado_em` e liberar chamada imediata | o dev roda gateway SEFAZ real (memória do projeto) |
| B11 | **Gateway real da distribuição desligado por padrão fora de produção:** `DFE_REAL_HABILITADO=false`; liga-se à mão para a única varredura supervisionada da D7. **Nunca** usar o certificado real de um cliente em dev/CI além dessa varredura | dev e produção não compartilham estado local, mas compartilham a cota do mesmo CNPJ na SEFAZ |
| B12 | **Auditoria de toda chamada:** tabela `dfe_chamadas (cnpj, ambiente, modo, nsu_inicio, cstat, duracao_ms, origem, created_at)` | diagnosticar de onde veio um 656 e provar o que foi enviado |
| B13 | **Cliente:** botão desabilitado durante a requisição e durante o cooldown; a trava real é do servidor (idempotência), não do botão | duplo clique, duas abas, retry automático do HTTP client |
| B14 | **Retry do HTTP client desligado** nas chamadas de distribuição (nfe-api → SEFAZ e gestaofacil-api → nfe-api) | retry automático é uma consulta a mais que ninguém pediu |
| B15 | **Outros sistemas consultando o mesmo CNPJ** (ERP, sistema do contador): a **NT confirma** (§3.11.4.1, "Atenção") que várias aplicações do mesmo ator, no mesmo CNPJ de 14 dígitos, "devem seguir a mesma sequência de numeração ordenada e ascendente", senão é uso indevido. Cada sistema guarda seu próprio `ultNSU`, então dois sistemas sem coordenação se enquadram nisso. O cooldown local não enxerga o consumo deles. Mitigação: (a) **perguntar ao cliente antes de ligar** se contador/ERP já consultam o CNPJ e registrar a resposta; (b) se consultam, **não ligar a nossa varredura** até acordar com o contador (ou o contador para); (c) um `656` na **primeira** chamada vira mensagem própria na tela ("outro sistema está consultando este CNPJ"), vale o cooldown de B4 e **conta** em `bloqueios`; (d) Fase 5 desligada para esse CNPJ | podemos ser bloqueados sem ter feito nada errado, e bloquear o contador do cliente |
| B16 | **`ultNSU = 0` só na criação da linha de estado**, nunca como recuperação automática. Estado perdido com `dfe_recebidos` existente: o NSU é semeado a partir de `max(nsu)` de `dfe_recebidos` daquele CNPJ e a feature fica pausada até um administrador confirmar. *Alternativa da NT (v1.14, §3.11.4.1):* a rejeição `656` de uma consulta `distNSU` **devolve o último NSU consultado para o CNPJ** — dá para recuperar, mas custa provocar um `656` (1 h de bloqueio), então só como último recurso. Toda chamada manda o `ultNSU` do último lote confirmado | consulta fora de sequência é causa de `656` na NT (§3.11.4.1-2); recomeçar do zero também refaz a carga |
| B17 | **`consNSU` só para recuperar buraco**, nunca para varredura, com contador próprio no mesmo molde do B7 (relatos indicam que é mais suscetível a `656` que `distNSU`). A varredura usa sempre `distNSU` | reduz exposição ao limite de 20/h |
| B18 | **Frequência baixa por padrão:** varredura automática 1×/dia por empresa (D4); o botão manual segue o cooldown. Como cliente novo não tem histórico (NT §3.4), o volume de uma empresa pequena é o das notas desde a ativação — poucos lotes, sem insistência | menos chamadas = menos chance de `656` e menos cota gasta com terceiros (B15) |
| B19 | **Códigos terminais não se repetem.** `217` (NF-e inexistente), `632` (fora do prazo de 90 dias), `640` (sem permissão), `641` (indisponível ao emitente), `653` (cancelada) e `654` (denegada) em `consChNFe` são resposta definitiva: gravar no `dfe_recebidos` e **não tentar de novo**. `589` (NSU maior que o máximo) indica estado corrompido: parar e alertar. `108/109` (serviço paralisado): backoff (B3). `999` (erro não catalogado): tratar como falha com backoff | repetir resposta definitiva só gasta cota |
| B20 | **Uso contínuo (regra dos 60 dias):** se o CNPJ ficar **mais de 60 dias sem `distNSU`**, a SEFAZ para de gerar NSU e **o intervalo é perdido para sempre** (NT §3.4). A feature nunca pode ficar pausada/desligada por mais de ~45 dias sem alerta; o kill switch (B8) e a pausa por B15 geram alerta com prazo | perda silenciosa de notas, sem erro |

### 3.6 O que a NT diz e muda o desenho (conferido em 2026-10-19)

NT 2014.002 **v1.40** (julho/2026) é a vigente; a v1.12 (março/2022) é anterior. Entre elas: v1.13
(eventos do fisco iguais para emitente e destinatário), **v1.14** (a rejeição `656` passa a devolver o
último NSU consultado), **v1.15** (o retorno de NSU vira facultativo e `consChNFe` **deixa de exigir**
NSU previamente gerado), v1.20/1.21 (evento "Ator Interessado"), v1.30 (eventos de "Insucesso da
Entrega") e **v1.40 (campos CNPJ de "N" para "C"** — CNPJ alfanumérico, vigente desde 08/07/2026).

| Ponto da NT | Efeito no plano |
|---|---|
| Disponível por **90 dias** após a recepção; `ultNSU=0` devolve no máximo 3 meses (§3, §3.1) | fecha a pendência "janela": **90 dias** |
| **NSU não é retroativo** para cliente novo; primeiro acesso devolve `137`; parar >60 dias interrompe a geração (§3.4) | não existe carga inicial; onboarding precisa do **primeiro acesso cedo** (1.11); B20 |
| Autentica pelo **CNPJ base** (8 dígitos); um certificado consulta qualquer filial (§3, §3.4.2). NSU é por CNPJ de 14 dígitos (§3.4) | uma linha de estado por CNPJ de 14 dígitos, mesmo certificado; `593` se a base difere |
| Cancelamento é distribuído **sem manifestação**; antes dela só o `resNFe` (nota 1 da tabela, §3) | confirmado (D6, §3.2) |
| A manifestação (exceto desconhecimento) **gera um NSU novo com a NF-e** (§3.11.3, passo 6) | o XML também chega na **próxima varredura**; `consChNFe` é atalho, não obrigação (B7) |
| `consChNFe` retorna só a NF-e, nunca evento (§3.7); só modelo 55 (`618`) | NFC-e fora; evento só pelo `distNSU` |
| `resNFe` traz `tpNF` (0 entrada, 1 saída), `vNF`, `cSitNFe`, `dhEmi`, `IE`, `digVal`, `nProt` (§3.11.1) | `dfe_recebidos` pode guardar `tp_nf` e `ie_emitente`; `tpNF` ajuda a separar devolução de venda |
| Mensagem de entrada ≤ 10 KB (`214`); `cUFAutor` é opcional (0-1) | sem impacto |
| `656` por `distNSU`: "tente após 1 hora" e devolve o último NSU (v1.14) | B4, B16 |
| **CNPJ alfanumérico (v1.40):** campos `CNPJ` viram tipo "C"; a **chave de acesso embute o CNPJ**, então deixa de ser só dígitos | validações do plano e do código (`\d{14}`, `\d{44}`, `char` numérico, máscara no FE) **não podem assumir só números** — conferir `sped-nfe` instalado e as validações da `gestaofacil-api` (Fase 1.12) |

Itens **não encontrados** na NT (v1.12 nem v1.40), portanto não confirmados: bloqueio permanente
após 50 bloqueios; bloqueio por IP; que a homologação "não devolve movimento".

### 3.7 Parâmetros de consumo mínimo (v1.5) — valores padrão, todos em `config/nfe.php` → `distdfe`

O objetivo é gastar o mínimo de cota possível, porque o CNPJ pode ter o contador ou um ERP consultando
a mesma cota (B15). A NT exige só 1 hora; usamos bem mais.

| Parâmetro | Padrão | Com outro sistema (`sim`/`nao_sei`) | Observação |
|---|---|---|---|
| Intervalo mínimo entre varreduras `distNSU` concluídas | **12 h** | **24 h** | vale também para o botão manual; a NT exige 1 h |
| Varredura automática (Fase 5) | 1×/dia | **desligada** | fora do escopo desta entrega |
| Lotes por varredura | máx. **10** (500 docs), pausa **2 s** | igual | o resto continua na varredura seguinte, sem esperar o intervalo |
| Consultas pontuais (`consChNFe` + `consNSU`) | **2 por hora e 6 por dia** por CNPJ | **1 por hora e 3 por dia** | orçamento TOTAL, não por chave (NT ambígua, §3.3) |
| Mesma chave | **1 a cada 30 min**, máx. 3 por dia | igual | resultado negativo em cache |
| Espera após a ciência antes de `consChNFe` | **15 min** | igual | o XML também chega na varredura (NT §3.11.3) |
| Margem sobre o bloqueio de 1 h | **+5 min** | igual | relógio |
| Após `656` | `liberado_em = max(1 h + 5 min, intervalo mínimo)` | igual | e conta em `bloqueios` |
| Kill switch | **3** bloqueios em 7 dias | **2** | desliga o CNPJ até `dfe:reabilitar` |
| Habilitar exige | resposta sobre outro sistema consultando o CNPJ | com `sim`/`nao_sei`: **confirmação explícita de coordenação** | B15 |
| Gateway real fora de produção | desligado (`NFE_DFE_REAL_HABILITADO=false`) | igual | B11 |

Decisões de desenho tomadas na implementação (pequenas, registradas aqui): a sincronização é um
**`POST /dfe/sincronizar`** (tem efeito colateral e gasta cota — o `GET` do plano original era
enganoso); consulta por chave é `POST /dfe/{chave}/consultar` pelo mesmo motivo; o contador de consultas
pontuais usa a própria tabela de auditoria `dfe_chamadas` (sem `dfe_consultas_chave` separada); o
**primeiro acesso** (1.11) acontece no `POST /dfe/habilitar`.

---

## 4. Decisões abertas — **precisam de resposta antes da Fase 1**

### D1 — Onde mora o `ultNSU` e o cooldown?

**Recomendo: na `nfe-api`**, tabela própria por certificado/CNPJ. É estado do diálogo com a SEFAZ,
exatamente como `nfe_numbering` e `sefaz_contingency_states` já são. A `gestaofacil-api` não deve
saber o que é NSU — ela pede "me dá o que há de novo" e recebe documentos.

**Consequência assumida (revisão v1.1): o `ultNSU` não pode avançar só porque a nfe-api devolveu o
lote.** Os documentos são persistidos na `gestaofacil-api` (`dfe_recebidos`); se ela cair depois da
resposta, o NSU já teria avançado e a nota sumiria em silêncio. Por isso a `nfe-api` guarda o lote
bruto num **buffer** (`dfe_documentos`, §5.1b) e o NSU só vira definitivo quando a `gestaofacil-api`
**confirma (ack)** que gravou (§6.1). Sem ack, a próxima chamada devolve o mesmo lote do buffer, sem
ir à SEFAZ. `dfe_recebidos` é idempotente por `(empresa_id, chave)`, então reentregar é seguro.

Alternativa (não recomendada): `ultNSU` na `gestaofacil-api` e a `nfe-api` sem estado. Isso vaza
protocolo SEFAZ para a camada de negócio e, pior, espalha o cooldown do §3.3 por tenant — se duas
empresas compartilham CNPJ-raiz ou se a `gestaofacil-api` for replicada, o limite é furado.

### D2 — Manifestação: manual ou automática?

**Recomendo: manual na v1.** O usuário vê a lista de resumos e clica. Automatizar ciência em massa
na primeira versão significa registrar eventos fiscais no nome do cliente sem ele ter visto a tela
uma vez.

Na v2, um opt-in explícito por empresa ("dar ciência automática em notas de fornecedores já
cadastrados") — com o aviso do que é ciência, no momento de ligar.

### D3 — Qual evento o botão principal usa?

**Recomendo: Ciência (210210) como o botão "Ver itens / liberar XML"**, e os outros três como ações
separadas e secundárias, nomeadas pelo que significam em português, não pelo código. Desconhecimento
e Operação não Realizada não são "liberar XML" — são recusa, e quem clica precisa entender isso.

**A confirmar com o contador do cliente antes de implementar:** se a Confirmação da Operação deve
ser oferecida no mesmo fluxo (há segmentos com manifestação obrigatória — combustíveis, bebidas) e
quais prazos valem para a UF dele. Não vou inventar prazo neste plano: a NT garante a disponibilidade
no ambiente nacional, mas o prazo de manifestação varia por segmento e legislação estadual.

### D4 — Como a varredura roda? (revisado v1.3: diária, via scheduler que já existe)

**Recomendo: Fase 2 com botão manual ("Buscar notas na SEFAZ"), síncrono, protegido pelo cooldown
do §3.3; cron só na Fase 5.** Motivos: zero infra nova para ver a feature funcionando; o cooldown de
1 hora já torna a varredura naturalmente esparsa; e o risco do §3.3 é mais fácil de observar com um
humano no gatilho do que com um cron em cima de um webservice que bloqueia por reincidência.

**Frequência-alvo: uma varredura por dia por empresa** (decisão do usuário em 2026-10-19: o público
são empresas pequenas, com poucas notas; não faz sentido consultar a cada hora). A Fase 5 passa a ser
um **comando agendado** (`dfe:sincronizar`) no `gestaofacil_scheduler` que já existe, rodando em
horário de baixo movimento com jitter entre empresas. **Não precisa de container novo nem de worker de
fila** (a premissa antiga de que não havia scheduler estava errada). O botão manual continua, sempre
atrás do cooldown. Uma vez por dia fica muito abaixo do limite de 1 h da SEFAZ, o que reduz o risco
de bloqueio e o consumo de cota compartilhada (B15).

### D5 — O resumo é uma `nota_entrada` ou entidade própria?

**Recomendo: entidade própria (`dfe_recebidos`).** Um resumo não tem itens, não tem fornecedor
resolvido, não tem o que conferir — enfiá-lo em `notas_entrada` com status novo quebraria o D12 do
`PLAN-IMPORTACAO-XML` (três estados, dois verbos) e contaminaria `NotasEntrada.tsx`, que hoje lista
coisas que têm itens. A `nota_entrada` nasce quando o `procNFe` chega, pelo caminho que já existe.

### D6 — O que fazer com os eventos que chegam na varredura?

A distribuição traz `resEvento`/`procEventoNFe`, inclusive **cancelamento de nota sem manifestação**
(§3.2). Se o fornecedor cancelar uma nota que já lançamos no estoque, nós descobrimos.

**Recomendo: guardar e avisar, nunca reverter sozinho.** Um estorno automático mexeria em estoque
e em preço de compra sem ninguém olhando. O aviso vai no mesmo lugar que os outros (`notas_entrada.avisos`,
jsonb, já existe) e a nota continua estornável à mão. Isso segue a regra de avisar e não travar.

### D7 — Como testar sem queimar o CNPJ de ninguém?

- `FakeSefazGateway` ganha `distribuicaoDFe()` e `manifestar()` com fixtures reais desempacotadas
  (um `resNFe`, um `procNFe`, um `procEventoNFe` de cancelamento), **anonimizadas** — mesmo
  tratamento que a §13.3 do `PLAN-IMPORTACAO-XML` pede para a fixture da nota de compra.
- Teste do cooldown é teste de banco + clock, não de rede: não precisa da SEFAZ.
- No gateway real, **uma** varredura manual por sessão de teste, consciente do §3.3.

---

## 5. Modelo de dados

### 5.1 `nfe-api` — estado da distribuição (D1)

```
distribuicao_estados
  id
  client_certificate_id  → client_certificates (cascade)
  cnpj            char(14)
  environment     smallint          -- 1 produção, 2 homologação: NSU é por ambiente
  ultimo_nsu      bigint default 0
  maior_nsu       bigint default 0  -- maxNSU da última resposta: dá o "quanto falta"
  consultado_em   timestamptz null  -- base do cooldown
  liberado_em     timestamptz null  -- quando pode consultar de novo (137 → +1h; 656 → +1h)
  bloqueios       integer default 0 -- contador de 656; o 50º pode ser bloqueio permanente (§3.3)
  unique (cnpj, environment)
```

**Concorrência:** a checagem de `liberado_em` e a chamada à SEFAZ rodam dentro de uma transação com
`lockForUpdate` na linha de `distribuicao_estados` (ou lock Redis por `cnpj+environment`). Duplo
clique ou duas abas não podem disparar duas varreduras. Renovar/trocar o certificado **não** zera
esta linha: a chave é CNPJ+ambiente, não o certificado (teste na Fase 1).

`liberado_em` é o que o `GET` consulta **antes** de abrir soquete. `bloqueios` existe para a
feature se desligar e gritar antes de chegar perto do limite permanente.

### 5.1b `nfe-api` — buffer do lote (D1, revisão v1.1)

```
dfe_documentos
  id
  cnpj, environment
  nsu            bigint
  schema         varchar        -- resNFe | procNFe | resEvento | procEventoNFe
  chave          char(44) null
  xml            text           -- já desempacotado
  confirmado_em  timestamptz null  -- preenchido pelo ack da gestaofacil-api
  created_at
  unique (cnpj, environment, nsu)
```

`distribuicao_estados.ultimo_nsu` é o maior NSU **confirmado**. Documentos com `confirmado_em` nulo
são reentregues antes de qualquer nova ida à SEFAZ. Confirmados podem ser expurgados após N dias.

### 5.2 `nfe-api` — manifestações

`nfe_events` não serve (está preso a `nfes.id`, §2). Tabela própria:

```
manifestacoes
  id              uuid pk
  cnpj            char(14)          -- quem manifestou (o destinatário)
  chave           char(44)
  tp_evento       integer           -- 210200 | 210210 | 210220 | 210240
  sequencia       integer default 1
  justificativa   text null         -- só 210240
  protocolo       varchar(20) null
  status          varchar(20)       -- registrado | rejeitado
  codigo          varchar(5)        -- cStat
  mensagem        text
  xml_path        text null         -- procEventoNFe
  created_at      timestamptz
  unique (cnpj, chave, tp_evento, sequencia)
```

A unique é o que impede registrar Ciência duas vezes (rejeição 573 na SEFAZ) por duplo clique.

### 5.3 `gestaofacil-api` — caixa de entrada (D5)

```
dfe_recebidos
  id
  empresa_id          → empresas (cascade)
  chave               char(44)
  nsu                 bigint
  emitente_cpf_cnpj   char(14)
  emitente_nome       varchar
  valor_total         decimal(15,2)
  dh_emissao          timestamptz null
  situacao            smallint null   -- cSitNFe do resNFe (1 autorizada, 2 denegada, 3 cancelada)
  manifestacao        varchar(20) null -- null | ciencia | confirmada | desconhecida | nao_realizada
  manifestado_em      timestamptz null
  manifestado_por     → users null
  xml_path            varchar null     -- preenchido quando o procNFe chega
  nota_entrada_id     → notas_entrada null -- vínculo após importar
  status              varchar(20)      -- pendente | manifestado | importado | recusado | ignorado
  created_at / updated_at
  unique (empresa_id, chave)
  index (empresa_id, status)
  index (empresa_id, dh_emissao)   -- filtro por mês e total do mês
```

`unique (empresa_id, chave)` é a idempotência da varredura: reprocessar o mesmo NSU não duplica
nada. Model novo entra no `CompanyScope`, como manda o padrão da base.

---

## 6. Contrato de API

### 6.1 `nfe-api` (novos endpoints, dentro do grupo autenticado de `routes/api.php`)

```
GET  /v1/certificados/{cnpj}/dfe
     → { ultimo_nsu, maior_nsu, pendentes_na_sefaz, liberado_em,
         documentos: [ { nsu, schema, chave, tipo, xml } ] }
     • varre do ultimo_nsu em diante, até 50 por chamada
     • 429 + liberado_em se o cooldown não venceu (§3.3) — não sai para a SEFAZ
     • cStat 137 → 200 com documentos: [] (não é erro)
     • cStat 656 → incrementa bloqueios, grava liberado_em = now+1h, responde 429

POST /v1/certificados/{cnpj}/dfe/confirmar
     { ate_nsu: 1234 }
     → marca `confirmado_em` nos documentos do buffer até esse NSU e avança `ultimo_nsu`
     • chamado pela gestaofacil-api **depois** de gravar `dfe_recebidos`; idempotente
     • sem ele o NSU não avança (D1)

GET  /v1/certificados/{cnpj}/dfe/{chave}
     → o mesmo formato, modo consChNFe (`sefazDownload`) (fornecedor mandou só a chave/DANFE)
     • conta no limite de 20 consultas/chave/hora

POST /v1/certificados/{cnpj}/dfe/{chave}/manifestar
     { tipo: "ciencia"|"confirmacao"|"desconhecimento"|"nao_realizada",
       justificativa?: string }
     → { id, status, codigo, mensagem, protocolo }
     • tipo em português no contrato; o tpEvento numérico não vaza (igual ao padrão
       de `cartaCorrecao`, que recebe campo+valor e não o XML do evento)
```

O `xml` de cada documento vai **já desempacotado** (base64/gzip resolvido). A `gestaofacil-api`
não deve saber que a SEFAZ comprime nada.

### 6.2 `gestaofacil-api`

```
GET  /dfe                        lista a caixa de entrada (filtro: status, fornecedor, mês; padrão = mês atual)
GET  /dfe/resumo-mensal?mes=     notas recebidas (só resumos, sem canceladas/denegadas) + compras lançadas
POST /dfe/sincronizar            dispara a varredura; devolve quantos resumos novos entraram
POST /dfe/{dfe}/manifestar       { tipo, justificativa? }
POST /dfe/{dfe}/importar         busca o procNFe e chama ImportacaoNotaService
POST /dfe/{dfe}/ignorar          tira da caixa sem manifestar (nota que não é nossa compra)
```

`POST /dfe/{dfe}/importar` é a costura toda do plano, e é curta: pega o XML, chama
`$this->importacao->importar($xml, $request->user())`, trata `NotaEntradaDuplicadaException` e
`LeitorXmlException` como o `NotaEntradaController::importar` já trata, vincula `nota_entrada_id`
e muda `status` para `importado`. Daí para frente é a tela de conferência que já existe.

### 6.3 `gestaofacil-fe`

Página nova `NotasSefaz.tsx` + entrada no menu ao lado de "Notas de entrada":

- lista dos resumos: emitente, valor, data, situação, status
- botão **Buscar notas na SEFAZ** — desabilitado com contagem regressiva quando em cooldown
  (`liberado_em` vem na resposta; a tela mostra "disponível em 42 min", não um erro)
- por linha: **Dar ciência** → depois **Importar itens** → cai na `ConferenciaNotaEntrada.tsx`
- ações secundárias: Desconhecer, Operação não realizada (com justificativa), Ignorar
- **antes da primeira manifestação:** diálogo explicando o que é dar ciência e que é irreversível (D2)

---

## 7. Fluxo e estados

### 7.1 Estados de `dfe_recebidos`

```
          varredura
              ↓
          pendente ──── ignorar ────→ ignorado
              │
              ├─ ciência/confirmação ─→ manifestado ── importar ──→ importado → (nota_entrada)
              │
              └─ desconhecimento / não realizada ──→ recusado
```

`recusado` e `ignorado` são terminais e saem da lista padrão. `importado` aponta para a
`nota_entrada`, que tem o ciclo de vida dela (rascunho → lancado → cancelado, D12 do outro plano).

### 7.2 Por que a varredura roda duas vezes

O XML completo **não** chega na mesma resposta da manifestação. Sequência real:

1. varredura → `resNFe` (resumo) → `dfe_recebidos.status = pendente`
2. manifestar → SEFAZ registra o evento (cStat 135)
3. **nova consulta** — por chave (`consChNFe`, imediata e barata) — → `procNFe` → `xml_path`
4. importar

O passo 3 por chave é o que evita esperar a próxima varredura por NSU. Mas conta no limite de 20
consultas por chave por hora, então não pode ficar num botão que o usuário aperte à vontade: o
`POST /dfe/{dfe}/importar` busca **uma vez** e guarda o XML.

### 7.3 Cancelamento que chega pela distribuição (D6)

`procEventoNFe` de cancelamento vem **sem manifestação** (§3.2). Se a chave bate com um
`dfe_recebidos` já importado:

- `situacao = 3` (cancelada) no `dfe_recebidos`
- aviso em `notas_entrada.avisos` (jsonb, já existe): *"O fornecedor cancelou esta nota na SEFAZ em
  {data}. Se a mercadoria não entrou, estorne o lançamento."*
- **nada é revertido automaticamente**

---

## 8. Fases

Cada fase fecha pelo portão de sempre: revisar → testar nos containers → commitar → `PROGRESS.md`.

### Fase 1 — `nfe-api`: distribuição (sem manifestação)

- [x] 1.1 Migration `distribuicao_estados` (§5.1) + model
- [x] 1.2 `DistribuicaoDocumento` (DTO: nsu, schema, chave, tipo, xml desempacotado)
- [x] 1.3 `distribuicaoDFe(int $ultimoNsu, ?string $chave, SefazContext $ctx)` na
      `SefazGatewayInterface` + `RealSefazGateway` (`Tools::sefazDistDFe`) + `FakeSefazGateway`
- [x] 1.4 Desempacotar `docZip`: `gzdecode(base64_decode(...))`, classificar por `schema`,
      recusar payload que não desempacota (sem deixar exceção crua subir)
- [x] 1.5a **Defesas B1–B20 (§3.5)** entram junto: nenhuma rota de distribuição sai para a SEFAZ sem
      passar pelo `CooldownDaDistribuicao`, que é o único ponto de saída
- [x] 1.5 `CooldownDaDistribuicao`: decide se pode consultar, grava `liberado_em`, conta `bloqueios`,
      trata 137/138/656 (§3.3); loop para em `ultNSU == maxNSU`; tudo sob `lockForUpdate` (§5.1)
- [x] 1.5b Migrations `dfe_consultas_chave` (B7) e `dfe_chamadas` (B12); coluna `habilitado` em
      `distribuicao_estados` (B8); espelho do cooldown no Redis (B10)
- [x] 1.5c Flag `DFE_REAL_HABILITADO` (B11), teto de lotes por requisição e pausa entre lotes (B5),
      orçamento por hora (B6), backoff de erro (B3), margem (B2), retry do client desligado (B14)
- [x] 1.6 Migration + model `dfe_documentos` (§5.1b) — o lote desempacotado é gravado no buffer
      **antes** de responder
- [x] 1.7 `DfeController@index` + `@show` (por chave, via `sefazDownload`) + `@confirmar` e as rotas
      do §6.1. `ultimo_nsu` **só** avança no `confirmar`; chamada sem ack reentrega o buffer sem ir à SEFAZ
- [x] 1.8 Modo somente leitura na primeira varredura real (**por desenho:** `sincronizar` só grava no buffer; quem confirma é o chamador, então basta não chamar `confirmar`; gateway real só liga com `NFE_DFE_REAL_HABILITADO=true`);
      o ack é dado depois de você conferir os dados
- [x] 1.9 Testes de bloqueio: consulta dentro do cooldown não abre soquete (nem com banco zerado,
      pelo espelho Redis); timeout arma backoff e a chamada seguinte é barrada; 656 não é repetido;
      `bloqueios >= 3` desliga o CNPJ; 4ª consulta por chave na hora é barrada localmente; teto de
      lotes interrompe e o próximo clique continua; gateway real desligado sem a flag
- [x] 1.9b Testes: 137 vazio, lote de 50 com loop, parada em `ultNSU == maxNSU`, 656 → 429, cooldown
      ativo não abre soquete, `ultimo_nsu` não avança sem ack, reentrega do buffer, duas chamadas
      concorrentes (a segunda não vai à SEFAZ), renovar certificado preserva o estado
- [x] 1.11 **Primeiro acesso no onboarding:** ao habilitar a feature para um CNPJ, fazer uma única
      chamada `distNSU` (`ultNSU=0`) para a SEFAZ começar a gerar NSU (§1, §3.4); `137` esperado;
      `liberado_em = +1h+margem`. Só depois de B15 respondido
- [x] 1.12 *(auditado em 19/10/2026; **não corrigido** — achado em §14.2)* Auditar suposição de **CNPJ/chave só numéricos** (v1.40): `sped-nfe` instalado, validações
      da `nfe-api`/`gestaofacil-api`, colunas e FE; `cnpj char(14)` e `chave char(44)` ficam, o que
      muda é validação/máscara
- [x] 1.10 Revisar → testar → commitar → `PROGRESS.md`

**Fase 1 fechada em 2026-10-19** — `nfe-api` commit `0f098ed`; 60 testes novos (suíte: 495 passam, 23 puladas, 4 falhas antigas do baseline; mutação de 2 regras derruba 4 testes). Desvios do plano: §3.7 (POST em vez de GET, sem `dfe_consultas_chave`). A migration ainda **não** foi aplicada no banco de dev (o container está no overlay do E2E): `make migrate-nfe`.

### Fase 2 — `gestaofacil-api` + FE: caixa de entrada (ainda só resumos)

- [x] 2.1 Migration `dfe_recebidos` (§5.3) + model com `CompanyScope`
- [x] 2.2 `NfeApiClient::distribuicaoDFe()` e `::documentoPorChave()` (mesmo padrão dos ~20 métodos existentes)
- [x] 2.3 `SincronizacaoDfeService`: varre, grava resumo idempotente por `(empresa_id, chave)` e **só
      então** chama `POST .../dfe/confirmar` com o maior NSU gravado; falha ao gravar = sem ack
- [x] 2.4 `DfeController@index` (filtro por mês, padrão mês atual) / `@resumoMensal` / `@sincronizar` /
      `@ignorar` + rotas. A tela nunca carrega o histórico inteiro; só o mês pedido
- [x] 2.4b `resumoMensal`: dois números lado a lado —
      **"Notas recebidas"** (soma de `valor_total` dos resumos com `situacao` autorizada, só resumos,
      sem ciência nem XML) e **"Já lançadas como compra"** (notas importadas e lançadas em
      `notas_entrada`, com CFOP lido do XML). O rótulo não pode dizer "compras" no primeiro: inclui
      devolução, remessa, bonificação, transferência e nota emitida por engano, e muda quando chega
      cancelamento
- [x] 2.5 `NotasSefaz.tsx`: lista por mês (seletor de mês) + os dois totais + botão de busca com
      cooldown visível + ignorar. Sem data de corte: o resumo de toda nota varrida é guardado
      (a chave é o único jeito de voltar a uma nota; descartar resumo é irreversível, §3.1)
- [x] 2.6 Testes: resumo gravado, reprocessar o mesmo NSU não duplica, 429 vira contagem na tela,
      erro ao gravar não dispara o ack (lote reaparece na próxima sincronização), filtro por mês
      não devolve notas de outro mês, total do mês exclui cancelada/denegada
- [x] 2.7 Portão de fase

**Fase 2 fechada em 2026-10-19** — `gestaofacil-api` `2cf08dc` (28 testes; suíte: 811 passam, 5 falhas antigas do baseline; mutação "confirmar antes de gravar" derruba 2 testes) e `gestaofacil-fe` `37d20e1` (type-check e build ok). **Não feito:** conferência visual no Firefox (é sua, item 4.6) e spec E2E (o gateway de dev não tem fake para a distribuição). Desvios: `GET /dfe/estado` e `POST /dfe/habilitar` (§3.7); aviso de cancelamento usa `tipo` (formato dos avisos existentes), não `codigo`.

### Fase 3 — manifestação

- [x] 3.1 Migration `manifestacoes` (§5.2) + model na `nfe-api`
- [x] 3.2 `manifestar()` na interface + real (reusa `enviarEvento`, `RealSefazGateway.php:158`) + fake
- [x] 3.3 Mapa `tipo` (pt) → `tpEvento`; exigir justificativa só em `nao_realizada`
- [x] 3.4 Endpoint `POST .../manifestar` + unique que barra duplo clique
- [x] 3.5 `gestaofacil-api`: `@manifestar`, grava `manifestacao`/`manifestado_em`/`manifestado_por`
- [x] 3.6 FE: diálogo de primeira manifestação (D2) + as quatro ações (D3)
- [x] 3.6b **Ciência em massa:** seleção de vários resumos, ou "Dar ciência em todas deste mês"
      (escopo = o mês filtrado, ainda pendentes), com o mesmo diálogo de confirmação mostrando a
      quantidade. Enviada um a um (não `sefazManifestaLote`), com resultado por linha; falha em uma
      não derruba as outras. Só Ciência é oferecida em massa
- [x] 3.7 Testes: 135 registra, 573 (duplicidade) não cria segunda linha, `nao_realizada` sem
      justificativa é 422
- [x] 3.8 Portão de fase

**Fase 3 fechada em 2026-10-19** — `nfe-api` `360c234` (21 testes; suíte 516 passam + 4 antigas), `gestaofacil-api` (19 testes; 830 passam + 5 antigas) e `gestaofacil-fe` (type-check e build ok). Mutações (remover a regra de transição; remover a conferência local) derrubam 5 e 3 testes. Desvios: `3.4` — a manifestação **não** usa o cooldown da distribuição (orçamento próprio de 60/h e 200/dia); **só o administrador (`fiscal`) manifesta**, por ser ato fiscal em nome da empresa (§14.3); a *Confirmação da Operação* existe na API e **não** na tela, até o contador decidir (D3).

### Fase 4 — fechar o ciclo: resumo → XML → nota de entrada

- [x] 4.1 `POST /dfe/{dfe}/importar`: usa o `procNFe` **se já chegou pela varredura** (a manifestação gera NSU novo com a NF-e, NT §3.11.3); só se não chegou e o orçamento B7 permite, `consChNFe` (`sefazDownload`) → `ImportacaoNotaService::importar()`
- [x] 4.2 Vincular `nota_entrada_id`, `status = importado`; redirecionar o FE para a conferência
- [x] 4.3 Tratar "manifestou mas o XML ainda não veio" como estado explícito, não como erro: a tela
      mostra "tente de novo após HH:MM" e bloqueia o botão até lá (protege o limite de 20 por chave/hora)
- [x] 4.4 *(implementado na Fase 2, testado ponta a ponta aqui)* Eventos de cancelamento → aviso em `notas_entrada.avisos` (§7.3, D6)
- [x] 4.5 Teste de ponta a ponta com fixture: resumo → ciência → procNFe → nota em rascunho com itens
- [ ] 4.6 Conferência visual no Firefox (é o usuário quem faz) — **ABERTO, é sua**
- [x] 4.7 Portão de fase *(fechado, exceto o 4.6)*

**Fase 4 fechada em 2026-10-19, exceto o 4.6** — `gestaofacil-api` `6d8f56d` (27 testes; suíte: 857 passam + 5 antigas) e `gestaofacil-fe` `d7b939d` (type-check e build ok). Três mutações (sem conferir a ciência, sem a espera local, sem conferir a chave do XML) derrubam 5, 1 e 1 testes.

### Fase 5 — varredura automática diária (**opcional; usa o scheduler que já existe**)

- [x] 5.1 Comando `dfe:sincronizar` por empresa com certificado ativo e feature habilitada,
      registrado em `routes/console.php` (`->dailyAt(...)->withoutOverlapping()`); horário de baixo
      movimento, **jitter** entre empresas (B9). Sem container novo
- [x] 5.2 Respeita todo o §3.5: passa pelo `CooldownDaDistribuicao`, pula CNPJ com `habilitado=false`
      ou com **outro sistema consultando** (B15), e roda no máximo o teto de lotes (B5); o que sobrar
      continua no dia seguinte
- [x] 5.3 Alerta quando `bloqueios` se aproximar do kill switch (B8, limite 3) — a feature se
      desliga e avisa, longe do limite permanente do §3.3
- [x] 5.4 Frequência: **horário fixo, 04:00 de Brasília, uma vez por dia** (decisão do Allan, 20/10/2026; mais horários = outra linha em `routes/console.php`). Sem intervalo próprio no comando: o piso é o do `CooldownDaDistribuicao`. Opt-out **por empresa** na tela (`distribuicao_estados.busca_automatica`, padrão ligado)
- [x] 5.5 Portão de fase (gestaofacil-api `20febf6`, 20/10/2026: 17 testes, mutação nas regras de pular detecta 3; suíte 916 ok, 5 falhas antigas)

### Fase 6 — histórico fora da janela da SEFAZ: importação de XMLs em lote (**independente das fases 1–5**)

A distribuição não entrega notas antigas além da janela do ambiente nacional, nem compras no CPF do
sócio. Para isso o upload manual continua, melhorado:

- [x] 6.1 `POST /notas-entrada/importar-lote`: vários XMLs ou um `.zip`, processados um a um pelo
      `ImportacaoNotaService::importar()`; resposta por arquivo (importado / duplicado / inválido)
- [x] 6.2 FE: `ImportarNotaEntrada.tsx` aceita múltiplos arquivos/ZIP e mostra o resultado por linha
- [x] 6.3 Limites: 100 XMLs/envio, 2 MB por XML, ZIP até 500 entradas e 60 MB descomprimidos, nada extraído em disco, leitura limitada (tamanho declarado pode mentir); excedente vira "ignorado"; 9 testes, mutação detecta 3
- [x] 6.4 Portão de fase (20/10/2026; E2E com vários arquivos não feito)

---

## 9. Riscos

- **Bloqueio de 1 hora que se renova** (§3.3) e, não confirmado pela NT, possível bloqueio duradouro
  por reincidência. Continua sendo o pior risco operacional. Mitigação: cooldown persistido e verificado antes do soquete (1.5/1.7), contador de bloqueios
  com desligamento automático (5.3), e **um** teste por sessão contra o gateway real.
- **`ultimo_nsu` avançado por engano perde nota em silêncio.** Não há erro, não há aviso: a nota
  simplesmente nunca aparece. Mitigação: buffer + ack (D1, §5.1b, 1.6/1.7) — o NSU só avança depois
  que a `gestaofacil-api` gravou —, e guardar `maior_nsu` para que a tela mostre "faltam N documentos".
  Recuperação de buraco detectado em `dfe_recebidos.nsu`: `consNSU` (`numNSU`), gastando cota.
- **Sincronização concorrente** (duplo clique, duas abas) furando o cooldown. Mitigação: lock na
  linha de estado (1.5).
- **Cobertura menor que "todas as NF dos fornecedores"**: só NF-e destinadas ao CNPJ, dentro da
  janela da SEFAZ. O resto entra pela Fase 6.
- **Manifestação é evento fiscal irreversível no nome do cliente.** Mitigação: manual na v1 (D2),
  diálogo na primeira vez, Ciência como padrão por ser a mais neutra.
- **Nota importada da SEFAZ cai numa conferência que ainda tem lacunas** (§13 do outro plano). Com
  XML manual, o volume é o que o usuário sobe; com varredura, as notas chegam sozinhas e o gargalo
  da conferência aparece multiplicado. Daí o pré-requisito no topo.
- **Homologação devolve pouco ou nada** — distDFe em `tpAmb=2` não tem o movimento real. O teste de
  verdade é em produção, com o CNPJ do cliente, o que estreita a margem de erro dos dois itens acima.
- **Cliente novo começa do zero** (NSU não retroativo, §1/§3.4) e **perde notas se ficar >60 dias sem
  consultar** (B20). Mitigação: primeiro acesso no onboarding (1.11), varredura diária, alerta de pausa.
- **Compra em nome de pessoa física não aparece.** A distribuição entrega o que foi emitido contra o
  CNPJ. Nota no CPF do sócio continua sendo XML na mão — o fluxo atual não pode ser removido.

---

## 10. Fora de escopo

- buscar nota **pelo número** — não existe (§1)
- CT-e e NFS-e (outros webservices, outro plano)
- manifestação via `sefazManifestaLote` (até 20 por lote) — só vale com a varredura automática. A
  ciência em massa da Fase 3 (3.6b) envia um evento por vez
- importação automática sem conferência humana
- reversão automática de lançamento por cancelamento do fornecedor (D6)
- buscar o XML de notas **antigas** além da janela de disponibilidade do ambiente nacional

---

## 11. Registro de pendências — nada decidido, nada implementado

**Decisão de 2026-10-02: este plano fica documentado e parado.** Não há código, branch nem
migration. O que segue é o que precisa de resposta **antes** da Fase 1, para que quem retomar não
precise redescobrir as perguntas.

### 11.1 Decisões abertas (detalhe em §4)

> **Atualização 2026-10-19:** as Fases 1 a 4 foram implementadas **adotando a recomendação de cada decisão abaixo**. Continuam listadas como abertas até você confirmar (§14.3, item 7).

| # | Pergunta | Minha recomendação | Quem decide | Trava |
|---|---|---|---|---|
| **D1** | Onde mora o `ultNSU` e o cooldown? | `nfe-api`, tabela por CNPJ+ambiente — é estado do diálogo com a SEFAZ, como `nfe_numbering` | você | Fase 1 inteira (§5.1) |
| **D2** | Manifestação automática ou manual? | manual na v1; opt-in por empresa só na v2 | você | Fase 3 |
| **D3** | Qual evento o botão principal usa? | Ciência (210210); os outros três como ações secundárias | você + **contador** | Fase 3 |
| **D4** | Varredura: botão manual ou cron? | botão manual agora; worker novo só na Fase 5 | você | Fase 2 vs. Fase 5 |
| **D5** | Resumo é `nota_entrada` ou entidade própria? | entidade própria `dfe_recebidos` | você | Fase 2 (§5.3) |
| **D6** | O que fazer com evento de cancelamento que chega? | guardar e avisar, **nunca** reverter sozinho | você | Fase 4 |
| **D7** | Como testar sem queimar o CNPJ? | fixtures anonimizadas no fake + **um** teste real por sessão | você | todas |

### 11.2 Pendências que não são decisão de arquitetura

| Pendência | Por quê | Quem responde |
|---|---|---|
| **Prazo de manifestação** por UF e segmento | a NT garante a disponibilidade no ambiente nacional, mas o prazo para manifestar varia por legislação estadual e segmento (combustíveis, bebidas têm manifestação obrigatória). **Não inventei número neste plano** | contador do cliente |
| **Se Confirmação da Operação entra no fluxo** | é declaração de que a mercadoria entrou, com efeito fiscal maior que a Ciência | contador do cliente |
| ~~Container `gestaofacil_worker`~~ | **Resolvido em v1.3:** o scheduler já existe (§2); a Fase 5 é um comando agendado, sem mudança de infra | — |
| **Fixture anonimizada de `resNFe` / `procNFe` / `procEventoNFe`** | mesma dívida que a §13.3 do `PLAN-IMPORTACAO-XML` registra para a nota de compra real | nós, na Fase 1 |
| **Outros sistemas que já consultam o CNPJ** (contador, ERP) | consumem a mesma cota na SEFAZ (B15); sem saber, o primeiro `656` parece defeito nosso | perguntar ao cliente e ao contador antes de ligar a feature |
| **Volume real de resumos por cliente** | a premissa é ~1 KB por resumo e janela de 90 dias; confirmar quantas linhas a primeira varredura grava e quanto tempo leva | medir na primeira varredura real (1.8) |
| ~~Janela de disponibilidade no ambiente nacional~~ | **Resolvido (NT §3.4/§3.5): 90 dias**, e cliente novo não tem NSU retroativo. O que falta medir é só o volume | — |

### 11.3 O que NÃO está pendente (já verificado, não precisa rediscutir)

- Buscar nota **pelo número** não existe e não vai existir: o `cNF` da chave são 8 dígitos
  aleatórios do emitente (§1).
- O XML completo **só** vem após manifestação — confirmado na NT 2014.002, não é suposição (§3.2).
- Evento de **cancelamento vem sem** manifestação (§3.2) — é o que viabiliza o D6.
- `LeitorXmlNfe` já aceita raiz `nfeProc`: o `procNFe` entra no pipeline atual sem alteração (§2).
- `nfe_events` **não** serve para manifestação (preso a `nfes.id`) — tabela nova é obrigatória, não
  é preferência (§2, §5.2).
- O consumo indevido bloqueia o CNPJ por 1 h e **renova se você insiste** (NT): o cooldown é requisito,
  não otimização (§3.3). Que vire permanente **não está na NT**.

---

## 12. Como retomar este plano

Ele vai ficar parado, e o código vai andar embaixo dele. Antes de começar a Fase 1:

- [ ] **Reconferir as referências `arquivo:linha` da §2** — foram verificadas em 2026-10-02 e
      envelhecem. O que importa é que ainda existam: `Tools::sefazDistDFe`, `Tools::sefazManifesta`,
      `RealSefazGateway::enviarEvento`, `ImportacaoNotaService::importar(string, User)` e o aceite de
      raiz `nfeProc` no `LeitorXmlNfe`.
- [ ] **Conferir se a §13 do `PLAN-IMPORTACAO-XML.md` fechou** — é pré-requisito declarado no topo.
- [ ] **Reconferir a NT 2014.002** (última lida: **v1.40, julho/2026**, via cópia de terceiro; baixar a
      versão oficial do Portal Nacional da NF-e e comparar): 50 por lote, 1 h, 20 consultas/h e a
      janela de 90 dias foram **confirmados no texto**; "50 bloqueios" e "bloqueio por IP" **não**.
- [ ] **Responder D1–D7** (§11.1) e levar D3 + prazos ao contador (§11.2).
- [ ] Só então a Fase 1, que é autocontida na `nfe-api` e não toca em nada que já funciona.

---

## 13. Registro da revisão v1.1 — 2026-10-19

Revisão feita sem código novo; o plano continua **parado** e D1–D7 continuam abertos.

| Mudança | Onde | Por quê |
|---|---|---|
| D1 passa a exigir buffer (`dfe_documentos`) + ack; NSU só avança no `confirmar` | §4 D1, §5.1b, §6.1, 1.6–1.8, 2.3 | o desenho original deixava o NSU avançar antes de a nota existir na `gestaofacil-api` |
| Lock na linha de `distribuicao_estados` | §5.1, 1.5, 1.9 | duas sincronizações simultâneas furavam o cooldown |
| Loop para em `ultNSU == maxNSU` | §3.1, 1.5 | evita chamada extra e arma o `liberado_em` |
| `sefazDownload` citado e usado no passo por chave | §2, §6.1, 4.1 | já existe em `Tools.php:1258` |
| Ciência em massa (um evento por vez) | 3.6b | sem ela, destravar dezenas de XMLs é dezenas de cliques |
| Primeira varredura real em modo somente leitura | 1.8 | homologação não devolve movimento; a primeira prova é em produção |
| Retry do XML com horário na tela | 4.3 | protege o limite de 20 consultas por chave/hora |
| Fase 6: upload em lote/ZIP | Fase 6 | histórico fora da janela e compras no CPF não vêm pela SEFAZ |
| `enviarEvento` agora em `RealSefazGateway.php:158` | §2 | referência envelhecida em 1 linha |

**Para retomar:** além do §12, o pré-requisito da §13 do `PLAN-IMPORTACAO-XML` segue com 3 itens
abertos (1.14, 3.4 e 5.13, conferência visual no Firefox). A Fase 6 não depende dele nem das
fases 1–5 e pode ser feita antes.

### 13.1 Ajustes do mesmo dia — carga por mês (sem data de corte)

| Mudança | Onde | Por quê |
|---|---|---|
| Filtro por mês (padrão = mês atual) + índice `(empresa_id, dh_emissao)` | §5.3, §6.2, 2.4 | a SEFAZ não filtra por período (só `distNSU`/`consNSU`/`consChNFe`); o corte é na tela, não na varredura |
| Dois totais: "Notas recebidas" (resumos) e "Já lançadas como compra" (CFOP do XML importado) | 2.4b, 2.5 | o resumo não traz CFOP; devolução, remessa, bonificação e nota por engano entram na soma, e cancelamentos chegam depois |
| "Dar ciência em todas deste mês" | 3.6b | escopo da ciência em massa acompanha o filtro |
| **Sem data de corte** | 2.5 | resumo guarda só a chave e dados básicos (~1 KB); descartar é irreversível, pois o NSU não repete |
| Pendência: medir volume real de resumos | §11.2 | confirmar a premissa de tamanho e tempo de carga |

### 13.2 Revisão v1.2 — 2026-10-19: defesa contra bloqueio e histórico

| Mudança | Onde | Por quê |
|---|---|---|
| Esclarecido que o histórico completo da empresa **não** vem; só a janela que a SEFAZ mantém | §1 | empresa de 20 anos não terá 20 anos de notas pela distribuição |
| Nova §3.5 com 14 requisitos B1–B14 contra bloqueio | §3.5 | bloqueio permanente é o único dano irreversível |
| Fail closed, margem no cooldown, backoff em erro de rede, 656 não repetido | B1–B4 | consulta sem resposta pode ter sido contada |
| Teto de lotes por clique e pausa entre lotes | B5 | carga inicial grande sem estourar timeout nem fazer rajada |
| Orçamento por hora e contador por chave | B6, B7 | proteção que não depende de cada rota |
| Kill switch em 3 bloqueios (antes 5 e só na Fase 5) | B8, 1.5b | longe do limite de 50 |
| IP de saída compartilhado entre clientes | B9 | risco de um cliente afetar os outros (a confirmar) |
| Cooldown espelhado no Redis; gateway real desligado fora de produção | B10, B11 | dev roda SEFAZ real e o banco de e2e é recriado |
| Auditoria de chamadas; retry de client desligado | B12, B14 | diagnóstico e nenhuma consulta "fantasma" |

### 13.3 Acréscimo de 2026-10-19 (material externo colado pelo usuário)

Conferido contra o plano: 1 h após `137`, 20 consultas/h por `consNSU`/`consChNFe`, relógio que reinicia se insiste e `distNSU` com o último NSU **já estavam** no plano. Novo:

| Item | Onde | Observação |
|---|---|---|
| Múltiplos sistemas no mesmo CNPJ | B15, §11.2 | risco que o cooldown local não enxerga |
| `ultNSU = 0` nunca como recuperação | B16 | semear por `max(nsu)` e pausar |
| `consNSU` restrito a recuperar buraco | B17 | varredura é sempre `distNSU` |
| **Divergência não resolvida:** o material fala em "ciclos de 35 a 60 minutos" | B2 | o plano segue com **1 h + 5 min**, o valor mais seguro; o intervalo exato é a reconferir na NT 2014.002 (§12). A fonte é secundária e não cita a NT |

### 13.4 Frequência diária e correção sobre o scheduler — 2026-10-19

| Mudança | Onde | Por quê |
|---|---|---|
| Varredura automática **1×/dia** por empresa; botão manual mantido | D4, Fase 5, B18 | público são empresas pequenas, poucas notas; menos chamadas, menos risco |
| Fase 5 deixa de exigir container/worker novo | §2, D4, Fase 5, §11.2 | `gestaofacil_scheduler` já existe e roda `schedule:work`; comando agendado roda síncrono |
| Correção: o plano dizia que não havia scheduler | §2 | verificado em `docker-compose.yml:153` e `routes/console.php` |

### 13.5 Conferência contra a NT 2014.002 (v1.12 e v1.40) — 2026-10-19

Arquivo lido: `NT2014.002 - v1.12 - WsNFeDistribuicaoDFe.pdf` (na raiz do projeto; cópia idêntica em
`~/Downloads`). É de **03/2022 e não é a vigente**; comparei com a **v1.40** (07/2026).

| Achado | Onde no plano | Efeito |
|---|---|---|
| Cliente novo: NSU só a partir do primeiro acesso, sem retroativo; >60 dias sem consultar interrompe a geração | §1, §3.4 da NT, B20, 1.11 | **não existe carga inicial**; onboarding faz o primeiro acesso cedo |
| Janela de 90 dias | §3.6, §11.2 | pendência resolvida |
| "50 bloqueios → permanente" e "bloqueio por IP" não estão na NT | §3.3, B8, B9 | rebaixados a hipótese |
| Vários sistemas no mesmo CNPJ: a NT exige a mesma sequência | B15 | confirmado pela NT, não só por relato |
| Limite de 20 consultas/h é ambíguo (por chave/NSU ou total) | §3.3, B7 | adotado o pior caso (total) |
| Manifestação gera NSU novo com a NF-e | 4.1, B7 | XML chega também na varredura; `consChNFe` vira atalho |
| `656` devolve o último NSU (v1.14) | B16 | recuperação possível, mas custa 1 h |
| `consChNFe` não exige NSU prévio (v1.15) | §3.6 | a v1.12 ainda dizia que exigia |
| CNPJ alfanumérico (v1.40) | 1.12 | validação numérica quebra |
| Códigos terminais `217/632/640/641/653/654` | B19 | não repetir |

**Correção de algo que eu disse na conversa:** afirmei que o 20 era "por chave, não por total". A NT
não deixa isso claro; o plano passou a tratar como total.

## 14. Registro de implementação (Fases 1 a 4) e decisões maiores para você

### 14.1 Andamento

- **Fase 1** — fechada em 2026-10-19 (`nfe-api` `0f098ed`).
- **Fase 2** — fechada em 2026-10-19 (`gestaofacil-api` `2cf08dc`, `gestaofacil-fe` `37d20e1`).
- **Fase 3** — fechada em 2026-10-19 (`nfe-api` `360c234`, `gestaofacil-api` `8898094`, `gestaofacil-fe` `16d97cd`).
- **Fase 4** — fechada em 2026-10-19, exceto a conferência visual no Firefox (`gestaofacil-api` `6d8f56d`, `gestaofacil-fe` `d7b939d`).
- **Fase 5** (varredura automática diária) — **implementada em 20/10/2026, revista no mesmo dia (ver Decisões)** (`dfe:sincronizar`, 02:00–06:00 Brasília, de hora em hora com intervalo de 24 h; pula homologação, busca desativada, `outro_sistema`≠não, kill switch; avisa no log CNPJ >45 dias sem varredura). Empresa que divide a cota fica de fora (a 1 do dev tem `outro_sistema=sim`).

### 14.2 Achados fora do escopo (precisam de decisão)

- *(RESOLVIDO, ver §14.2b)* **CNPJ alfanumérico (NT v1.40) quebra o resto do sistema.** A distribuição já é alfanumérica (rotas
  `[0-9A-Z]{14}`, parser, chave), mas a emissão assume só dígitos: `digits:14` em `StoreNfeRequest`,
  `StoreCertificateRequest`, `StoreNfeNumberingRequest`, `ProvisionarEmpresaRequest`; `preg_replace('/\D/')`
  no `NfeXmlBuilder` e em ~20 pontos da `gestaofacil-api` (apagaria as letras); rotas `\d{14}`; extração
  do CNPJ do certificado (`CertificateService:129`, `\d{14}`); `sped-nfe` v5.2.8 pode não suportar. Hoje só
  afeta CNPJs **novos** (a partir de 07/2026). **Não mexi:** é decisão de escopo.

### 14.2b Resolvido em 2026-10-19 (mesmo dia, por decisão do Allan)

- **CNPJ alfanumérico em todo o sistema:** feito. `nfe-api` `1d033e8` (21 testes), `gestaofacil-api` `110e647` + teste de reforço (19 testes), `gestaofacil-fe` `dbb5ed9`
  (`npm run verificar:documento`, 28 verificações). O `sped-nfe` 5.2.8 e o `sped-common` 5.1.17 já aceitam letras na chave (DV com ASCII − 48), mas os **schemas** do pacote
  são só parcialmente alfanuméricos (`distDFeInt`, `Id` de evento e QR Code ainda numéricos), por isso o `RealSefazGateway` valida num pacote derivado (`SchemasCnpjAlfa`,
  gerado do vendor, vendor intocado). Conferido: o exemplo da Receita `12ABC34501DE35` fecha o DV nas três bases.
  **Não conferido contra a SEFAZ real:** se a SEFAZ aceita o CNPJ alfanumérico em homologação hoje e a partir de quando; as fontes divergem entre 06/2026 e 07/2026.
- **Confirmação da Operação na tela:** liberada (`gestaofacil-fe` `f745c89`), com confirmação que explica o efeito fiscal; Recusar também vale depois da ciência.
- **Quem manifesta:** continua só o administrador, "por enquanto".

### 14.2c Decisão de 2026-10-19 (Allan): a feature só opera em produção

Homologação não tem movimento de terceiros, e `dfe_recebidos` não guarda ambiente. Em vez de uma coluna de ambiente, `nfe-api` recusa tudo (`409 so_producao`) com a empresa em homologação
(`NFE_DFE_SOMENTE_PRODUCAO=true`), e a tela explica e desabilita. Lição do primeiro teste em produção: o primeiro acesso levou 36 s (7 lotes, NSU 4071–4384) e o navegador abortava aos 30 s;
39 das 43 notas já vinham com XML porque o contador dá a ciência — a importação passou a aceitar XML já entregue.

### 14.3 Decisões maiores — para você responder (nada disto travou a implementação)

> Itens 2, 3 e 6 abaixo já foram respondidos (§14.2b). Ficam abertos: 1, 4, 5 e 7.

Tomei como pequenas, e registro aqui, as escolhas de desenho listadas na §3.7 e os valores de consumo. O que segue é maior:

1. **Risco dos 60 dias sem a Fase 5 (o mais importante).** A varredura hoje só roda quando alguém clica em *Buscar notas*. Se o CNPJ ficar mais de 60 dias sem
   consultar, a SEFAZ para de gerar NSU e as notas daquele intervalo **se perdem para sempre** (NT §3.4). `dfe:verificar-continuidade` existe mas **não está agendado**.
   Recomendo fazer a Fase 5 logo: um comando diário no `gestaofacil_scheduler` que já existe. Faço se você disser.
2. **Quem manifesta.** Só o administrador (`fiscal`). Operador vê a lista, ignora e importa depois da ciência. Se o operador também deve dar ciência, é uma troca de rota e de botão.
3. **Confirmação da Operação** existe na API e não na tela (declara que a mercadoria chegou; D3 pede o contador).
4. **Valores de consumo** (§3.7): varredura no mínimo a cada 12 h (24 h com outro sistema), ciência em massa de até 50 por pedido, 2 consultas por chave por hora. Notas novas podem demorar até 12 h
   para aparecer no botão manual. Aprove ou ajuste (`config/nfe.php` → `distdfe`, tudo por `.env`).
5. **O primeiro acesso é uma chamada real à SEFAZ dentro do clique em *Ativar*.** Fica atrás de `NFE_DFE_REAL_HABILITADO` (desligado fora de produção).
6. **CNPJ alfanumérico no resto do sistema** (§14.2): não mexi.
7. **D1 a D7 foram adotadas como recomendadas** (nfe-api guarda o NSU; ciência manual; Ciência como botão principal; botão manual agora; entidade própria; cancelamento só avisa; fixtures sintéticas).
   Confirme ou mande trocar.

### 14.4 O que NÃO foi feito e por quê

- Conferência visual no Firefox (item 4.6): é sua.
- Spec E2E no `gestaofacil-e2e`: o gateway de dev não tem fake da distribuição, e ligar o real gasta a cota.
- Migrations **não aplicadas** no banco de dev (o container está no overlay do E2E): `make migrate-nfe` e `make migrate-api`.
- Teste real contra a SEFAZ: nenhum. Tudo foi validado contra a SEFAZ roteirizada/fake. A primeira varredura real deve ser supervisionada (`NFE_DFE_REAL_HABILITADO=true`, uma vez).
- Pergunta ao cliente/contador se alguém mais consulta o CNPJ (B15), prazo de manifestação por UF e a Confirmação da Operação (§11.2).
- Fase 5.

### 14.5 Decisões e lições consolidadas (2026-10-19) — leia antes de retomar

**Decisões do Allan**
1. **Só em produção.** A busca, a consulta por chave e a manifestação operam apenas com a empresa em produção (`409 so_producao`, `NFE_DFE_SOMENTE_PRODUCAO=true`). Homologação não tem notas de terceiros e a caixa de entrada
   não guarda ambiente. Não existe coluna de ambiente em `dfe_recebidos` de propósito.
2. **Só o administrador manifesta ("por enquanto").** Operador e vendedor não veem ciência, confirmação, recusa nem ciência em massa; o operador pode ignorar e importar.
3. **Confirmação da Operação está na tela** (com diálogo que explica o efeito fiscal). **Recusar** (desconheço / não realizada) vale também depois da ciência.
4. **CNPJ alfanumérico** em todo o sistema (NT Conjunta 2025.001), não só na distribuição. Ver §14.2b.
5. **Banco de dev será zerado** quando a empresa entrar em operação (as 43 notas reais de produção do teste somem junto).
6. **Quem dá a ciência é, na prática, o contador** (39 das 43 notas já vieram com XML). A tela existe para quando ninguém faz; **perguntar ao contador** se ele dá ciência automática e se a loja precisa confirmar recebimento
   em alguma operação (não verificado, depende de UF e segmento).

**Lições do primeiro teste real em produção (7 chamadas, NSU 4071–4384, 36 s, 314 documentos, 43 notas)**
- O primeiro acesso pode trazer meses de notas se o contador já consulta o CNPJ: demora, e o navegador abortava aos 30 s (hoje 150 s). O servidor concluiu e gravou tudo; nada se perdeu.
- `Ativar` precisa gravar e confirmar o que o primeiro acesso trouxe (senão ficaria preso no buffer com o botão bloqueado por 24 h).
- Nota cujo XML já chegou tem a ciência dada por outro sistema: **pode ser importada sem nova ciência**.
- Nota importada por upload de XML aparece como importada na lista (`ReconciliadorDfe`, por chave, sem SQL cru).
- Tela só mostrava o mês corrente (4 de 43): faixa de meses com contagem, atalhos e intervalo livre (`PeriodoDfe`).
- Armadilhas de operação: depois de atualizar o código, `make migrate-nfe`, `make migrate-api` e `make cache-clear-nfe`; `NFE_DFE_REAL_HABILITADO` vem do `.env` do `gestaofacil-dev-environment` (não da pasta da `nfe-api`) e exige
  `make up` + `make cache-clear-nfe`; o cache de config velho zera `config('nfe.distdfe.*')`.

**Convenções criadas**
- Botão desabilitado não reage ao hover em todo o sistema (`index.css`).
- Regras puras do front sem runner de teste: `npm run verificar:documento` e `npm run verificar:dfe` (dentro do container).
- O teste `EntradaESeguraTest` proíbe SQL cru (`raw(`, `statement(`): contagem por mês e reconciliação usam Eloquent.


### 14.6 Decisões de 20/10/2026 (Allan) — varredura automática e importação em lote

| Decisão | Motivo |
|---|---|
| Varredura automática **uma vez por dia, 04:00 de Brasília, horário fixo** (era de hora em hora entre 02h e 06h com intervalo de 24 h) | de hora em hora era barulho e gasto sem ganho; horário fixo dispensa regra de intervalo local; quem precisar de mais, acrescenta um horário (ex.: um no expediente) |
| **Empresa com outro sistema na cota também roda**; a trava é a **chave "busca automática" por empresa**, padrão ligada, que o administrador desliga na tela. `DFE_AUTOMATICO_COMPARTILHADA` e `DFE_AUTOMATICO_HORAS` foram **removidos** | uma consulta por dia está muito abaixo do 1 h da NT; a coordenação com o contador já é exigida ao ativar; o controle passa a ser do cliente, não de variável de ambiente |
| Chave guardada no **nfe-api** (`distribuicao_estados.busca_automatica`), exposta em `GET /dfe` | é estado do diálogo com a SEFAZ, como `outro_sistema`; um lugar só |
| Intervalo mínimo com outro sistema: **20 h** (era 24 h) | com hora fixa a varredura de hoje termina minutos depois das 04:00 e a de amanhã começa às 04:00: 24 h faria pular um dia inteiro. 12 h sem outro sistema não muda |
| `outro_sistema` agora **pode ser mudado depois de ativado** (`POST /dfe/configurar`, só administrador, auditado, não vai à SEFAZ); passar para `sim`/`nao_sei` exige a coordenação confirmada | antes quem marcasse "sim" ficava preso a isso |
| Importação em lote: **8 MB por envio** (teto do nginx `client_max_body_size`), não 20 MB; a tela confere antes de enviar e traduz o 413 | validação de 20 MB era inalcançável e o erro virava genérico |

### 14.7 Encerramento (2026-10-20) — o que fica em aberto, e com quem

| Item | Quem | Observação |
|---|---|---|
| Conferência visual no Firefox: tela *Notas na SEFAZ* (lista, período, ações, painel *Configurar a busca*) e *Importar nota de entrada* (vários XMLs/ZIP) | Allan | 4.6; o painel de configuração só aparece com a empresa em **produção** (decisão do Allan: ficar assim; em homologação a busca e a configuração são recusadas pelo servidor) |
| Perguntas ao contador: ele dá a ciência automaticamente? A loja precisa confirmar o recebimento em alguma operação? | Allan | define se a Confirmação da Operação entra no fluxo normal |
| Primeira chamada real com **CNPJ alfanumérico** | Allan, ao entrar em produção | nunca testada na SEFAZ real; o formato segue a NT 2014.002 v1.40 |
| `NFE_DFE_REAL_HABILITADO` voltar a `false` no `.env` do dev (+ `make up`, `make cache-clear-nfe`) | Allan | trava de ambiente; produção deixa `true` |
| Zerar o banco de dev ao entrar em operação | Allan | já combinado |
| Teste E2E do lote de XML/ZIP e do painel de configuração | futuro | E2E hoje não cobre ativar/buscar/manifestar (empresa E2E em homologação) |
| ~~Defeito do filtro de data da lista *Notas fiscais* (fuso local × UTC)~~ | **resolvido 20/10/2026** | fuso da aplicação = Brasília (decisão do Allan); também some a limitação do mês da nota em UTC nas 3 últimas horas do mês |
| Totais "Notas recebidas/Já lançadas" somam o período inteiro | opcional | só rótulo |

D1–D7 foram adotadas conforme a recomendação do plano; nenhuma foi contestada.
