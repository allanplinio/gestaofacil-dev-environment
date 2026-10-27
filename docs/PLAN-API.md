# PLAN-API.md — GestãoFácil API (Laravel)

**Documentos Relacionados:**
- [`REQUISITOS.md`](./REQUISITOS.md) — Escopo funcional v1
- [`DATA-MODEL.md`](./DATA-MODEL.md) — Schema completo (migrations, fields, indices)
- [`PLAN-UI.md`](./PLAN-UI.md) — Telas e fluxos (sincronizado com fases aqui)
- [`SECURITY.md`](./SECURITY.md) — Segurança de senhas, multitenancy, testes

Este plano assume as regras de negócio descritas em `REQUISITOS.md`. Cada fase é
dimensionada pra caber numa sessão curta — feche cada fase com commit, atualize
`PROGRESS.md` com 3-5 linhas, e não recarregue este documento inteiro na sessão seguinte,
só referencie a fase atual.

Convenção de teste: toda fase com endpoint/regra de negócio termina com testes de
request/feature (Pest), seguindo o mesmo padrão usado na API de NFe.

**Alinhamento com DATA-MODEL.md:**
- Cada migration descrita aqui corresponde a uma tabela em DATA-MODEL.md
- Campos mencionados estão documentados com tipos, constraints e índices em DATA-MODEL.md
- GlobalScope `CompanyScope` deve ser aplicado em TODAS as models listadas

---

## 💾 ESTRATÉGIA DE CACHE

**Objetivo:** Reduzir carga de banco de dados e melhorar performance sem sacrificar consistência.

### Cache Strategy por Recurso

#### 1. **Produtos (Cache Agressivo — 1 hora)**
```php
Cache::remember("empresa:{$empresa_id}:produtos", 3600, function() {
    return Produto::all()->keyBy('id'); // Indexado por ID
});
```
- Invalidar quando: `Produto` criado/atualizado/deletado/inativado
- TTL: 1 hora (mudanças de preço não são críticas)
- Benefício: Buscas rápidas em PDV/Pedido

**Invalidação:**
```php
// Em ProdutoService
Cache::forget("empresa:{$empresa_id}:produtos");
```

#### 2. **Clientes (Cache Moderado — 30 min)**
```php
Cache::remember("empresa:{$empresa_id}:clientes", 1800, function() {
    return Cliente::all()->keyBy('id');
});
```
- TTL: 30 minutos
- Invalidar quando: Cliente criado/atualizado
- Benefício: Autocomplete de cliente é rápido

#### 3. **Configuração Fiscal (Cache Permanente com Manual Invalidation)**
```php
Cache::rememberForever("empresa:{$empresa_id}:fiscal", function() {
    return ConfiguracaoFiscal::where('empresa_id', $empresa_id)->first();
});
```
- TTL: Permanente (até invalidar manualmente)
- Invalidar quando: Certificado upload, mudança de ambiente
- Benefício: Usado em TODA emissão de NFe

**Invalidação:**
```php
// Em ConfiguracaoFiscalService
Cache::forget("empresa:{$empresa_id}:fiscal");
```

#### 4. **Planos (Cache Permanente — Muda Raramente)**
```php
Cache::rememberForever('planos:all', function() {
    return Plano::all()->keyBy('id');
});
```
- TTL: Permanente
- Invalidar quando: Admin cria/edita plano (raro)
- Benefício: Validação de limites é O(1)

**Invalidação:**
```php
// Em PlanoService (raro)
Cache::forget('planos:all');
```

#### 5. **Estoque (Cache REGRESSIVO — Curto TTL)**
```php
// Produto individual
Cache::remember("produto:{$produto_id}:estoque", 60, function() {
    return $produto->estoque_atual;
});
```
- TTL: 60 segundos (CURTO — estoque muda frequentemente)
- Invalidar quando: Venda criada/cancelada, movimentação lançada
- Benefício: Evita lock contention no banco

**Invalidação:**
```php
// Em EstoqueService::lancar()
Cache::forget("produto:{$produto_id}:estoque");
```

#### 6. **Tokens de API (Cache + Validation)**
```php
// Token da API nfe-api (criptografado)
$token = Cache::remember("empresa:{$empresa_id}:nfe_api_token", 86400, function() {
    return Crypt::decryptString(
        ConfiguracaoFiscal::findOrFail($empresa_id)->nfe_api_token_id
    );
});
```
- TTL: 24 horas (minimizar decrypts)
- Invalidar quando: Token renovado
- Benefício: Decryption é custoso, cache fica seguro

### Driver de Cache Recomendado

```env
# .env
CACHE_DRIVER=redis # Não use file() — lento em produção
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=1
```

**Por quê Redis:**
- Rápido (in-memory)
- Suporta TTL automático
- Compartilhado entre workers (Laravel Horizon)
- Data types avançados (SET, HASH, LIST)

### Cache Tags (Invalidação em Batch)

```php
// Em vez de cache individual, usar tags
Cache::tags(["empresa:{$empresa_id}", 'products'])->remember(
    "produtos:all",
    3600,
    fn() => Produto::all()
);

// Invalidar todos os caches da empresa
Cache::tags("empresa:{$empresa_id}")->flush();

// Invalidar só produtos
Cache::tags('products')->flush();
```

### Monitoramento de Cache

```php
// tests/Feature/CacheTest.php
public function test_cache_invalidation_on_product_create() {
    Cache::set("empresa:1:produtos", ['id' => 1]);
    
    Produto::factory()->for($empresa)->create();
    
    $this->assertNull(Cache::get("empresa:1:produtos"));
}
```

### Consistência de Cache (Critical Path)

**Cenário:** Usuário cria Cliente e logo em seguida faz Venda com esse cliente. Vai funcionar?

**Resposta: SIM, sempre funciona.**

**Por quê:**

1. **Quando cliente é criado:**
   ```php
   // ClienteController::store()
   $cliente = Produto::create([...]);
   
   // Invalidar cache IMEDIATAMENTE
   Cache::forget("empresa:{$empresa_id}:clientes");
   
   // Retornar cliente criado
   return $cliente;
   ```

2. **Quando venda tenta usar cliente:**
   ```php
   // VendaController::show() ou validação
   $cliente = Cliente::findOrFail($cliente_id); // SEMPRE do banco
   
   // Ou se usar cache:
   Cache::remember("empresa:{$empresa_id}:clientes", 1800, fn() => Cliente::all());
   // Cache foi invalidado no passo 1, então reconstrói com novo cliente
   ```

3. **Garantia:**
   - Invalidação é SÍNCRONA (mesmo request que criou)
   - Próxima leitura vai do banco ou preenche cache limpo
   - Sem delay, sem race condition

**Casos Cobertos:**

| Cenário | Resultado | Motivo |
|---------|-----------|--------|
| Criar cliente → venda imediata | ✅ Funciona | Cache invalidado antes de responder |
| Criar produto → pedido imediato | ✅ Funciona | Cache invalidado antes de responder |
| Criar cliente → outro user vê imediato | ✅ Funciona | Cache foi limpo, próxima busca vai no banco |
| Cache miss (nunca acessou) | ✅ Funciona | Busca vai direto no banco, sem cache |
| Múltiplos usuários criam cliente | ✅ Funciona | Cada criação invalida, banco é source of truth |

**Testes (Obrigatório na Fase 3+):**
```php
public function test_cliente_criado_aparece_imediato_em_venda() {
    $empresa = Empresa::factory()->create();
    $usuario = User::factory()->for($empresa)->create();
    
    // Usuário 1: Cria cliente
    $this->actingAs($usuario)->post('/api/clientes', [
        'nome' => 'Novo Cliente'
    ])->assertStatus(201);
    
    // Usuário 2: Tenta venda com cliente novo
    $cliente_id = Cliente::latest()->first()->id;
    
    $response = $this->actingAs($usuario)->post('/api/vendas', [
        'cliente_id' => $cliente_id,
        'itens' => [...],
        'total' => 100
    ]);
    
    // DEVE FUNCIONAR
    $this->assertEquals(201, $response->status());
}

public function test_produto_criado_aparece_imediato_em_pedido() {
    $empresa = Empresa::factory()->create();
    $usuario = User::factory()->for($empresa)->create();
    
    // Cria produto
    $this->actingAs($usuario)->post('/api/produtos', [
        'nome' => 'Novo Produto',
        'preco_venda' => 100
    ])->assertStatus(201);
    
    // Tenta venda com produto novo
    $produto_id = Produto::latest()->first()->id;
    
    $response = $this->actingAs($usuario)->post('/api/vendas', [
        'cliente_id' => 1,
        'itens' => [['produto_id' => $produto_id, 'quantidade' => 1]],
        'total' => 100
    ]);
    
    // DEVE FUNCIONAR
    $this->assertEquals(201, $response->status());
}
```

### Checklist de Cache

- [ ] Produtos: 1h TTL, invalidar on CRUD
- [ ] Clientes: 30min TTL, invalidar on CRU
- [ ] Invalidação: SÍNCRONA no mesmo request que criou
- [ ] Testes: validar race conditions não causam stale data
- [ ] Configuração Fiscal: permanente, invalidar on upload/ambiente
- [ ] Planos: permanente, invalidar on admin edit
- [ ] Estoque: 60s TTL, invalidar on venda/movimentação
- [ ] Tokens: 24h TTL, invalidar on renew
- [ ] Cache driver: Redis (não file)
- [ ] Verificar que criaturas aparecem imediatamente em operações subsequentes

---

## 🔒 SEGURANÇA MULTITENANCY — PRIORIDADE CRÍTICA

**Princípio inviolável:** Uma empresa NUNCA pode acessar dados de outra empresa, independentemente do exploit ou misconfiguration.

### Arquitetura de Isolamento (obrigatório em TODAS as fases)

1. **Middleware de Escopo Automático** (`EnscopeToCompany` middleware)
   - Aplicado GLOBALMENTE em rotas autenticadas
   - Extrai `empresa_id` do usuário autenticado via `Auth::user()->empresa_id`
   - Adiciona constraint automático a TODAS as queries: `.where('empresa_id', $empresa_id)`
   - **NUNCA** confiar em filtro manual em controller — middleware é obrigatório

2. **Modelos com Escopo Padrão** (Laravel query scopes)
   - Toda model de negócio (Produto, Cliente, Venda, etc.) define `static function booted()` com:
     ```php
     static::addGlobalScope(new CompanyScope);
     ```
   - CompanyScope automaticamente filtra por `empresa_id` mesmo em queries raw
   - Nunca escrever `.all()` ou `.get()` direto — sempre vai vir com filtro

3. **Testes de Vazamento Obrigatórios** (TODAS as fases)
   - Criar 2 empresas distintas com dados diferentes
   - Para CADA novo endpoint/model, validar:
     - Usuário de Empresa A NÃO vê dados de Empresa B
     - Endpoints retornam 403 ou 404 (nunca 200 com dados errados)
     - Queries raw com `toSql()` mostram `.where('empresa_id', ?)` presente
   - Teste deve falhar propositalmente SEM o escopo (verificar que middleware faz diferença)

4. **Campos Sensíveis Protegidos**
   - `senha_certificado`: NUNCA persiste em GestãoFácil (fica só na API nfe-api, criptografada)
   - Arquivo `.pfx`: NUNCA persiste em GestãoFácil (fica só na API nfe-api, em diretório privado do servidor)
   - IE, IM, CRT, `cMun`, CNAE, CSC, série e numeração: NUNCA persistem em GestãoFácil — ver "Fronteira de Dados" abaixo
   - `token_api_nfe`: Armazenar criptografado com key por empresa, nunca em log
   - `email`: Validar que email de Empresa A não aparece em queries de Empresa B

5. **Fronteira de Dados entre GestãoFácil e nfe-api** (ver [SECURITY.md](SECURITY.md))
   - A API de Vendas só guarda o que é comercial/operacional: razão social, nome fantasia,
     CNPJ/CPF, endereço, e-mail comercial, plano, usuários, clientes, produtos e vendas
   - Tudo que é fiscal da emissão vive só no `nfe-api`: `.pfx`, senha do certificado, IE, IM,
     CNAE, CRT, `cMun`, CSC, série e sequência numérica das notas
   - Exceção controlada: espelho somente-leitura de `cnpj_certificado`,
     `certificado_validade`, `status_certificado` e `ambiente`, sincronizado do `nfe-api`
   - O upload de certificado é **proxy sem persistência**: a API de Vendas repassa o corpo
     da requisição e grava apenas o retorno de status
   - Teste obrigatório: `Schema::hasColumn('configuracoes_fiscais', ...)` confirma que as
     colunas fiscais proibidas não existem

5. **Endpoints com Validação Dupla** (exemplo: PATCH /empresas/{id}/certificado)
   - Validar que `:id` pertence à empresa do usuário autenticado
   - Exemplo:
     ```php
     $empresa = Empresa::findOrFail($id); // vai com escopo automático via middleware
     if ($empresa->id !== Auth::user()->empresa_id) abort(403); // validação explícita como fallback
     ```

### Cenários de Ataque (devem ser bloqueados)

- [ ] **ID Tampering:** Usuário de Emp A tenta `GET /produtos/123` onde 123 é de Emp B
  - Resultado esperado: 404 (não encontrado, porque scope filtra automaticamente)

- [ ] **Bulk Operations:** Usuário tenta `PATCH /produtos/bulk` passando IDs de empresas diferentes
  - Resultado esperado: 422 (validação falha porque scope rejeita)

- [ ] **SQL Injection na empresa:** Atacante tenta injetar SQL pra contornar filtro
  - Resultado esperado: Query parametrizado com ?, não concatenação direta

- [ ] **Token Replay:** Atacante captura token de Emp A, tenta usar com Emp B
  - Resultado esperado: Falha porque Sanctum vincula token à sessão/usuário específico

- [ ] **Webhook Malicioso:** API nfe-api envia webhook com `cnpj` diferente do esperado
  - Resultado esperado: GestãoFácil valida que `cnpj` pertence a alguma empresa conhecida antes de atualizar

### Responsabilidade por Fase

- **Fase 1:** Middleware base + teste de vazamento entre 2 empresas
- **Fase 3+:** CADA nova model/endpoint DEVE ter teste de vazamento adicionado
- **Fase 6:** Webhook receiver valida CNPJ contra empresas conhecidas
- **Testes:** Se testes não incluem validação multitenancy, NÃO MERGE

---

---

## Fase 0 — Fundação do projeto

- [ ] Laravel 11 + Docker Compose (app, worker, db, redis) — reaproveitar padrão de nfe-api
- [ ] Sanctum para autenticação (login humano, não M2M)
- [ ] `.env.example` com variáveis: DB, Redis, URL + token da API de NFe
- [ ] Pest PHP configurado

- [ ] **Configuração de Segurança de Senhas (CRÍTICO):**
  - [ ] `config/hashing.php`: driver = **argon2id** (NÃO bcrypt!)
    - memory = 65536 (64MB)
    - time = 4 (iterações)
    - threads = 4 (parallelism)
  - [ ] Script de validação: `scripts/check-security.php` valida config
  - [ ] CI/CD: `.github/workflows/security.yml` roda validação antes de deploy
  - [ ] Testes: validar que hashes SÃO Argon2ID (começam com `$argon2id$`)

- [ ] Documentação: `SECURITY.md` com guia completo de senhas

- **Commit:** "chore: project skeleton com Argon2ID security"

---

## Fase 1 — Empresas e Usuários (multiempresa + login)

**Foco:** Isolamento de dados entre empresas com middleware automático.

- [ ] Migration `empresas` (razao_social, nome_fantasia, cnpj único, plano, ativo)
- [ ] Migration `users` (nome, email, senha, perfil, empresa_id)
- [ ] Model `Empresa` com `hasMany(User::class)`
- [ ] Model `User` com `belongsTo(Empresa::class)` + `belongsTo(Perfil::class)`

- [ ] **Middleware de Escopo Multiempresa** (`EnscopeToCompany`):
  - Aplicado em `api` route group (GLOBAL para rotas autenticadas)
  - Extrai `empresa_id` de `Auth::user()->empresa_id`
  - Adiciona `.where('empresa_id', $empresa_id)` automaticamente a toda query
  - Não pode ser skipado manualmente (sempre ativo)

- [ ] **Global Query Scope** (`CompanyScope`):
  - Criar classe `app/Models/Scopes/CompanyScope.php`
  - Aplicar a TODAS as models de negócio (ver Fase 3+)
  - Exemplo: `Produto::all()` retorna só produtos da empresa logada, mesmo sem `.where()`

- [ ] Endpoint `POST /login` com Sanctum + Rate Limiting (5 tentativas/1min)
  - Validação de empresa ativa (`empresa.ativo = false` → bloqueia)
  - Resposta: token Sanctum + empresa_id

- [ ] Endpoint `POST /logout` (limpa token)

- [ ] Endpoint `POST /password/forgot` (Recuperação de Senha)
  - Recebe email
  - Gera token aleatório (64 chars) com expiração 24h
  - Envia email com link `/password/reset?token=...`
  - Token é hash('sha256') no banco (não plaintext)

- [ ] Endpoint `POST /password/reset` (Alterar Senha via Token)
  - Recebe token + nova_senha + confirmação
  - Valida token: existe, hash bate, não expirado (< 24h)
  - Hash com Argon2ID (configurado em Fase 0) e atualiza
  - Deleta token após uso (1 uso apenas)
  - Invalida todos os tokens/sessões existentes do usuário

- [ ] Validação de Força de Senha (OBRIGATÓRIO):
  - Mínimo 8 caracteres
  - Maiúscula + minúscula
  - Pelo menos 1 número
  - Pelo menos 1 símbolo (!@#$%^&*)
  - Validar contra haveibeenpwned.com (senhas comprometidas)

- [ ] **Testes de Multitenancy (vazamento entre empresas):**
  - Criar 2 empresas Emp A e Emp B
  - Login Emp A retorna token
  - Token Emp A + `GET /empresas` → só dados Emp A
  - Token Emp A + `GET /empresas/{B_id}` → 404
  - SQL `.toSql()` mostra `.where('empresa_id', ?)`

- [ ] **Testes de Segurança de Senha (CRÍTICO):**
  - Senha bcrypt: `$user->password !== 'minha-senha'` (hashed)
  - Validação força: senha com < 8 chars rejeitada (422)
  - Validação força: sem número rejeitada (422)
  - Validação força: sem símbolo rejeitada (422)
  - Rate limiting: 6ª login attempt em 1 min → 429 Too Many Requests
  - Reset token expira 24h (teste com `created_at` > 24h)
  - Reset token uso único (tentar usar 2x: 1ª OK, 2ª 401)
  - Reset invalida todas as sessões do usuário
  - Senha NUNCA aparece em response ou logs

- [ ] **Documentação:**
  - Criar `SECURITY.md` (multitenancy + senhas)
  - Checklist por fase para segurança
  - Cenários de ataque bloqueados

- **Commit:** "feat: multi-tenant com middleware + segurança de senha (bcrypt, rate-limit, reset)"

---

## Fase 2 — Configuração Fiscal (por empresa)

**Princípio desta fase:** a API de Vendas é um *proxy sem persistência* para a configuração
fiscal. Ela não guarda `.pfx`, senha, IE, IM, CRT, `cMun`, CNAE, CSC, série nem numeração —
apenas o espelho de status. Ver "Fronteira de Dados" em [SECURITY.md](SECURITY.md).

- [ ] Migration `configuracoes_fiscais` — **apenas campos de espelho e integração**:
  - `empresa_id` (unique), `ambiente`, `status_certificado`, `cnpj_certificado`,
    `certificado_validade`, `last_certificate_check`, `nfe_api_token_id` (criptografado)
  - ❌ **Não criar:** `certificado_path`, `senha_certificado`, `emitente`, `serie`,
    `numero_inicial_nfe`, `numero_inicial_nfce`, `inscricao_estadual`, `crt`,
    `codigo_municipio`, `cnae`, `csc`, `csc_id`

- [x] **Dívida corrigida em 2026-09-20** (era: o schema violava a fronteira). Era assim:
  `configuracoes_fiscais` tem `certificado_path`, `senha_certificado`, `emitente` e
  `serie` (migrations `2026_09_15_160000` e `2026_09_17_000000`), e o
  `ConfiguracaoFiscalController` grava o `.pfx` em `Storage::disk('private')`. Tarefas:
  - [ ] Migration de correção que faz `dropColumn` dessas colunas
  - [ ] Migration/comando que apaga os `.pfx` já gravados no disco da API de Vendas
        (após confirmar que estão cadastrados no `nfe-api`)
  - [ ] Remover os campos do `$fillable` de `ConfiguracaoFiscal` e do `UpdateConfiguracaoFiscalRequest`
  - [ ] Remover a escrita em `Storage` do `ConfiguracaoFiscalController`

- [ ] Model `ConfiguracaoFiscal` com:
  - `belongsTo(Empresa::class)`
  - **Global scope** `CompanyScope` aplicado automaticamente
  - Campos de espelho marcados como somente-leitura para o usuário (só o sincronizador escreve)

- [ ] Cliente HTTP pra API de NFe (`NfeApiClient` — service que encapsula chamadas)
  - Métodos: `uploadCertificado()`, `atualizarEmitente()`, `trocarAmbiente()`, `emitir()`,
    `consultarStatus()`, `cancelar()`, `inutilizar()`
  - NUNCA persiste `.pfx` nem senha de certificado (ficam só na API nfe-api)
  - Token de API armazenado criptografado com `Crypt::encryptString()`

- [ ] Endpoint `POST /empresas/{id}/certificado` — **proxy sem persistência**:
  - Validar que `{id}` pertence à empresa do usuário autenticado e que o perfil é Administrador
  - Recebe `.pfx` + senha + dados do emitente (IE, IM, CNAE, CRT, endereço, CSC) + série e
    numeração inicial, e repassa tudo para `POST /v1/certificados` e
    `PUT /v1/certificados/{cnpj}/emitente` do nfe-api
  - Grava na `ConfiguracaoFiscal` **apenas** `cnpj_certificado`, `certificado_validade`,
    `status_certificado` e `ambiente` a partir da resposta
  - Nada do payload vai para log, disco ou tabela de auditoria

- [ ] Endpoint `PATCH /empresas/{id}/certificado/ambiente` — troca sem reenviar certificado
  (chama `PATCH /v1/certificados/{cnpj}/ambiente` e atualiza só o espelho)

- [ ] Job de sincronização do espelho (`SyncCertificateStatus`) — lê status do nfe-api e
  atualiza `status_certificado`, `certificado_validade`, `ambiente`, `last_certificate_check`

- [ ] **Testes de request (COM VALIDAÇÃO MULTITENANCY):**
  - Emp A tenta `POST /empresas/{B_id}/certificado` → 403/404 (acesso negado)
  - Emp A tenta `PATCH /empresas/{B_id}/certificado/ambiente` → 403/404
  - Upload de certificado chama API corretamente (usar `Http::fake()`)
  - Troca de ambiente não reenvia senha (validar que payload não tem `password`)
  - Falha da API é repassada como erro claro

- [ ] **Testes de fronteira de dados (NOVOS — bloqueiam merge):**
  - `test_api_de_vendas_nao_tem_colunas_fiscais()` — `Schema::hasColumn()` falso para
    `certificado_path`, `senha_certificado`, `emitente`, `serie`, `numero_inicial_nfe`,
    `numero_inicial_nfce`, `inscricao_estadual`, `crt`, `codigo_municipio`, `cnae`, `csc`
  - `test_certificado_nunca_persistido_localmente()` — com `Storage::fake('private')`,
    `allFiles()` fica vazio após o upload
  - Senha não aparece em nenhuma coluna da linha de `configuracoes_fiscais`
  - Payload do upload não aparece em log (`Log::spy()`)

- [ ] **Checklist Multitenancy:**
  - [ ] `ConfiguracaoFiscal` model tem `CompanyScope`
  - [ ] Endpoints validam `:id` pertence à empresa logada
  - [ ] Queries usam `.toSql()` pra confirmar `.where('empresa_id')`
  - [ ] Senhas/tokens NUNCA aparecem em logs

- **Commit:** "feat: fiscal config as stateless proxy to nfe-api (data boundary)"

---

## Fase 3 — Produtos e Estoque

- [ ] Migration `produtos` (empresa_id, nome, sku, codigo_barras, preco_compra, preco_venda, ncm, unidade, estoque_atual, ativo)
  - **Nota:** Sem limite de quantidade de produtos cadastrados (ilimitado em todos os planos)
- [ ] Migration `estoque_movimentacoes` (produto_id, tipo[entrada|saida|ajuste], quantidade, motivo, created_at)
- [ ] `EstoqueService::lancar()` — único ponto que cria movimentação E atualiza `estoque_atual` (nunca alterar `estoque_atual` direto em outro lugar do código)
- [ ] `EstoqueService::estornar()` — usado no cancelamento de venda
- [ ] CRUD de produtos (Create, Read, Update, Delete)
  - `POST /produtos` — criar
  - `GET /produtos` — listar com filtro `ativo` (default: true)
  - `GET /produtos/{id}` — detalhe
  - `PATCH /produtos/{id}` — editar (inclusive campo `ativo` toggle)
  - `DELETE /produtos/{id}` — deletar (soft delete ou hard delete)
  
- [ ] Campo `ativo` no formulário de edição (toggle)
  - Não precisa endpoint separado para inativar
  - Editando produto, usuário marca `ativo: false`
  - Simplifica API (menos endpoints)
- [ ] **Testes de request:**
  - criar produto, editar, inativar
  - produto inativo não aparece em busca padrão
  - produto inativo pode aparecer em pedido já criado (aviso, mas permitir pré-venda)
  - lançar movimentação de entrada/saída atualiza `estoque_atual` corretamente
  - ajuste manual exige motivo
  - produto de uma empresa não aparece na busca de outra empresa
- **Commit:** "feat: produtos and estoque with movement history"

---

## Fase 4 — Clientes

- [ ] Migration `clientes` (empresa_id, nome, cpf_cnpj?, telefone?, email?, endereco?)
- [ ] CRUD de clientes
- [ ] **Testes de request:**
  - criar cliente com dados mínimos (só nome)
  - cliente de uma empresa não aparece pra outra
- **Commit:** "feat: clientes CRUD"

---

## Fase 5 — Vendas (PDV com NFC-e + Pedido com NF-e)

**Nota:** v1 implementa AMBOS:
- **PDV** com origem `pdv`, tipo_documento **OBRIGATORIAMENTE `nfce`** (modelo 65, B2C)
- **Pedido** com origem `pedido`, tipo_documento pode ser `nfe` (modelo 55, B2B), `cupom_nao_fiscal`, ou `nenhum`

**Diferenças Críticas PDV vs Pedido:**

| Aspecto | PDV | Pedido |
|--------|-----|--------|
| **Origem** | `pdv` | `pedido` |
| **Tipo de Doc** | `nfce` (modelo 65) — **OBRIGATÓRIO** | `nfe` (modelo 55) — opção de cupom ou nenhum |
| **Fluxo** | Criar + Emitir **na mesma ação** (rápido) | Criar (`em_aberto`) → Depois emitir (manual) |
| **Cliente** | Consumidor Final (obrigatório) | Cliente B2B (obrigatório) |
| **Pagamento** | Múltiplas formas na mesma venda | Múltiplas formas na mesma venda |
| **Estoque** | Lançar estoque = marcar venda como atendida | Lançar estoque é ação separada |
| **UX** | < 1 minuto de transação | Administrativo, sem pressa |

**Dependência crítica:** API nfe-api DEVE suportar NFC-e (modelo 65) antes de GestãoFácil lançar v1.

- [ ] Migration `vendas` (empresa_id, cliente_id, usuario_id, origem[pdv|pedido], tipo_documento[nfe|nfce|nenhum], situacao[em_aberto|atendido|cancelado], total, estoque_lancado_em?)
  - **Lógica de tipo_documento por origem:**
    - **PDV** (`origem='pdv'`): tipo_documento **SEMPRE `nfce`** (modelo 65 — NFC-e obrigatória, B2C)
    - **Pedido** (`origem='pedido'`): tipo_documento pode ser `nfe` (modelo 55 — padrão), `cupom_nao_fiscal`, ou `nenhum`
  - **Campos de rastreamento de NFe:**
    - `nf_protocolo_id` (UUID da API nfe-api, null até emitir)
    - `nf_chave_acesso` (string 44 dígitos, null até autorizar)
    - `nf_chave_acesso_anterior` (rastreia mudanças por contingência SVC)
    - `nf_environment` (1=produção, 2=homologação, herdado do certificado)
    - `nf_status` (queued|processing|authorized|rejected|cancelled, null até tentar emitir)
    - `nf_contingencia_ativa` (boolean)
    - `nf_xml_url` (URL do XML armazenado na API)
    - `nf_danfe_url` (URL do PDF armazenado na API)
- [ ] Migration `venda_itens` (venda_id, produto_id, quantidade, preco_unitario, desconto)
- [ ] Migration `venda_pagamentos` (venda_id, forma_pagamento, valor)
  - **Múltiplas formas de pagamento por venda:**
    - Exemplo: R$50 dinheiro + R$30 cartão crédito = R$80 total
    - Tabela `venda_pagamentos` armazena CADA forma separadamente
    - Não há limite de formas por venda (1..N)
    - Formas típicas: dinheiro, credito, debito, pix, boleto

- [ ] `VendaService::criarPedido()` — nasce com situação `em_aberto`

- [ ] **Validação de Pagamento:**
  - Regra: Σ(venda_pagamentos.valor) DEVE = vendas.total (exato)
  - Bloqueio: Soma diferente → erro 422, pedido não é atendido
  - Exemplo correto: [dinheiro: 50, cartão: 30] → total 80 ✅
  - Exemplo errado: [dinheiro: 50, cartão: 20] → total 80 ❌ (soma 70)
- [ ] Endpoint de mudança de situação do pedido (`em_aberto` → `atendido`, ou → `cancelado` a qualquer momento antes de `atendido`)
- [ ] Ao cancelar: se `estoque_lancado_em` não é nulo, chama `EstoqueService::estornar()` automaticamente
- [ ] Endpoint de "lançar estoque" da venda (ação explícita, separada da mudança de situação)
- [ ] Validação: permitir adicionar produto inativo em pedido (pré-venda válida), mas avisar via API
- [ ] **Testes de request:**
  - Pedido nasce em_aberto
  - pagamento com soma diferente do total é rejeitado (ou aceito como parcial, depender da decisão de negócio)
  - lançar estoque decrementa produto e marca `estoque_lancado_em`
  - cancelar venda com estoque já lançado gera estorno automático
  - cancelar venda sem estoque lançado não gera nenhuma movimentação
  - venda atendida não permite editar itens
- **Commit:** "feat: vendas (Pedido only) with stock and payment rules"

---

## Fase 6 — Emissão de NF-e (Integração com API nfe-api)

**Objetivo:** GestãoFácil envia venda atendida para emissão de NF-e via API nfe-api, aguarda resultado, mostra status.

- [ ] Service `NfeApiClient` — encapsula chamadas HTTP para API nfe-api:
  - `emitir(venda)` → `POST /api/v1/nfe` com dados da venda
  - `consultarStatus(protocolo_id)` → `GET /api/v1/nfe/{protocolo_id}` (polling)
  - `cancelar(protocolo_id, justificativa)` → `POST /api/v1/nfe/{protocolo_id}/cancelar`
  - `cartaCorrecao(protocolo_id, campo, valor)` → `POST /api/v1/nfe/{protocolo_id}/carta-correcao`
  - `inutilizar(cnpj, serie, numero_inicial, numero_final, motivo)` → `POST /api/v1/nfe/inutilizar`
  - Logging de todas as chamadas em `nfe_requests` table (auditoria)

- [ ] Webhook receiver: `POST /webhook/nfe` (assina com HMAC para validar que veio da API nfe-api)
  - Atualiza `vendas.nf_status`, `nf_chave_acesso`, `nf_danfe_url` com dados do webhook
  - Se `nf_chave_acesso_anterior` diferente de nova, marca `nf_contingencia_ativa=true`
  - Dispara notificação ao usuário: "Nota autorizada" / "Nota rejeitada"

- [ ] Endpoint `POST /vendas/{id}/emitir-nfe` — aciona emissão (comportamento diferente por origem)
  - **Para Pedido** (`origem='pedido'`):
    - Recebe: `tipo_comprovante` (nfe | cupom_nao_fiscal | nenhum)
    - Se `nfe`: emite NF-e via API nfe-api
    - Se `cupom_nao_fiscal`: gera apenas cupom não-fiscal (não envia à SEFAZ)
    - Se `nenhum`: apenas registra que foi escolhido "sem comprovante"
  - **Para PDV** (`origem='pdv'`):
    - Ignora parâmetro `tipo_comprovante` (sempre usa `nfce`)
    - Força emissão de NFC-e (modelo 65) automaticamente
  - Valida que venda está `atendido`
  - Valida que empresa tem certificado válido na API nfe-api (se emitir NF-e)
  - Chama `NfeApiClient::emitir(venda)` → recebe `protocolo_id` (se NF-e)
  - Persiste `nf_protocolo_id` e `nf_status=queued` (se NF-e)
  - Retorna 202 (aceito, em processamento)
  - **Não espera resultado** — webhook ou polling traz status depois

- [ ] Polling automático: Job `SyncNfeStatusJob` roda a cada 30s:
  - Para cada venda com `nf_status` em [queued, processing]
  - Chama `NfeApiClient::consultarStatus(protocolo_id)`
  - Atualiza status/chave/danfe se mudou
  - Para se chegar a `authorized` ou `rejected`

- [ ] Endpoint `GET /vendas/{id}/nfe-status` — retorna status atual (para polling manual se webhook falhar)

- [ ] **Testes de request (usando `Http::fake()` para mockar API nfe-api):**
  - emissão de venda válida → `nf_protocolo_id` preenchido, status `queued`
  - emissão de venda sem certificado → erro 403
  - webhook atualiza status corretamente
  - polling retorna status quando muda
  - mudança de chave por contingência marca `nf_contingencia_ativa`
  - venda rejeitada pode ser reenviada (endpoint permitir reset de nf_status)

- [ ] **Tratamento de erros da API nfe-api:**
  - 403: certificado não encontrado/inválido → msg clara pro usuário
  - 422: schema inválido → listar campos e erros específicos
  - 500: API fora → marcar como `nf_status=error`, permitir retry depois
  - Timeout da API → não deixar job travar, retentar com backoff exponencial

- **Commit:** "feat: NFe emission integration with nfe-api"

---

## Fase 7 — Cancelamento e Carta de Correção

**Objetivo:** Permitir cancelar nota autorizada ou emitir CC-e para erros não-críticos.

- [ ] Endpoint `POST /vendas/{id}/nfe/cancelar` (requer justificativa, valida prazo legal):
  - Valida que nota está `authorized`
  - Valida que autorização < 30 dias (prazo legal, pode ser variável por UF)
  - Chama `NfeApiClient::cancelar(protocolo_id, justificativa)`
  - Atualiza `nf_status=cancelled`, `situacao=cancelado`
  - Se estoque foi lançado, chama `EstoqueService::estornar()` automaticamente

- [ ] Endpoint `POST /vendas/{id}/nfe/carta-correcao`:
  - Recebe: `campo` (string do campo a corrigir), `valor_correto` (novo valor)
  - Valida que nota está `authorized`
  - Chama `NfeApiClient::cartaCorrecao(protocolo_id, campo, valor_correto)`
  - Marca `nf_carta_correcao_emitida=true`

- [ ] Endpoint `POST /empresas/{id}/inutilizar-numeracao`:
  - Recebe: `modelo` (55/65), `numero_inicial`, `numero_final`, `motivo`
  - Lê o CNPJ da empresa (`empresas.cnpj`) — **não** de um certificado local, que não existe aqui
  - Recebe também `serie` do usuário: ele precisa dizer de qual série é a faixa vaga
    (`POST /v1/certificados/{cnpj}/inutilizar` exige `serie`) — é parâmetro da operação,
    não configuração guardada nesta API
  - Chama `NfeApiClient::inutilizar(cnpj, serie, numero_inicial, numero_final, motivo)`
  - Registra em `nfe_inutilizacoes` table (auditoria)

- [ ] Migration `nfe_inutilizacoes` (empresa_id, cnpj, serie, numero_inicial, numero_final, motivo, criado_em)
  - `serie` aqui é auditoria do que foi pedido, não controle de numeração — a API de
    Vendas nunca incrementa, reserva ou decide o próximo número

- [ ] **Testes de request:**
  - cancelamento dentro do prazo → sucesso
  - cancelamento fora do prazo → erro com msg clara
  - CC-e sem justificativa → erro 422
  - inutilização de range é registrada

- **Commit:** "feat: NFe cancellation and correction letters"

---

## Fase 8 — Avisos Operacionais e Dashboard

- [ ] Job `CheckCertificateExpiration` — sincroniza validade de certificados com API nfe-api:
  - Roda diariamente
  - Para cada empresa, faz polling de status de certificado
  - Se < 30 dias: envia email "Certificado expira em N dias"
  - Se < 15 dias: aviso "URGENTE"
  - Se < 7 dias: aviso "CRÍTICO — renovar agora"
  - Guarda `last_notified_at` para não enviar duplicado no mesmo dia

- [ ] Endpoint `GET /dashboard/nfe` — resumo de NFe:
  - Notas autorizadas (hoje, este mês)
  - Notas rejeitadas (hoje)
  - Circuitos abertos? (se tiver, avisar)
  - Certificados a vencer
  - Taxa de sucesso (% de notas que autorizaram / total enviadas)

- [ ] UI mostra:
  - Badge "Homologação" em vermelho se `empresa.ambiente=2`
  - Aviso se certificado vence < 15 dias
  - Status real de cada nota (queued, processing, authorized, rejected)
  - Link pra download de XML/DANFE quando autorizada

- **Commit:** "feat: certificate monitoring and NFe dashboard"

---

## Fase 9 — Área do Usuário (Senha e Auditoria)

**Objetivo:** Permitir que usuários troquem sua própria senha com auditoria completa.

- [ ] Migration `password_change_history` (user_id, empresa_id, tipo, ip_address, user_agent, sucesso, motivo_falha)

- [ ] Endpoint `PATCH /users/me/password` — troca senha do usuário autenticado:
  - Recebe: `password_current`, `password_new`, `password_confirmation`
  - Valida que `password_current` bate com hash no banco
  - Valida que `password_new != password_current`
  - Valida força de senha (8+, maiús/minús, número, símbolo, não comprometida)
  - Valida que `password_new == password_confirmation`
  - Hash a nova senha com Argon2ID
  - Atualiza no banco
  - **LOG EM password_change_history:**
    - Sucesso: `tipo='alteracao', sucesso=true, ip=..., user_agent=...`
    - Falha: `tipo='alteracao', sucesso=false, motivo='senha_atual_incorreta'|'senha_fraca'|'senha_comprometida'|...`
  - Invalida todas as outras sessões/tokens do usuário (força re-login)
  - Retorna 200 com mensagem de sucesso

- [ ] **Testes de request:**
  - senha atual incorreta → 422, auditado com `motivo='senha_atual_incorreta'`
  - nova senha igual à antiga → 422, auditado com `motivo='senha_igual_anterior'`
  - confirmação não bate → 422, auditado com `motivo='confirmacao_nao_bate'`
  - senha fraca (< 8 chars) → 422, auditado com `motivo='senha_fraca'`
  - senha comprometida (haveibeenpwned) → 422, auditado com `motivo='senha_comprometida'`
  - sucesso → 200, auditado com `sucesso=true`, usuário pode fazer login com nova senha
  - após sucesso, tokens antigos são invalidados (usuário precisa fazer login novamente)

- [ ] **Endpoint de histórico (opcional em v1, preparar estrutura):**
  - `GET /users/me/password-history` — últimas 5 alterações de senha
  - Retorna: tipo, data, ip, status (sucesso/falha)
  - Sem mostrar hashes ou senhas

- **Commit:** "feat: user password change with audit trail"

---

## Fase 10 — Gestão de Usuários (Administrador)

**Objetivo:** Administrador pode criar, editar, inativar usuários da empresa.

- [ ] Endpoint `GET /users` — lista usuários da empresa:
  - Filtro: perfil, status (ativo/inativo)
  - Retorna: id, nome, email, perfil, status, criado_em

- [ ] Endpoint `POST /users` — cria novo usuário (apenas Administrador):
  - Recebe: nome, email, perfil
  - Valida email único por empresa
  - Gera token de "definir senha" com expiração 24h
  - Persiste `password_reset_token` + `password_reset_expires_at` no banco
  - Envia email com link: `/password-reset?token=[token]`

- [ ] Endpoint `PATCH /users/{id}` — edita usuário (apenas Administrador):
  - Pode alterar: nome, perfil, status (ativo/inativo)
  - Não pode alterar email direto (futuro: verificação de email)
  - Inativar usuário não deleta, só marca `ativo=false`

- [ ] Endpoint `POST /password-reset` — usuário novo define senha via link de email:
  - Recebe: token, nova_senha, confirmação
  - Valida token e expiração
  - Se token expirado: erro 401 "Link de convite expirou, solicite um novo"
  - Se sucesso: limpa token, define senha, marca `password_set_at`, redireciona pra login

- [ ] **Testes de request:**
  - listar usuários (Administrador OK, Vendedor 403)
  - criar usuário envia email com token válido
  - token expirado após 24h
  - usuário novo pode fazer login depois de definir senha
  - inativar usuário bloqueia login

- **Commit:** "feat: user management (create, edit, password reset)"

---

## Fase 11 — Perfis e Permissões

**Objetivo:** Implementar autorização por perfil (Administrador, Operador, Vendedor).

- [ ] Middleware `CheckRole` que valida se usuário tem permissão para ação:
  - Aplicado em rotas sensíveis (ex: `Route::middleware('auth:sanctum', 'role:admin')->get(...)`)

- [ ] Permissões por perfil:
  - **Administrador:** acesso total
  - **Operador:** Produtos (CRUD), Clientes (CRUD), Vendas (CRUD), Dashboard — sem acesso a Configuração Fiscal
  - **Vendedor:** Produtos (apenas leitura), Clientes (criar, próprios), Vendas (criar próprias/pedidos), Dashboard (apenas próprias)

- [ ] Endpoints de autorização:
  - Configuração Fiscal → `role:admin`
  - Gestão de Usuários → `role:admin`
  - Inativar Produto → `role:admin|operador`
  - Lançar Estoque → `role:admin|operador`
  - Criar Pedido → `role:admin|operador|vendedor`

- [ ] Escopo automático em queries:
  - Vendedor só vê próprios pedidos, clientes criados por ele, histórico suas vendas
  - Operador vê todos os dados da empresa
  - Administrador vê tudo + configurações

- [ ] **Testes de request:**
  - Vendedor acessa POST /vendas/criar → 200
  - Vendedor acessa PATCH /produtos/{id} → 403
  - Vendedor não vê pedidos de outro vendedor
  - Operador não acessa POST /empresas/{id}/certificado → 403
  - Administrador acessa tudo

- **Commit:** "feat: role-based permissions middleware"

---

## Fase 12 — Planos e Preparação para Cobrança

**Objetivo:** Estruturar suporte a múltiplos planos com características (para futura cobrança).

- [ ] Migration `planos` (nome, preço_mensal, limite_vendas_por_mes?, limite_usuarios?, features)
  - **Nota:** Sem limite de quantidade de produtos cadastrados em nenhum plano
  - Exemplo: Plano Starter = R$99, 1000 vendas/mês, 2 usuários, produtos ilimitados
  - Exemplo: Plano Pro = R$299, ilimitado vendas, 5 usuários, produtos ilimitados

- [ ] Migration alterar `empresas`: adicionar `plano_id`, `proxima_cobranca` (null por enquanto)

- [ ] Model `Plano` com `hasMany(Empresa::class)`

- [ ] Endpoint `GET /planos` — lista planos disponíveis (público):
  - Retorna: nome, preço, features, recomendado (boolean)

- [ ] Endpoint `PATCH /empresas/{id}/plano` — upgrade/downgrade (apenas Administrador, com validação):
  - Recebe: `plano_id`
  - Valida que empresa existe e usuário é admin
  - Atualiza `empresas.plano_id`
  - Log de auditoria: "Empresa XYZ mudou pra Plano Pro em 2026-09-13"
  - (Futuro: integrar com Stripe/PagSeguro para cobrança)

- [ ] Endpoint `GET /empresas/me` — retorna dados da empresa logada + plano atual:
  - Incluir: razao_social, cnpj, plano, validade de certificado, quantidade de vendas (este mês)

- [ ] **Feature flags (backend ready, frontend hidden):**
  - Endpoints de plano existem e funcionam, mas UI não mostra seletor de plano em v1
  - Ou: botão [Upgrade] existe mas redireciona pra página com "Em breve"

- [ ] **Testes de request:**
  - upgrade de plano atualiza empresa
  - apenas Administrador pode fazer upgrade
  - listar planos funciona sem autenticação

- **Commit:** "chore: plan model and endpoints (feature flag ready)"

---

---

## Emissão Avulsa de NF-e/NFC-e (concluída em 22/09/2026)

Emitir uma nota **sem venda por trás**, pela tela `/notas/nova`. O fluxo antigo
(`/vendas/{id}/emitir`) continua existindo: as duas entradas montam o payload por caminhos
diferentes e compartilham envio, regra fiscal e tratamento de resposta.
Serviço de NF-e: `nfe-api/PLAN.md` Fase 14. Tela: `PLAN-UI.md`.

### Decisões

- **Nota sem venda.** `nfe_emissoes.venda_id` é opcional; `origem` (`venda`|`avulsa`) e `modelo`
  (55/65) identificam a nota. A lista `/notas` continua lendo essa tabela.
- **Formulário guardado em JSON** (`nfe_emissoes.formulario`), com `cliente_id` e `produto_id`.
  Serve para rascunho, correção de rejeitada e baixa/estorno de estoque. O payload enviado ao
  Serviço de NF-e continua em `xml_requisicao`.
- **Correções valem só para a nota.** Destinatário e itens saem de uma busca no cadastro; o que o
  usuário alterar (inclusive descrição, NCM e unidade) vai para a nota e **não** atualiza o
  cadastro de clientes nem de produtos.
- **Estoque só da nota avulsa** (a de venda já baixou na venda): baixa ao autorizar, estorno ao
  cancelar. Ponto único (`Services\Nfe\EstoqueDaNota`) chamado pelo webhook, pelo "consultar" e
  pelo cancelamento, com troca condicional de `estoque_lancado` — cada movimento acontece uma vez
  só. A nota já está autorizada na SEFAZ quando a baixa roda, então **falta de estoque não pode
  bloquear**: o estoque pode ficar negativo e a tela avisa antes de emitir.
- **Quantidade inteira**, como na venda: `produtos.estoque_atual` e
  `estoque_movimentacoes.quantidade` são inteiros, e arredondar na baixa seria silencioso.
- **Rejeitada é corrigida e reenviada na mesma nota**, mantendo série e número (ver Fase 14 do
  `nfe-api/PLAN.md`). Denegada não: a SEFAZ consome o número.
- **Descartar** inutiliza o número da nota rejeitada de que o usuário desistiu. Também vale para
  rejeitada vinda de venda, cujo número também fica sem uso.
- **Transportadora digitada na própria nota** (sem cadastro de transportadoras na v1).
- **Sem vendedor** na nota.

### Estados

```
  (nova) ──salvar──► rascunho ──excluir──► (removida)
     │                  │  ▲
     │ emitir           │  └─ editar / emitir
     └──────────────────┴──────► pendente
                                    │
          ┌─────────────────────────┼──────────────────────┐
          ▼                         ▼                      ▼
     autorizada                 rejeitada               denegada
   (baixa estoque,               │   │   ▲             (fim: número
    se avulsa)                   │   │   │              consumido)
          │ cancelar             │   │   └── inutilização recusada ──┐
          ▼                      │   │                               │
     cancelada                   │   └─ descartar ──► descartando ───┤
   (estorna estoque,             │                                   ▼
    se avulsa)                   └─ corrigir e reenviar          descartada
                                    (mesma série/número)
```

### Endpoints (`/nfe-emissoes`)

| Endpoint | O que faz |
|---|---|
| `GET /` | Lista com modelo, série/número, destinatário, total, origem e motivo resumido. `ids=` + `atualizar=1` consulta no Serviço de NF-e só as notas em andamento (funciona sem o webhook) |
| `GET /{id}` | Detalhe com formulário, histórico de tentativas e dados da inutilização (lidos na hora do Serviço de NF-e) |
| `POST /` | `acao=rascunho` grava sem validar e sem enviar; sem `acao`, valida e emite |
| `PATCH /{id}` | Edita o formulário. Só rascunho e rejeitada; na rejeitada, recusa troca de modelo e série |
| `POST /{id}/emitir` | Rascunho: primeiro envio. Rejeitada: reenvio |
| `POST /{id}/descartar` | Inutiliza o número da nota rejeitada (justificativa mínima de 15 caracteres) |
| `DELETE /{id}` | Exclui rascunho |
| `GET /{id}/xml-inutilizacao` | XML da inutilização da nota descartada |

Todas seguem o `CompanyScope` e têm teste de acesso entre empresas.

### Regras do envio

- **Validação antes de enviar:** `Services\Nfe\FormularioNotaAvulsa` repete as regras do
  `StoreNfeRequest` do Serviço de NF-e, mais as de configuração (certificado, série do modelo,
  natureza ativa, CSC na NFC-e). Os erros voltam **por campo do formulário**
  (`itens.1.ncm`, `destinatario.endereco.cep`), e o 422 do Serviço de NF-e é repassado no mesmo
  formato — a tela marca o campo em vez de mostrar um erro genérico.
- **Rateio** (`Services\Nfe\Rateio`): desconto total e frete são informados por item na NF-e.
  Distribuídos na proporção do valor de cada item, com os centavos que sobram no item de maior
  valor. Feito no backend para valer também para o fluxo de venda.
- **Clique duplo:** emitir troca o status de forma condicional no banco; o segundo pedido para a
  mesma nota recebe **409** e não chega ao Serviço de NF-e.
- **Tradução das rejeições** (`ErrorTranslationService`): códigos comuns da SEFAZ viram frase e
  campo do formulário; código sem tradução mantém o texto original, que continua visível no
  detalhe da nota.
- **Regra fiscal num lugar só** (`Services\Nfe\RegrasFiscais`): CFOP, ICMS, PIS/COFINS, série e
  formas de pagamento, usados pelas duas entradas.

### Correções na emissão que já existia (valem também para a venda)

- Status do Serviço de NF-e (`queued`/`authorized`/`rejected`) traduzido num ponto só, com os
  campos certos (`chave_acesso`, `numero`, `serie`). Antes a nota nunca saía de "pendente".
- **Natureza da venda é sempre "Venda de mercadoria"** (slug `venda`). Era "a primeira ativa" da
  lista, que vem em ordem alfabética: a venda saía como "Devolução de compra". A venda não tem
  onde escolher a natureza — quem escolhe é a tela de emissão avulsa. Se a natureza de venda
  estiver inativa, a emissão para com uma mensagem dizendo o que ativar.
- **Frente de loja emite NFC-e (modelo 65).** Os dois pontos de emissão do PDV passavam a string
  `'venda'` no parâmetro do modelo (`?int`), então a emissão falhava antes de começar e o erro só
  aparecia no log do checkout.
- Série passa a ser a configurada (era fixa em `1`); na emissão por venda usa a menor do modelo.
- **tPag de cartão:** crédito `03` e débito `04` (estavam `04` e `05` — crédito saía como débito e
  débito como crédito loja). Notas emitidas antes disso ficaram com a forma errada na SEFAZ e não
  têm correção por carta de correção.
- PIX `17` (era `26`, recusado pelo Serviço de NF-e).
- CFOP usa a UF do emitente do certificado, não `config('nfe.uf_padrao')`.
- Origem da mercadoria vem do campo novo `produtos.origem_icms` (0 a 8), não fixa em `0`.

### Falta

- Roteiro em homologação com certificado real: emitir, rejeitar de propósito, corrigir e reenviar
  com o mesmo número, descartar e cancelar (estoque volta).
- Nota de devolução (`nfe_referenciada`) não entra por esta tela.

---

## Fases Futuras (v2+)

- **Fase 13:** Integração com gateway de pagamento (Stripe/PagSeguro)
- **Fase 14:** Dashboard avançado com relatórios de vendas, margem, top produtos
- **Fase 15:** Reserva de estoque em pedidos
- **Fase 16:** Contingência offline (emissão local quando SEFAZ cai, sincronização posterior)
- **Fase 17:** Integração com impressoras (térmica, A4, etiqueta)

---

## Dependências Críticas de nfe-api para v1 Launch

GestãoFácil v1 **NÃO PODE** lançar enquanto nfe-api não tiver:

1. **RealSefazGateway implementado e testado** (não pseudocódigo) — ✅ **implementado em 2026-09-15**,
   ⏳ **falta homologação** (Fase 6.1 do `nfe-api/PLAN.md`)
   - XML real montado (`NfeXmlBuilder`), assinado, validado contra o XSD e enviado; `nfeProc` gravado.
     Testado offline com SEFAZ roteirizada; comportamento real de cada SEFAZ só em homologação
   - ⚠️ **Contrato de `POST /nfe` mudou** — GestãoFácil precisa: (a) cadastrar o emitente por CNPJ em
     `PUT /certificados/{cnpj}/emitente` (razão social, IE, CRT, endereço, CSC); (b) mandar por item
     `codigo`, `cfop`, `unidade`, `icms` (CSOSN no Simples / CST no regime normal), `pis`, `cofins`;
     destinatário com endereço (NF-e); `pagamentos` somando o total. Devolução com valores **positivos**.
     Contrato completo em `nfe-api/docs/API_ENDPOINTS.md`. (Hoje o `NfeEmissaoService::emitir()` do
     GestãoFácil passa uma string XML para `NfeApiClient::emitir(array)` — já não funcionava.)

2. **Numeração separada por ambiente** (homolog vs produção) — ✅ (e agora também por modelo)
   - Contador já era por ambiente, mas o unique de `nfes` (certificado, série, número) bloqueava a nota 1
     de produção se existisse a 1 de homologação — corrigido em 2026-09-15

3. **NFC-e (modelo 65) suportado** — ✅ **implementado em 2026-09-15**, ⏳ falta homologação
   - Mesmo endpoint, `"modelo": "65"`; destinatário opcional; exige CSC cadastrado no emitente
   - QR Code, DANFCE e numeração independente da NF-e

4. **Tratamento de contingência SVC documentado**
   - API deve documentar como a chave muda durante contingência
   - GestãoFácil já implementa armazenamento de histórico

5. **Webhook com payload completo** (incluindo `cnpj` e `timestamp`)
   - Se não tiver, GestãoFácil faz lookup via `protocolo_id`
   - Workaround em PLAN-API Fase 6 já coberto

6. **Email para notificações** (opcional — GestãoFácil implementa job próprio como fallback)

7. **Endpoint de download de XML da NFe** — ✅ **implementado no nfe-api em 2026-09-15**
   (Fase 7.1 do `nfe-api/PLAN.md`; contrato em `nfe-api/docs/API_ENDPOINTS.md`).
   Falta o lado GestãoFácil.
   - Motivo original: nenhuma rota expunha o `xml_path` do nfe-api, e os campos
     `xml_requisicao`/`xml_resposta` em `nfe_emissoes` não são o XML autorizado pela SEFAZ.
   - **Contrato final (diferente da proposta `{"xml_url": ...}`):**
     `GET /nfe/{protocoloId}/xml` responde **o conteúdo do XML**, síncrono:
     - 200 → corpo XML, `Content-Type: application/xml; charset=UTF-8`,
       `Content-Disposition: attachment; filename="{chave}-nfe.xml"`, `Cache-Control: private, no-store`
     - 409 `{"message", "status_atual"}` → nota não está `authorized` nem `cancelled`
     - 404 `{"message"}` → nota inexistente/de outro client/sem arquivo; 401 JSON sem token
     - Por quê: o XML já existe desde a autorização (nada a gerar) e o storage do nfe-api
       é privado — uma URL exporia dados do destinatário fora do token.
   - **XML dos eventos (cancelamento/CC-e)** — também implementado em 2026-09-15:
     `GET /nfe/{protocoloId}/eventos/{event_id}/xml`, mesmo formato (200 XML / 409 com
     `status_atual` se o evento não foi registrado / 404). `event_id` é o que
     `POST /cancelar` e `/carta-correcao` já devolvem. Os jobs de evento do nfe-api eram
     stubs (cancelavam sem falar com a SEFAZ); agora a nota só vira `cancelled` depois que a
     SEFAZ registra — GestãoFácil não deve assumir cancelamento no 202.
   - **O que GestãoFácil precisa fazer:** `NfeApiClient::xml()` lendo `$response->body()`
     (não `->json()` no 200; erros continuam JSON), sem persistir URL; rota própria que
     repassa o corpo com os mesmos headers. Liberar também para nota cancelada. Guardar o
     `event_id` dos eventos para baixar o XML deles.
   - ⚠️ **Relacionado:** o `danfe_url` que GestãoFácil já grava em `nfe_emissoes.danfe_url`
     não funciona — é relativo (`/storage/danfe/{id}.pdf`) e o nfe-api não serve esse caminho.
     Registrado como aberto na Fase 7.1 do nfe-api; a correção provável é o `/danfe` passar a
     devolver o PDF no mesmo padrão do `/xml`, o que muda o contrato consumido hoje.

Ver [[nfe_api_blockers]] em memory para checklist completo.

---

## Débito Técnico Assumido Conscientemente (Mesma Lógica da API de NFe)

- Sem controle de caixa (abertura/fechamento) — é módulo financeiro, fora de escopo agora
- Sem parcelamento — `venda_pagamentos` guarda valor total por forma de pagamento, não parcelas individuais
- Rate limit e isolamento entre empresas dependem do middleware de escopo por `empresa_id` — não há banco separado por empresa (decisão consciente de custo/simplicidade, mesma lógica da API de NFe)
- Sem integração com impressoras em v1 (será avaliado em v2, Fase 17)
- Sem live collaboration/edição concorrente de pedidos (um usuário por vez)
- Sem histórico completo de edições (apenas timestamps)

---
