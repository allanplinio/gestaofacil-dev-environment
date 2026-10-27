# Plano de Implantação e Infraestrutura — GestãoFácil

> Documento de planejamento. Custos são estimativas em R$/mês, sem impostos. Itens marcados como **(estimativa)** não foram cotados diretamente com o provedor.

## 1. Premissas

| Item | Valor | Origem |
|---|---|---|
| NF por empresa, média | 100/dia | Informado |
| NF por empresa, pior caso | 200/dia | Informado |
| Dias úteis por mês | 22 | Premissa |
| Horas de expediente | 10 | Premissa |
| Tamanho médio do XML de NF-e | 15 KB | Estimativa |
| Importações de XML por cliente | 10/mês, ~200 itens cada | Informado (XML real tem 313 itens) |
| Retenção fiscal | 5 anos | Obrigação legal |
| Dimensionamento de capacidade | **pior caso** (4.400 NF/mês por cliente) | Decisão |

Dimensionar pelo pior caso evita estourar capacidade quando uma empresa acelera.

## 2. Carga por cliente e por total

| Clientes | NF/mês (média) | NF/mês (pior caso) | Pico estimado (pior caso, 3x) |
|---|---|---|---|
| 1 | 2.200 | 4.400 | ~1/min |
| 10 | 22.000 | 44.000 | ~10/min |
| 30 | 66.000 | 132.000 | ~30/min |
| 100 | 220.000 | 440.000 | ~100/min (~1,7/s) |

Pico = NF/mês ÷ 22 dias ÷ 10 horas × 3 (fator de pico), convertido para minuto.

No pior caso com 100 clientes, o gargalo é a fila de envio à SEFAZ (com 3 a 5 s por chamada, ~10 workers simultâneos dão folga), e não a CPU. As 1.000 importações mensais de XML são concentradas e devem rodar em fila separada, para não disputar com a emissão.

## 3. Fases de implantação

### Fase 0 — Validação (1 empresa piloto, 2 a 3 meses)

- **Infra:** VPS NVMe 4 (2 vCPU, 4 GB RAM, 100 GB NVMe). Custo: **R$ 30,39/mês** (plano de 3 anos). Confirmar condições de upgrade antes de contratar.
- **Backup:** diário, com cópia offsite. Custo estimado: **R$ 20/mês** **(estimativa)**.
- **Total:** **~R$ 50/mês**.
- **Obrigatório antes de sair da fase:** teste de restauração de backup e teste de carga com 200 emissões simuladas.

### Fase 1 — Operação inicial (2 a 30 clientes)

- **Infra:** VPS NVMe 8 (4 vCPU, 8 GB RAM, 200 GB NVMe). Custo: **R$ 45,49/mês**.
- **Backup offsite:** **R$ 30/mês** **(estimativa)**.
- **Total:** **~R$ 80/mês**.
- **Capacidade:** ~130 mil NF/mês (pior caso), ou seja, até 30 clientes.

### Fase 2 — Separação de serviços (30 a 60 clientes)

- **Infra:** servidor de aplicação (4 vCPU, 8 GB) e servidor de banco (4 vCPU, 16 GB), com storage de 200 GB para XML.
- **Custo:** **R$ 240 a 370/mês** **(estimativa, usar R$ 305)**. Planos de 16 GB não foram cotados nas fontes consultadas.
- **Capacidade:** ~260 mil NF/mês, ou seja, até 60 clientes.

### Fase 3 — Escala (60 a 100 clientes)

- **Infra:** 2 servidores de aplicação atrás de um balanceador, banco com 8 vCPU e 32 GB, storage de 0,5 a 1 TB.
- **Backup offsite:** cerca de US$ 6 por TB por mês de referência, a confirmar **(estimativa)**.
- **Custo:** **R$ 450 a 930/mês** **(estimativa, usar R$ 690)**.
- **Capacidade:** ~440 mil NF/mês, ou seja, até 100 clientes.
- **Acima de 100 clientes:** não está previsto aqui. Será um novo plano.

## 4. Crescimento exponencial de clientes

Modelo:

```
N(m) = 100 ^ ((m − 1) / T)        com N(1) = 1
```

- `m` = mês comercial, a partir do início das vendas.
- `T` = meses para chegar a 100 clientes.
- Taxa mensal de crescimento: `g = 100^(1/T) − 1`.

| Cenário | T (meses para 100) | Crescimento mensal (g) |
|---|---|---|
| Rápido | 12 | 46,8% |
| **Base** | **24** | **21,2%** |
| Lento | 36 | 13,6% |

Cenário base (T = 24):

| Mês | Clientes N(m) | NF/mês pior caso |
|---|---|---|
| 1 | 1 | 4.400 |
| 5 | 2 | 8.800 |
| 7 | 3 | 13.200 |
| 10 | 6 | 26.400 |
| 13 | 10 | 44.000 |
| 17 | 21 | 92.400 |
| 21 | 42 | 184.800 |
| 25 | 100 | 440.000 |

## 5. Decaimento do custo unitário

O custo total de infra é uma escada: sobe em saltos quando troca de fase e fica fixo dentro dela. Já o custo por cliente cai exponencialmente dentro de cada fase, porque o número de clientes cresce exponencialmente:

```
u(m) = C_fase / N(m) = C_fase · 100^(−(m−1)/T)
```

- **Meia-vida do custo unitário dentro de uma fase** (cenário base): `ln 2 / ln(100^(1/24)) ≈ 3,6 meses`. A cada 3,6 meses, o custo por cliente cai pela metade, sem mudar a infra.
- O custo unitário sobe nos saltos de fase e depois volta a cair.

Projeção de custo (cenário base, gatilhos da seção 6):

| Mês | Clientes | Fase | Infra total (R$/mês) | Custo por cliente (R$) |
|---|---|---|---|---|
| 1 | 1 | 0 | 50 | 50,0 |
| 5 | 2 | 1 | 80 | 40,0 |
| 7 | 3 | 1 | 80 | 26,7 |
| 10 | 6 | 1 | 80 | 13,3 |
| 13 | 10 | 1 | 80 | 8,0 |
| 17 | 21 | 2 | 305 | 14,5 |
| 21 | 42 | 3 | 690 | 16,4 |
| 25 | 100 | 3 | 690 | 6,9 |

Leitura: o custo por cliente tem picos nos saltos, mas é quase sempre menor que um plano de software cobrado por empresa. Os picos devem ser absorvidos pela margem no mês da troca, não pelo preço do cliente.

## 6. Gatilhos de escalonamento

Regra: migrar quando o uso chegar a **70%** da capacidade da fase atual, com **30 dias** de antecedência para provisionar e validar.

| Transição | Gatilho (clientes) | Gatilho (NF/mês pior caso) | Mês esperado (cenário base) | Ação |
|---|---|---|---|---|
| Fase 0 → 1 | 2 | ~9 mil | 5 | Contratar NVMe 8 |
| Fase 1 → 2 | 21 | ~92 mil | 17 | Separar banco e app |
| Fase 2 → 3 | 42 | ~185 mil | 21 | Contratar 2º app e banco 8 vCPU |

Os gatilhos devem ser confirmados pelas métricas reais: uso de CPU acima de 70% por mais de 1 hora, uso de disco acima de 70%, tempo de resposta da emissão acima do aceitável, fila de envio à SEFAZ crescendo.

## 7. Armazenamento e backup

- **XML de NF-e:** 15 KB por nota. No pior caso com 100 clientes, são ~79 GB por ano.
- **Acumulado com 5 anos de retenção:** ~400 GB só de XML, sem contar banco e índices.
- **Crescimento no cenário base:** o volume acumulado nos primeiros 25 meses fica em torno de 20 a 40 GB de XML, então o storage inicial de 200 GB cobre os dois primeiros anos.
- **Ação:** expandir storage quando passar de 70% do disco. Comprimir XML antigo (após 1 ano) e avaliar arquivamento frio.
- **Backup:** regra 3-2-1 (3 cópias, 2 mídias, 1 fora do servidor). Teste de restauração mensal, registrado.

## 8. Riscos e o que monitorar

| Risco | Impacto | Mitigação | Custo |
|---|---|---|---|
| Queda do link da loja | PDV para | Contingência offline no sistema | Dev |
| SEFAZ lenta ou indisponível | Atraso na emissão | Fila com retry e contingência | Dev |
| Disco cheio | Emissão para | Alerta em 70%, expansão antecipada | Incluído |
| Perda de dados | Crítico, fiscal | Backup offsite e restauração testada | R$ 20 a 30/mês (fase 0 a 1) |
| Importação grande travando emissão | Lentidão no PDV | Fila separada para importação | Dev |
| NF-e em lote ou DANFE atrasando a NFC-e do caixa | Cliente esperando no balcão | Fila `nfce` com supervisor próprio no Horizon (19/10/2026); alerta se a espera passar de 15 s | Dev (sem infra nova) |
| Upgrade de plano com indisponibilidade | Parada curta | Janela de manutenção comunicada | Incluído |

Monitorar desde a Fase 0: uso de CPU, RAM, disco, tamanho do banco, tamanho da fila de envio à SEFAZ e tempo de resposta do PDV.

## 9. Recomendação para precificação

- **Custo de infra por cliente** no cenário base: de R$ 50 (cliente único, fase 0) a cerca de R$ 7 (100 clientes).
- **Sugestão:** cobrar um valor fixo de infra por cliente, calculado no pior caso da fase atual, e não o custo unitário do mês. Assim o cliente não paga o pico de uma troca de fase.
- **Piloto:** o primeiro cliente sozinho custa R$ 50/mês de infra. Cobrar uma taxa de implantação cobre essa fase.

## 10. Pendências antes de fechar o plano

- Confirmar preços dos planos de 16 GB e 32 GB no provedor escolhido.
- Confirmar condições de upgrade do NVMe 4 para o NVMe 8 (pagar só a diferença, sem perder IP e dados).
- Confirmar preço do backup offsite por TB.
- Validar a capacidade do NVMe 8 com teste de carga real. Os números de capacidade desta seção são estimativas.
- Escolher o método de atualização do VPS (seção 11) e montar o script de deploy antes do piloto.

## 11. Ambientes e atualização do código

### 11.1 Ambientes

| Ambiente | Onde roda | Quem usa | Dados | SEFAZ | Custo |
|---|---|---|---|---|---|
| **Produção** | VPS (Fase 0 em diante) | Cliente piloto e, depois, clientes | Reais, fiscais, com backup | Produção (`tpAmb=1`) | Previsto na seção 3 |
| **Dev** | Máquina do desenvolvedor, Docker (`gestaofacil-dev-environment`) | Desenvolvedor | Fictícios (seeds) | Homologação (`tpAmb=2`) | Zero |
| **Teste** | Máquina do desenvolvedor, Docker, mesma stack do dev | Desenvolvedor e testes automatizados (Pest, Playwright) | Fictícios, descartáveis | Homologação (`tpAmb=2`) | Zero |

Regras:

- Nenhum dado real de cliente sai do VPS. Para reproduzir um problema, usar XML anonimizado ou seed.
- Os testes de carga e de restauração de backup (seção 3) rodam no ambiente de teste local, contra a SEFAZ de homologação, nunca contra a produção.
- Não há ambiente de homologação em VPS por enquanto. Quando houver um segundo desenvolvedor ou um testador externo, avaliar um VPS de homologação (~R$ 30/mês, fora da previsão atual).
- Os quatro repositórios (`gestaofacil-fe`, `gestaofacil-api`, `nfe-api`, `gestaofacil-e2e`) estão no GitHub, branch `master`.

### 11.2 Como o VPS recebe código

Recomendação: deploy disparado a partir do `master` do GitHub, executando sempre o mesmo script no VPS. O script faz:

1. Backup do banco antes de qualquer mudança (ver seção 7).
2. `git pull` nos repositórios de produção.
3. `docker compose build` e `docker compose up -d`.
4. Migrations (`migrate --force` no Laravel), só depois dos containers novos subirem.
5. Verificação de saúde (endpoint de status da API). Se falhar, voltar ao commit anterior e restaurar o backup se houve migration destrutiva.

Duas formas de disparar, em ordem de adoção:

- **Fase inicial (agora):** deploy manual. Na máquina do desenvolvedor, `ssh` no VPS e rodar o script `deploy.sh`. Não depende de CI e cabe em um desenvolvedor só.
- **Quando o CI existir:** GitHub Actions com `workflow_dispatch` (disparo manual) rodando o mesmo script via SSH. O workflow `security.yml` já previsto em `PLAN-API.md` roda antes do deploy. Deploy automático a cada push no `master` fica descartado: produção fiscal não deve mudar sem um passo consciente.

Itens de segurança para o deploy:

- Chave SSH só para deploy, em GitHub Secrets, sem acesso de login interativo ao usuário de serviço.
- No VPS, o repositório é lido com deploy key somente leitura.
- `.env` de produção fica só no VPS, fora do Git. Nunca em GitHub Secrets sem necessidade.
- Deploy só a partir de `master`. Não publicar branch de feature no VPS.

### 11.3 Pendências desta seção

- Decidir se o script de deploy fica em `gestaofacil-dev-environment` ou em um repositório próprio de infra.
- Definir o endpoint de verificação de saúde de cada API.
- Definir a janela de manutenção comunicada ao cliente piloto (seção 8).

## 12. Monitoramento e alertas

Escopo desta seção: erros do **sistema**, percebidos pelo **admin do sistema** (exceções, bugs, falhas de integração e indisponibilidade). Eventos de negócio da empresa cliente, como certificado digital vencendo, são notificações dentro do próprio sistema e não entram aqui.

Princípio: começar simples e evoluir aos poucos. Cada etapa só entra quando a anterior estiver funcionando.

### 12.1 Níveis e destino

| Nível | Exemplos | Destino |
|---|---|---|
| **Grave** | Erro 500 em emissão ou cancelamento, job de NF-e falhando em lote, banco ou Redis fora do ar, backup que falhou, API fora do ar | E-mail ao admin na hora |
| **Médio / simples** | Exceção isolada em tela não crítica, warnings, validação inesperada, timeout pontual da SEFAZ | Arquivo de log, revisado manualmente |

Um erro só vira "grave" por regra explícita (rota, job ou código de erro listado). Não por frequência ou por quem o gerou.

### 12.2 Logs

- Arquivos JSON, uma linha por evento, gerados pelo Monolog do Laravel nas duas APIs.
- Rotação diária, retenção de 30 dias no VPS.
- Análise na máquina local: cópia periódica com `rsync` e leitura com `grep`, `jq` ou DuckDB.
- Cada linha traz o ID da requisição ou da emissão, para cruzar com o registro fiscal sem copiar o conteúdo.
- Proibido no log: XML, certificado, senha, CPF e CNPJ de cliente. Ver seção 8.

### 12.3 Disponibilidade (ping)

- Uma máquina local (a do desenvolvedor) faz `ping` HTTP no endpoint de saúde da API a cada 5 minutos, via `cron`.
- O endpoint de saúde verifica pelo menos banco e Redis, não só se o processo responde. Ver pendência na seção 11.3.
- Após **3 falhas seguidas** (15 minutos), envia e-mail **grave** ao admin. Ao voltar a responder, envia e-mail de recuperação.
- **Limitação:** o alerta só existe com a máquina local ligada e conectada à internet. Se ela estiver desligada, não há alerta. Aceitável na Fase 0. Quando houver mais de um admin, ou quando o ping local falhar mais de uma vez, migrar para um monitor externo (seção 12.6).

### 12.4 Envio de e-mail

- Usar serviço transacional (Amazon SES, Mailgun ou Resend), não o SMTP do VPS. E-mail saindo de IP de VPS tende a cair no spam.
- O mesmo envio serve ao ping local e à aplicação.
- Limitar a um e-mail por erro a cada 30 minutos, com contagem de ocorrências no corpo, para evitar enxurrada.

### 12.5 Regras

- E-mail e log não recebem dado sensível do cliente. O corpo do alerta traz tipo do erro, rota ou job, ID interno e horário.
- O admin decide o que é grave. Esta lista deve ser revista a cada mudança relevante.

### 12.6 Evolução, em etapas

1. **Agora:** ping local com e-mail grave, logs em arquivo copiados para a máquina local.
2. **Próxima:** verificações básicas no VPS (disco, fila de envio à SEFAZ) com alerta grave acima do limite. Disco acima de 70% (seção 6) vira aviso no log; acima de 90%, e-mail grave.
3. **Quando justificar** (mais de um admin, ou ping local falhando): monitor externo de disponibilidade e, se o volume de erros crescer, ferramenta de agregação de erros.

### 12.7 Pendências desta seção

- Escolher o serviço transacional de e-mail (SES, Mailgun ou Resend).
- Listar as rotas, jobs e códigos de erro considerados graves.
- Confirmar se a máquina local roda 24 horas. Se não, o ping só cobre o horário em que ela estiver ligada.
- Definir o endpoint de saúde (já pendente na seção 11.3).
