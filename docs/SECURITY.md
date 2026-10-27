# SECURITY.md — GestãoFácil API (Multitenancy & Data Isolation)

## 🔒 Princípio Inviolável

**Uma empresa NUNCA pode acessar dados de outra empresa.**

Toda implementação de feature deve seguir este princípio como prioridade máxima, mesmo que retarde entrega.

---

## 🧭 Fronteira de Dados — API de Vendas × Serviço de NFe

**Segundo princípio inviolável: a API de Vendas não conhece os detalhes fiscais da emissão.**

A API de Vendas (GestãoFácil) guarda **apenas** o que é estritamente necessário para o
funcionamento comercial e operacional. Tudo que é específico da emissão fiscal vive
exclusivamente no Serviço de NFe (`nfe-api`).

### Dados compartilhados (podem existir nos dois)

| Dado | Por que a Vendas precisa | Por que o NFe precisa |
|---|---|---|
| CNPJ / CPF | Identificação da conta/tenant e cobrança do SaaS | Chave do certificado e do emitente |
| Razão social | Exibir no painel e em relatórios | Grupo `<emit>` do XML |
| Nome fantasia | Exibir no painel e em relatórios | Grupo `<emit>` do XML |
| Endereço | Cadastro e exibição | Grupo `<emit>` do XML |
| E-mail comercial | Contato e notificações do SaaS | Envio de DANFE/XML |

**Compartilhado significa escrever nos dois.** Razão social e nome fantasia se editam num
lugar só — o formulário de Configuração Fiscal — e a gravação vai para as duas bases na
mesma requisição: `PUT /v1/certificados/{cnpj}/emitente` no Serviço de NFe (grupo `<emit>`
do XML) e `empresas` na API de Vendas (painel e relatórios). Espelhar só um lado deixaria
os dois divergindo, com o usuário vendo o nome antigo no topo da tela onde acabou de
trocá-lo. O espelhamento cobre **apenas esses dois campos** — IE, IM, CRT, `cMun`, CNAE e
CSC seguem exclusivos do `nfe-api`, e o teste
`test_espelhamento_nao_leva_dados_fiscais_para_empresas` garante isso.

### Exclusivo do Serviço de NFe — NUNCA vai para a API de Vendas

- ❌ Arquivo do certificado digital A1 (`.pfx`)
- ❌ Senha do certificado
- ❌ Inscrição Estadual (IE) e Inscrição Municipal (IM)
- ❌ Código do município IBGE (`cMun`) e CNAE
- ❌ Regime tributário (CRT)
- ❌ CSC e ID do CSC da NFC-e
- ❌ Série e sequência numérica das notas fiscais

### Exclusivo da API de Vendas — NUNCA vai para o Serviço de NFe

- Plano de assinatura da empresa no SaaS
- Lista de funcionários/usuários que acessam o app
- Histórico de pedidos, catálogo comercial completo e base de clientes
  (na emissão vão apenas os dados do destinatário **daquela nota**, não a base)

### Sem espelho: leitura direta (revisado em 2026-09-20)

Uma versão anterior deste documento permitia cachear `cnpj_certificado`,
`certificado_validade`, `status_certificado` e `ambiente` como "espelho somente-leitura".
**Essa exceção foi removida.** Espelho precisa de sincronização, e sincronização falha
em silêncio: a tela dizia "certificado válido" porque a coluna nunca tinha sido
atualizada, e a pré-checagem de emissão liberava nota com certificado já vencido.

Hoje `App\Services\EstadoDoCertificado` **lê do `nfe-api` a cada uso**
(`GET /v1/certificados/{cnpj}`), com cache apenas por requisição — de-duplicação dentro
do mesmo request, nada que sobreviva a ele. Se o serviço estiver fora, os campos vêm
`null`, a tela abre vazia e a emissão é bloqueada (`podeEmitir()` retorna false).

`ambiente` merece nota própria: no `nfe-api` ele é propriedade do **certificado**, não
parâmetro de request — de propósito, para o client não conseguir mandar nota real para
homologação. Manter uma cópia local reabria essa porta.

Sobra em `configuracoes_fiscais` **apenas** `nfe_api_token_id` (a credencial da
integração) e as chaves da linha.

### Número e série de uma nota emitida não são "controle"

`nfe_emissoes.numero_nfe`, `serie_nfe` e `chave_nfe` **continuam** na API de Vendas, e
está correto: são o **resultado** que a SEFAZ autorizou, lido da resposta do `nfe-api`.
Sem eles a venda não sabe qual nota é dela. O que não pode existir aqui é o **contador** —
quem reserva o próximo número é o `nfe_numbering` do `nfe-api`, com lock no banco.

A distinção pegou um defeito real: o payload de emissão mandava
`numero_nfe => str_pad($emissao->id, 9, '0')`, ou seja, o autoincrement da tabela local
como número de nota fiscal. O `nfe-api` ignorava, mas era controle de numeração no lugar
errado. O mesmo valia para `ambiente`. Ambos removidos do payload.

### Onde o dado fiscal é digitado

A tela de Configuração Fiscal vive no GestãoFácil UI, mas a API de Vendas atua como
**proxy sem persistência**: valida a permissão do usuário, resolve o CNPJ do tenant e
repassa o corpo da requisição ao `nfe-api`. IE, IM, CRT, `cMun`, CSC, senha, `.pfx` e
numeração transitam pela Vendas no máximo como payload em memória de uma requisição —
nunca viram coluna, arquivo, cache ou linha de log.

Por que proxy e não upload direto do browser para o `nfe-api`: o token de client do
`nfe-api` é segredo de servidor. Se ele fosse para o navegador, qualquer usuário do
tenant poderia falar com o serviço fiscal por fora do app.

### Como a tela exibe de volta o que não está guardado

Não guardar o emitente não pode significar não conseguir mostrá-lo. O caminho de leitura
é simétrico ao de escrita: `GET /configuracoes/fiscal` da API de Vendas chama
`GET /v1/certificados/{cnpj}` do `nfe-api` **a cada requisição** e devolve o emitente
junto na resposta, sem persistir nada. O `.pfx`, a senha e o CSC nunca vêm nessa leitura
(só `csc_configurado: true|false`).

Se o Serviço de NFe estiver fora do ar ou o CNPJ ainda não tiver certificado, o campo vem
`null` e a tela abre sem os dados — nunca com erro, e nunca com um valor local de fallback,
que seria justamente a cópia que esta fronteira proíbe.

⚠️ **Contrato com o frontend:** `emitente` é objeto ou `null`. Nunca string JSON. Quando
vazava como string, a tela quebrava em `emitente.endereco is undefined` — o teste
`test_get_devolve_emitente_lido_do_nfe_api_como_objeto` trava essa regressão.

### Bugs reais que essa fronteira revelou (2026-09-20)

Fechar a fronteira expôs três defeitos que já existiam e nunca tinham aparecido, porque
a integração nunca havia sido exercitada de ponta a ponta:

| Defeito | Efeito | Correção |
|---|---|---|
| `nfe_api_token_id` era `VARCHAR(255)` | Um token real, criptografado com `Crypt::encryptString()` (~300 chars), estourava com *"value too long"*. Só cabia o placeholder curto do ambiente de dev | Migration `2026_09_18_000000_widen_nfe_api_token_id` muda para `TEXT` |
| `pfx_file` validado com `mimes:pfx,p12` | Um PKCS#12 real é detectado pelo `finfo` como `application/octet-stream`, então **todo certificado válido era recusado** com "O arquivo deve ser um certificado .pfx ou .p12" | Trocado por `extensions:pfx,p12`; quem valida o conteúdo de verdade é o `openssl_pkcs12_read()` do `CertificateService` |
| Resposta do `nfe-api` gravada crua no log | Os endpoints de certificado respondem com o recurso **inteiro**, `emitente` junto. `nfe_requests.response` virava uma cópia de IE/IM/CRT/CNAE/`cMun` — dentro de uma tabela de auditoria, fora do alcance do teste que só olha as colunas de `configuracoes_fiscais` | `NfeApiClient::respostaSegura()` filtra por **lista de permitidos**; migration `2026_09_20_000001_purge_emitente_from_nfe_requests` apaga o passivo |
| Erro do `nfe-api` repassado cru ao usuário | `401` virava a mensagem *"Unauthenticated."* na tela — o usuário achava que tinha errado a própria senha | `NfeApiClient::mensagemDeErro()` separa erro de negócio (repassa) de erro de autenticação/infra (traduz) |

### Decisão: a configuração fiscal é síncrona (2026-09-20)

O FE nunca fala com o `nfe-api`. Tem um único cliente HTTP apontando para a API de Vendas,
que faz o proxy. Isso é verificável: zero referências a URL do serviço fiscal em
`gestaofacil-fe/src/`.

Foi levantada a hipótese de tornar o salvamento assíncrono (responder 202 e sincronizar
com o `nfe-api` em fila). **Decidido manter síncrono**, por três motivos:

1. **Conflita com esta fronteira.** "Salvar aqui e sincronizar depois" exige que a API de
   Vendas segure o `.pfx`, a senha e o emitente até o job rodar — no payload da fila, que
   é infraestrutura dela. É a mesma cópia que este documento proíbe, num lugar onde
   ninguém audita.
2. **Perde o erro onde ele importa.** Só o `nfe-api` sabe dizer se a senha abre o `.pfx`
   (`openssl_pkcs12_read`), se a numeração daquele CNPJ/série já existe (risco fiscal) ou
   se IE/CRT/`cMun` passam no XSD. Assíncrono o usuário vê "salvo", vai embora, e o
   certificado nunca foi aceito.
3. **Não há problema de latência.** Medido: ~50ms por chamada. E é tela de onboarding,
   não caminho quente.

**O caminho quente já é assíncrono, e corretamente:** a emissão (`POST /v1/nfe`) devolve
`202` + `protocolo_id`, processa em fila no `nfe-api` e avisa a API de Vendas por webhook
(`POST /webhooks/nfe-emissao`), com um "consultar" manual como reforço. É lá que o
assincronismo paga — dezenas de notas por dia contra uma configuração por empresa.

Se algum dia a configuração precisar ser assíncrona, a forma que **não** quebra a
fronteira é fila do lado do `nfe-api` (ele recebe, responde 202 e processa), nunca
buffer do lado da Vendas.

### Checklist de fronteira (bloqueia merge)

- [ ] Nenhuma migration da API de Vendas cria coluna de `.pfx`, senha de certificado, IE, IM, CRT, `cMun`, CNAE, CSC, série ou numeração
- [ ] Nenhum `Storage::put` / `move` / `copy` da API de Vendas grava `.pfx`
- [ ] O payload de configuração fiscal não é escrito em log nem em tabela de auditoria
- [ ] **A resposta do `nfe-api` também não** — ela ecoa o emitente inteiro; filtrar por lista de permitidos antes de logar
- [ ] Teste automatizado verifica com `Schema::hasColumn()` que as colunas proibidas não existem

---

## Arquitetura de Isolamento

### 1. Middleware Automático (`EnscopeToCompany`)

**Localização:** `app/Http/Middleware/EnscopeToCompany.php`

**Responsabilidade:** Adicionar constraint automático `where('empresa_id', $empresa_id)` a TODA query de usuário autenticado.

**Como funciona:**
```php
// No middleware:
$empresa_id = Auth::user()->empresa_id; // Extrai empresa do token/sessão
$request->attributes->set('empresa_id', $empresa_id);

// Em qualquer model query:
// Antes: $user->produtos()->all() → retorna produtos de qualquer empresa (ERRADO!)
// Depois: $user->produtos()->all() → retorna SÓ produtos de user->empresa_id (CORRETO!)
```

**Aplicação:** Está em `api` route group do `routes/api.php` — aplicado GLOBALMENTE.

**Não pode ser skipado:** Middleware não tem bypass. Se você esquecer de aplicar, o CI/CD deve falhar.

### 2. Global Query Scope (`CompanyScope`)

**Localização:** `app/Models/Scopes/CompanyScope.php`

**Responsabilidade:** Filtrar automaticamente por `empresa_id` em qualquer query.

**Como usar em nova model:**
```php
// In app/Models/Produto.php:
use App\Models\Scopes\CompanyScope;

class Produto extends Model {
    protected static function booted(): void {
        static::addGlobalScope(new CompanyScope);
    }
}

// Resultado:
Produto::all(); // Automático: .where('empresa_id', current_empresa_id)
```

**CHECKLIST quando criar nova model:**
- [ ] Model extende `Model`
- [ ] Model tem `empresa_id` foreign key
- [ ] Model tem `static function booted() { addGlobalScope(new CompanyScope) }`
- [ ] Testes incluem validação de vazamento entre 2 empresas

### 3. Validação Explícita em Endpoints Sensíveis

Para endpoints que recebem parâmetro `{id}`, validar SEMPRE que o recurso pertence à empresa logada:

```php
// ERRADO (apenas scope):
public function update(Request $request, $id) {
    $produto = Produto::findOrFail($id); // Scope filtra, mas...
    // Se scope não existir, vaza dados!
}

// CORRETO (scope + validação explícita):
public function update(Request $request, $id) {
    $produto = Produto::findOrFail($id); // Scope filtra
    
    // Validação explícita como fallback (defesa em profundidade):
    if ($produto->empresa_id !== Auth::user()->empresa_id) {
        abort(403, 'Unauthorized');
    }
    
    // ... update logic
}
```

---

## Testes de Vazamento (Obrigatórios por Feature)

### Padrão de Teste

```php
// tests/Feature/ProdutoTest.php
public function test_empresa_a_nao_ve_produtos_de_empresa_b() {
    $empresaA = Empresa::factory()->create();
    $empresaB = Empresa::factory()->create();
    
    $userA = User::factory()->for($empresaA)->create();
    $userB = User::factory()->for($empresaB)->create();
    
    $produtoA = Produto::factory()->for($empresaA)->create();
    $produtoB = Produto::factory()->for($empresaB)->create();
    
    // User A tenta ver produto de B via GET
    $response = $this->actingAs($userA)->get("/api/produtos/{$produtoB->id}");
    $this->assertEquals(404, $response->status()); // Não encontrado!
    
    // User A lista produtos — só vê seu próprio
    $response = $this->actingAs($userA)->get('/api/produtos');
    $this->assertCount(1, $response->json('data')); // Só 1 (produtoA)
    $this->assertEquals($produtoA->id, $response->json('data.0.id'));
}

public function test_scope_esta_sendo_aplicado() {
    $empresa = Empresa::factory()->create();
    $user = User::factory()->for($empresa)->create();
    $produto = Produto::factory()->for($empresa)->create();
    
    // Validar que query tem .where('empresa_id')
    $query = Produto::query()->toSql();
    $this->assertStringContainsString('`empresa_id`', $query);
}
```

### Checklist por Fase

| Fase | Modelos | Testes Adicionados |
|------|---------|-------------------|
| 1    | Empresa, User | vazamento de usuários |
| 2    | ConfiguracaoFiscal | vazamento de certificados + fronteira de dados (colunas fiscais ausentes) |
| 3    | Produto, EstoqueMovimentacao | vazamento de produtos/movimentações |
| 4    | Cliente | vazamento de clientes |
| 5    | Venda, VendaItem, VendaPagamento | vazamento de vendas/itens |
| 6    | NfeRequest (logs) | vazamento de requests/webhooks |

---

## Cenários de Ataque (Bloqueados Automaticamente)

### 1. ID Tampering

**Ataque:** Usuário da Empresa A tenta acessar recurso da Empresa B:
```
GET /api/produtos/999 (onde 999 é de Empresa B)
```

**Proteção:** GlobalScope filtra automaticamente
```php
Produto::find(999) // Internamente: .where('empresa_id', A).where('id', 999)
// Resultado: null → Controller retorna 404
```

**Validação:** Teste deve confirmar que retorna 404, não 200 com dados errados.

### 2. Bulk Operations Inválidas

**Ataque:** Usuário tenta atualizar múltiplos produtos de outra empresa:
```
PATCH /api/produtos/bulk
{ "ids": [1, 2, 3, 999], "preco": 100 } // 999 é de Emp B
```

**Proteção:** Validação no controller + scope:
```php
$produtos = Produto::whereIn('id', $ids)->get(); // Só retorna se empresa_id bater
if ($produtos->count() !== count($ids)) {
    abort(422, 'Alguns produtos não encontrados'); // Não especificar quais
}
```

### 3. SQL Injection Contornando Filtro

**Ataque:** Injetar SQL pra ignorar `.where('empresa_id')`
```
GET /api/produtos?filter=id=1 OR 1=1
```

**Proteção:** Queries parametrizadas (Laravel default)
```php
// Laravel usa prepared statements automaticamente:
where('empresa_id', $empresa_id) // Mapped como ?
// SQL: ... WHERE empresa_id = ? (value separately)
// Não concatenação de strings
```

**Validação:** Teste com `.toSql()` confirma `?` não string.

### 4. Token Replay

**Ataque:** Capturar token de Empresa A, usar com Empresa B
```
GET /api/produtos -H "Authorization: Bearer TOKEN_A"
// TOKEN_A vinculado a Empresa A
```

**Proteção:** Sanctum vincula token à sessão/user específico
```php
// Token armazena: user_id + empresa_id (via Auth::user())
// Middleware valida: Auth::user()->empresa_id sempre bate com request
```

### 5. Webhook Malicioso

**Ataque:** API nfe-api envia webhook com CNPJ diferente:
```
POST /webhook/nfe
{ "cnpj": "DIFFERENT", "status": "authorized", "chave": "...", ... }
```

**Proteção:** Validar CNPJ contra empresas conhecidas
```php
// app/Http/Controllers/WebhookNfeController.php
$empresa = Empresa::where('cnpj', $payload['cnpj'])->firstOrFail();
if (!$empresa) abort(404, 'Empresa não encontrada');
// Atualizar dados da empresa específica
```

---

## 🔐 Proteção de Senhas

### Tipos de Senhas no Sistema

1. **Senha de Usuário** (email/alias + password)
   - Usada para login no GestãoFácil
   - Armazenada hashed no banco
   
2. **Senha de Certificado Digital** (.pfx)
   - Necessária para assinar notas fiscais
   - NUNCA é armazenada na API de Vendas (GestãoFácil) — nem criptografada
   - Fica **criptografada no banco do `nfe-api`**, com chave mestra dedicada
   - É **criptografada e não hasheada**: precisa ser recuperável para abrir o `.pfx` na
     hora de assinar o XML — um hash seria irreversível e inutilizaria o certificado

### 1. Senhas de Usuário — Hashing com Argon2ID (Não Bcrypt!)

**⚠️ CUIDADO:** Laravel default pode usar Bcrypt, que é mais fraco que Argon2. Forçar Argon2ID.

**Configuração (config/hashing.php):**
```php
return [
    'driver' => 'argon2id', // NÃO 'bcrypt'!
    
    'argon' => [
        'memory' => 65536,    // 64MB (padrão)
        'threads' => 4,       // 4 threads paralelas
        'time' => 4,          // 4 iterações (padrão)
    ],
];
```

**Por que Argon2ID e não Bcrypt:**
- Bcrypt: desenhado em 1999, máximo 72 bytes de password (limitação!)
- Argon2ID: vencedor de Password Hashing Competition 2015, resistente a GPU/ASIC
- Resistência: Argon2 requer MUITA memória + CPU, impossível paralelizar com GPUs
- Tempo: Argon2 com memory=65536 leva ~50-100ms por hash (vs Bcrypt ~60ms)
- Segurança: Argon2ID é recomendado por OWASP e NIST

**Armazenamento:**
```php
// Ao registrar/alterar senha:
$user->password = Hash::make($password); // Usa driver configurado (Argon2ID)
$user->save();

// Validação:
Hash::check($password_input, $user->password); // True/False
```

**Propriedades do Argon2ID:**
- Algoritmo: Argon2ID (OWASP recomendado 2024)
- Memory cost: 65536 KB (~64MB por hash)
- Time cost: 4 iterações
- Parallelism: 4 threads
- Colisões: Impossível (2^256 possibilidades)
- GPU-resistant: Sim (requer muita memória compartilhada)
- ASIC-resistant: Sim (não pode ser pré-computado em massa)

**Validação (CRÍTICO):**
```php
// tests/Feature/PasswordSecurityTest.php

public function test_driver_hashing_eh_argon2id() {
    // Validar que configuração está com Argon2ID (não Bcrypt)
    $this->assertEquals('argon2id', config('hashing.driver'));
}

public function test_senha_armazenada_com_argon2id() {
    $user = User::factory()->create(['password' => 'MinhaSenh@123']);
    
    // Validar que está hashed (não em plaintext)
    $this->assertNotEquals('MinhaSenh@123', $user->password);
    
    // Validar que é Argon2ID (começa com $argon2id$)
    $this->assertStringStartsWith('$argon2id$', $user->password);
    
    // Validar que Argon2ID consegue validar
    $this->assertTrue(Hash::check('MinhaSenh@123', $user->password));
}

public function test_hash_nao_eh_bcrypt() {
    $user = User::factory()->create(['password' => 'MinhaSenh@123']);
    
    // Validar que NÃO é Bcrypt (não começa com $2y$)
    $this->assertStringNotStartsWith('$2y$', $user->password);
    $this->assertStringNotStartsWith('$2b$', $user->password);
    $this->assertStringNotStartsWith('$2a$', $user->password);
}

public function test_argon2_memory_cost_eh_65536() {
    $memory = config('hashing.argon.memory');
    $this->assertEquals(65536, $memory); // 64MB
}

public function test_argon2_time_cost_minimo_4() {
    $time = config('hashing.argon.time');
    $this->assertGreaterThanOrEqual(4, $time);
}

public function test_argon2_threads_minimo_4() {
    $threads = config('hashing.argon.threads');
    $this->assertGreaterThanOrEqual(4, $threads);
}

public function test_hash_nao_pode_ser_revertido() {
    $password = 'MinhaSenh@123';
    $hash = Hash::make($password);
    
    // Validar que NUNCA consegue reverter
    // (teoricamente impossível com Argon2, não há "decrypt")
    $this->assertFalse(Hash::check('outra-senha', $hash));
    
    // Mesmo hash com mesma senha produz hash diferente
    $hash2 = Hash::make($password);
    $this->assertNotEquals($hash, $hash2); // Salts diferentes
    
    // Mas ambos validam a mesma senha
    $this->assertTrue(Hash::check($password, $hash));
    $this->assertTrue(Hash::check($password, $hash2));
}
```

**CI/CD Check (Bloqueia Deploy):**
```php
// scripts/check-security.php
$config = include 'config/hashing.php';

if ($config['driver'] !== 'argon2id') {
    echo "❌ ERRO: hashing.driver DEVE ser 'argon2id', não '{$config['driver']}'\n";
    exit(1);
}

if ($config['argon']['memory'] < 65536) {
    echo "❌ ERRO: argon memory DEVE ser >= 65536, não {$config['argon']['memory']}\n";
    exit(1);
}

if ($config['argon']['time'] < 4) {
    echo "❌ ERRO: argon time DEVE ser >= 4, não {$config['argon']['time']}\n";
    exit(1);
}

echo "✅ Configuração de hashing está segura\n";
```

**GitHub Actions:**
```yaml
# .github/workflows/security.yml
- name: Validate hashing config
  run: php scripts/check-security.php
```

**Testes complementares:**
```php
public function test_senha_nunca_aparece_em_log_ou_response() {
    Log::spy();
    
    // Tentar login com senha
    $response = $this->post('/api/login', [
        'email' => 'user@example.com',
        'password' => 'minha-senha-secreta'
    ]);
    
    // Validar senha NUNCA aparece em response
    $this->assertNotContains('minha-senha-secreta', json_encode($response->json()));
    
    // Validar senha NUNCA aparece em logs
    Log::assertNotLogged('minha-senha-secreta');
}

public function test_outro_usuario_nao_consegue_verificar_senha() {
    $user1 = User::factory()->create(['password' => 'senha-1']);
    $user2 = User::factory()->create(['password' => 'senha-2']);
    
    // User2 não consegue verificar hash de User1 (segurança por isolamento)
    $this->assertFalse(Hash::check('senha-2', $user1->password));
    $this->assertFalse(Hash::check('senha-1', $user2->password));
}
```

### 1b. Requisitos de Infraestrutura para Argon2ID

**Performance:**
- Argon2 com memory=65536 leva ~50-100ms por hash
- Login de 5 usuários concorrentes = ~500ms total (aceitável)
- NÃO é "lento demais" — segurança vale o tempo

**Recursos:**
- CPU: 1 core dedicado por ~100 hashes/segundo (não é gargalo)
- Memória: 64MB por hash (temporário durante processamento)
- Não requer GPU ou hardware especial

**Teste de Carga:**
```php
// tests/Performance/PasswordHashingTest.php
public function test_argon2_nao_sobrecarrega_cpu() {
    $start = microtime(true);
    
    // Hash 100 senhas
    for ($i = 0; $i < 100; $i++) {
        Hash::make('MinhaSenh@' . $i);
    }
    
    $elapsed = microtime(true) - $start;
    
    // Deve levar ~5-10 segundos (50-100ms cada)
    $this->assertLessThan(15, $elapsed);
    $this->assertGreaterThan(3, $elapsed);
}
```

### 2. Força de Senha (Validação Obrigatória)

**Regras na criação/alteração:**
- Mínimo 8 caracteres
- Validador Laravel (ou custom):
  ```php
  'password' => [
      'required',
      'min:8',
      'confirmed', // password_confirmation deve bater
      Password::min(8)
          ->mixedCase()     // Maiúscula + minúscula
          ->numbers()        // Pelo menos 1 número
          ->symbols()        // Pelo menos 1 símbolo
          ->uncompromised(), // Validar contra lista de senhas comprometidas (haveibeenpwned.com)
  ]
  ```

**Testes:**
```php
public function test_senha_fraca_rejeitada() {
    $response = $this->post('/api/users', [
        'email' => 'new@example.com',
        'password' => '123', // Muito curta
        'password_confirmation' => '123'
    ]);
    
    $this->assertEquals(422, $response->status());
    $this->assertHasErrors($response, 'password');
}

public function test_senha_sem_numero_rejeitada() {
    $response = $this->post('/api/users', [
        'email' => 'new@example.com',
        'password' => 'SenhaABC!', // Sem número
        'password_confirmation' => 'SenhaABC!'
    ]);
    
    $this->assertEquals(422, $response->status());
}

public function test_senha_comprometida_rejeitada() {
    $response = $this->post('/api/users', [
        'email' => 'new@example.com',
        'password' => 'Password123!', // Comum, pode estar em haveibeenpwned
        'password_confirmation' => 'Password123!'
    ]);
    
    $this->assertEquals(422, $response->status());
}
```

### 3. Certificado (.pfx) — Armazenado Só no Serviço de NFe

**Fluxo correto:**
```
GestãoFácil UI (HTTPS)
  │  multipart: .pfx + senha + IE/IM/CRT/cMun/CSC + série/numeração inicial
  ▼
GestãoFácil API (API de Vendas)  ── PROXY SEM PERSISTÊNCIA ──┐
  • autentica o usuário e checa o perfil (só Administrador)   │ nada toca disco
  • resolve o CNPJ do tenant a partir de `empresas`           │ nada toca banco
  • repassa o corpo da requisição adiante                     │ nada vai pro log
  ▼                                                           ┘
nfe-api (Serviço de NFe)
  ├─ valida o .pfx com a senha (openssl_pkcs12_read) e extrai a validade
  ├─ grava o .pfx CRIPTOGRAFADO em diretório privado do servidor (fora da raiz web)
  ├─ grava a SENHA CRIPTOGRAFADA no banco (chave mestra dedicada)
  ├─ grava IE / IM / CRT / cMun / CNAE / CSC / série / numeração
  └─ responde { cnpj, validade, status, ambiente }
  ▼
GestãoFácil API grava APENAS o espelho somente-leitura desses 4 campos
```

**O que a API de Vendas NUNCA faz:**
- ❌ Não persiste o `.pfx` em arquivo (`Storage::put`, `move`, `copy`, `file_put_contents`)
- ❌ Não persiste a senha do certificado no banco — **nem criptografada**
- ❌ Não guarda IE, IM, CRT, `cMun`, CNAE, CSC, série ou numeração de nota
- ❌ Não faz cache do certificado em memória entre requisições
- ❌ Não loga o conteúdo do arquivo, a senha ou o payload do upload

**O que a API de Vendas armazena (espelho, ver [Fronteira de Dados](#-fronteira-de-dados--api-de-vendas--serviço-de-nfe)):**
- ✅ `cnpj_certificado` — para identificar a empresa
- ✅ `certificado_validade` — para avisar do vencimento (30/15/7 dias)
- ✅ `status_certificado` — válido, vencendo, vencido
- ✅ `ambiente` — homologação ou produção (só exibição; fonte da verdade é o `nfe-api`)
- ✅ `nfe_api_token_id` — criptografado com `Crypt::encryptString()`

**Implementação:**
```php
// ERRADO — NÃO FAZER na API de Vendas:
$conteudo = file_get_contents($request->file('certificado')->getRealPath());
Storage::disk('private')->put("certificados/{$empresa->id}.pfx", $conteudo); // ❌ NUNCA
$config->senha_certificado = Crypt::encryptString($request->input('senha')); // ❌ NUNCA
$config->emitente = $request->input('emitente');                             // ❌ NUNCA (IE/CRT/cMun)
$config->serie = $request->input('serie');                                   // ❌ NUNCA

// CORRETO — proxy, e persiste só o espelho:
$resposta = app(NfeApiClient::class)->uploadCertificado(
    cnpj:     $empresa->cnpj,
    pfxStream: $request->file('certificado'), // repassado, não lido pra variável de longa vida
    senha:    $request->input('senha'),
    emitente: $request->input('emitente'),    // IE, IM, CRT, cMun, CNAE, CSC — só de passagem
);

$empresa->configuracaoFiscal()->update([
    'cnpj_certificado'      => $resposta['cnpj'],
    'certificado_validade'  => $resposta['validade'],
    'status_certificado'    => $resposta['status'],
    'ambiente'              => $resposta['ambiente'],
]);
```

---

#### 3a. Como o `nfe-api` guarda o arquivo `.pfx` (em disco privado, não em coluna de banco)

**Diretório privado na VPS**, fora da raiz pública servida por Nginx/Apache:

```
/var/app/storage/certificates/{certificate_id}/cert.pfx
```

O diretorio e por **certificado** (UUID de `client_certificates`), nao por empresa: um
client pode ter varios CNPJs, e a renovacao reaproveita a mesma linha e o mesmo caminho.
O caminho base vem de `NFE_CERTIFICATES_PATH` (`config/nfe.php` → `certificates_path`);
o default de desenvolvimento e `storage/certificates`, que ja fica fora de `public/`.

| Regra | Valor | Motivo |
|---|---|---|
| Local | Fora do docroot do Nginx/Apache | Nenhuma URL consegue alcançar o arquivo |
| Dono | Usuário de sistema que roda o serviço (ex: `app:app`) | Outro processo do VPS não lê |
| Permissão do arquivo | `chmod 400` (ou `600` se precisar reescrever na renovação) | Só a aplicação lê |
| Permissão do diretório | `chmod 700` | Impede até listar quais tenants existem |
| Conteúdo em repouso | Criptografado com `NFE_CERT_ENCRYPTION_KEY` (chave mestra dedicada, **não** a `APP_KEY`) | Vazar um snapshot do disco não entrega os certificados |
| Backup | O arquivo criptografado entra no backup; a chave mestra **não** vai junto | Backup roubado é inútil sem a chave |
| Remoção | `unlink` + remoção da linha ao descadastrar a empresa | Não deixar certificado órfão no disco |

**Provisionamento na VPS:**
```bash
sudo mkdir -p /var/app/storage/certificates
sudo chown -R app:app /var/app/storage/certificates
sudo chmod 700 /var/app/storage/certificates
```

**Na gravação (por empresa):**
Implementado em `app/Services/CertificateStorage.php`:

```php
// Escrita atomica: grava num temporario 0600 no MESMO diretorio e renomeia por cima.
// Sem isso, uma renovacao que falhe no meio deixaria o certificado antigo corrompido -
// e o arquivo final e 0400, entao nao da pra sobrescrever direto.
$temporario = $destino . '.new';
file_put_contents($temporario, $conteudoJaCriptografado, LOCK_EX);
chmod($temporario, 0600);
rename($temporario, $destino);
chmod($destino, 0400);
```

O `CertificateStorage` nunca ve o `.pfx` limpo: recebe e devolve sempre cifrado. Quem
decifra e o `CertificateService`, e so em memoria.

**Descriptografia SÓ em RAM — nunca uma cópia limpa em disco:**

O `.pfx` decriptado existe apenas como string PHP durante a assinatura do XML e é
entregue direto à biblioteca de assinatura. **Nunca** passa por `tempnam()`,
`sys_get_temp_dir()`, `/tmp`, `storage/app` nem por um arquivo intermediário.

```php
// ERRADO — grava cópia limpa em disco:
$pfx = $this->encryption->decrypt(file_get_contents($caminho));
$tmp = tempnam(sys_get_temp_dir(), 'cert'); // ❌ NUNCA
file_put_contents($tmp, $pfx);              // ❌ NUNCA
$gateway->setCertificate(Certificate::readPfx(file_get_contents($tmp), $senha));

// CORRETO — só memória (ver app/Jobs/Concerns/PreparesSefazGateway.php):
$gateway->setCertificate(Certificate::readPfx(
    $certificates->decryptedPfx($certificate),      // string em RAM
    $certificates->decryptedPassword($certificate), // string em RAM
));
```

**Testes obrigatórios:**
```php
public function test_pfx_gravado_com_permissao_restrita() {
    $certificate = $this->uploadCertificado();
    $caminho = config('nfe.certificates_path') . "/{$certificate->id}/cert.pfx";

    $this->assertFileExists($caminho);
    $this->assertSame('0400', substr(sprintf('%o', fileperms($caminho)), -4));
    $this->assertSame('0700', substr(sprintf('%o', fileperms(dirname($caminho))), -4));
}

public function test_pfx_em_disco_esta_criptografado() {
    $certificate = $this->uploadCertificado();
    $bruto = file_get_contents(config('nfe.certificates_path') . "/{$certificate->id}/cert.pfx");

    // O conteúdo em repouso não pode ser um PKCS#12 legível
    $certs = [];
    $this->assertFalse(@openssl_pkcs12_read($bruto, $certs, 'senha-do-teste'));
}

public function test_assinatura_nao_deixa_copia_limpa_em_tmp() {
    $antes = glob(sys_get_temp_dir() . '/*');
    $this->emitirNota();
    $this->assertSame($antes, glob(sys_get_temp_dir() . '/*'));
}
```

---

#### 3b. Como o `nfe-api` guarda a senha do certificado

- Coluna `password_encrypted` em `client_certificates`, **criptografada** via
  `CertificateEncryptionService` (chave `NFE_CERT_ENCRYPTION_KEY`, separada da `APP_KEY`).
- **Criptografada, não hasheada:** a senha precisa ser recuperada para abrir o `.pfx` na
  assinatura. Hash seria irreversível e inutilizaria o certificado.
- A chave mestra é separada da `APP_KEY` de propósito: vazar a `APP_KEY` sozinha não
  expõe os certificados de todos os clientes.
- `protected $hidden = ['pfx_encrypted', 'password_encrypted', 'csc_encrypted']` no model
  impede vazamento em serialização acidental (resposta de API, `dd()`, log de exceção).
- A senha **nunca** volta para a API de Vendas, nem para a UI, nem em mensagem de erro.
  Quem digitou errado recebe "senha incorreta ou arquivo corrompido", sem eco do valor.
- Rotação da chave mestra: re-criptografar todas as linhas e todos os arquivos `.pfx`.
  Procedimento manual documentado — ver `nfe-api/docs/SECRETS_MANAGEMENT.md`.

**Teste:**
```php
public function test_senha_do_certificado_fica_criptografada_e_recuperavel() {
    $certificate = $this->uploadCertificado(senha: 'SenhaDoCert@123');

    // Não está em texto claro no banco
    $bruto = DB::table('client_certificates')->where('id', $certificate->id)->value('password_encrypted');
    $this->assertNotSame('SenhaDoCert@123', $bruto);

    // Mas é recuperável (criptografia, não hash)
    $this->assertSame('SenhaDoCert@123', app(CertificateService::class)->decryptedPassword($certificate));

    // E nunca aparece na resposta da API
    $this->assertStringNotContainsString('SenhaDoCert@123', json_encode($certificate->toArray()));
}
```

---

#### 3c. Teste de fronteira na API de Vendas (bloqueia merge)

```php
public function test_api_de_vendas_nao_tem_colunas_fiscais() {
    $proibidas = [
        'certificado_path', 'senha_certificado', 'pfx', 'pfx_encrypted',
        'emitente', 'inscricao_estadual', 'inscricao_municipal', 'crt',
        'codigo_municipio', 'cnae', 'csc', 'csc_id',
        'serie', 'numero_inicial_nfe', 'numero_inicial_nfce',
    ];

    foreach ($proibidas as $coluna) {
        $this->assertFalse(
            Schema::hasColumn('configuracoes_fiscais', $coluna),
            "Coluna fiscal '{$coluna}' não pode existir na API de Vendas — pertence ao nfe-api."
        );
    }
}

public function test_certificado_nunca_persistido_localmente() {
    Storage::fake('private');

    Http::fake(['*/v1/certificados' => Http::response([
        'cnpj' => '12345678901234',
        'validade' => '2027-12-31',
        'status' => 'valido',
        'ambiente' => 2,
    ], 201)]);

    $this->actingAs($admin)->post('/api/empresas/' . $empresa->id . '/certificado', [
        'certificado' => UploadedFile::fake()->create('cert.pfx', 4),
        'senha' => 'senha-cert',
        'emitente' => ['ie' => '123456789', 'crt' => 1],
    ])->assertOk();

    // Nenhum arquivo ficou no disco da API de Vendas
    $this->assertEmpty(Storage::disk('private')->allFiles());

    // Só o espelho foi gravado
    $this->assertDatabaseHas('configuracoes_fiscais', [
        'empresa_id' => $empresa->id,
        'cnpj_certificado' => '12345678901234',
        'status_certificado' => 'valido',
    ]);

    // Senha não foi parar em lugar nenhum do banco
    $linha = (array) DB::table('configuracoes_fiscais')->where('empresa_id', $empresa->id)->first();
    $this->assertStringNotContainsString('senha-cert', json_encode($linha));
}
```

---

### 4. Proteção Contra Força Bruta (Rate Limiting)

**No endpoint de login:**
```php
Route::post('/login', [LoginController::class, 'store'])
    ->middleware('throttle:5,1'); // 5 tentativas por 1 minuto
```

**Comportamento:**
- 5 tentativas de login ✅ Permitidas
- 6ª tentativa: 429 Too Many Requests por 60 segundos
- Tenta novamente após 60s

**Teste:**
```php
public function test_rate_limiting_no_login() {
    for ($i = 0; $i < 5; $i++) {
        $response = $this->post('/api/login', [
            'email' => 'user@example.com',
            'password' => 'wrong'
        ]);
        $this->assertEquals(401, $response->status()); // Erro, mas permitido
    }
    
    // 6ª tentativa bloqueada
    $response = $this->post('/api/login', [
        'email' => 'user@example.com',
        'password' => 'wrong'
    ]);
    $this->assertEquals(429, $response->status()); // Too Many Requests
}
```

### 5. Recuperação de Senha (Reset Link Seguro)

**Fluxo:**
```
User clica "Esqueci Senha"
  ↓
GestãoFácil gera token aleatório + expira em 24h
  ↓
Envia email com link: /reset-password?token=TOKEN
  ↓
User acessa link, valida token, seta nova senha
  ↓
Token é invalidado (1 uso apenas)
```

**Implementação:**
```php
// Criar token de reset
$token = Str::random(64); // 64 caracteres aleatórios
DB::table('password_reset_tokens')->insert([
    'email' => $request->email,
    'token' => hash('sha256', $token), // Hash do token (não plaintext)
    'created_at' => now()
]);

// Enviar email com token (plaintext, uma vez)
Mail::send('emails.reset-password', [
    'reset_link' => url('/reset-password?token=' . $token)
]);

// Validar token ao fazer reset
$token_hash = hash('sha256', $request->token);
$reset = DB::table('password_reset_tokens')
    ->where('email', $request->email)
    ->where('token', $token_hash)
    ->where('created_at', '>', now()->subHours(24)) // Expiração 24h
    ->first();

if (!$reset) abort(401, 'Token inválido ou expirado');

// Set nova senha e limpar token
$user = User::where('email', $request->email)->first();
$user->update(['password' => bcrypt($request->password)]);
DB::table('password_reset_tokens')->where('email', $request->email)->delete();
```

**Testes:**
```php
public function test_token_reset_expira_24h() {
    DB::table('password_reset_tokens')->insert([
        'email' => 'user@example.com',
        'token' => hash('sha256', 'old-token'),
        'created_at' => now()->subHours(25) // Mais de 24h
    ]);
    
    $response = $this->post('/api/reset-password', [
        'email' => 'user@example.com',
        'token' => 'old-token',
        'password' => 'NovaSenh@123'
    ]);
    
    $this->assertEquals(401, $response->status()); // Expirado
}

public function test_token_so_pode_ser_usado_uma_vez() {
    // Primeiro reset: sucesso
    $response = $this->post('/api/reset-password', [
        'email' => 'user@example.com',
        'token' => 'valid-token',
        'password' => 'NovaSenh@123'
    ]);
    $this->assertEquals(200, $response->status());
    
    // Segunda tentativa com mesmo token: falha
    $response = $this->post('/api/reset-password', [
        'email' => 'user@example.com',
        'token' => 'valid-token', // Token já foi deletado
        'password' => 'OutraSenh@456'
    ]);
    $this->assertEquals(401, $response->status()); // Token inválido
}
```

---

## Campos Sensíveis (Nunca Logar)

### Na API de Vendas (GestãoFácil)

| Campo | Regra |
|---|---|
| Senha de usuário | Hash Argon2ID, nunca em log nem em response |
| `nfe_api_token_id` | Criptografado com `Crypt::encryptString()`, nunca em log |
| `email` | Validar em testes que não vaza entre empresas |
| Arquivo `.pfx` | **Não existe aqui** — só de passagem no proxy, nunca logado |
| Senha do certificado | **Não existe aqui** — só de passagem no proxy, nunca logada |
| IE, IM, CRT, `cMun`, CNAE, CSC, série, numeração | **Não existem aqui** — ver Fronteira de Dados |

### No Serviço de NFe (`nfe-api`)

| Campo | Regra |
|---|---|
| Arquivo `.pfx` | Criptografado em diretório privado (`chmod 400`), decriptado só em RAM |
| `password_encrypted` | Criptografado com chave mestra dedicada, `$hidden` no model |
| `csc_encrypted` | Criptografado com a mesma chave, `$hidden` no model |
| `NFE_CERT_ENCRYPTION_KEY` | Fora da `APP_KEY`; em produção vem de cofre de segredos |

**Regra geral:** o payload inteiro de configuração fiscal é considerado sensível. Não
escrever `$request->all()` em log, em tabela de auditoria ou em mensagem de exceção.

**Validação:**
```php
// Test que valida que senha NUNCA aparece em log
public function test_senha_nao_aparece_em_log() {
    Log::spy();
    
    $this->post('/login', [
        'email' => 'user@example.com',
        'password' => 'minha-senha-secreta'
    ]);
    
    // Validar que nenhum log contém a senha
    Log::assertNotLogged('minha-senha-secreta');
}
```

---

## Procedimento de Review Multitenancy

Antes de fazer merge de qualquer PR:

**Isolamento entre empresas:**
- [ ] Toda nova model tem `CompanyScope`
- [ ] Endpoints sensíveis validam parametro `{id}` pertence à empresa
- [ ] Tests incluem vazamento entre 2 empresas para cada novo endpoint
- [ ] Senhas/tokens não aparecem em logs ou responses
- [ ] Webhook validates CNPJ contra empresas conhecidas
- [ ] SQL queries usam `.toSql()` pra confirmar `.where('empresa_id')`

**Fronteira de dados Vendas × NFe:**
- [ ] A migration não cria coluna de `.pfx`, senha de certificado, IE, IM, CRT, `cMun`, CNAE, CSC, série ou numeração na API de Vendas
- [ ] Nenhum `Storage::put` / `move` / `copy` / `file_put_contents` grava `.pfx` na API de Vendas
- [ ] Upload de certificado é proxy sem persistência — `Storage::fake()` confirma disco vazio
- [ ] `test_api_de_vendas_nao_tem_colunas_fiscais()` passa
- [ ] No `nfe-api`: `.pfx` gravado com `0400` em diretório `0700` fora da raiz web
- [ ] No `nfe-api`: nenhuma cópia decriptada do `.pfx` em `/tmp` ou `storage/app`

**Se qualquer ponto falhar: NÃO MERGE. Corrigir e re-testar.**

---

## Referências em Código

| Arquivo | Responsabilidade |
|---------|------------------|
| `app/Http/Middleware/EnscopeToCompany.php` | Middleware de escopo |
| `app/Models/Scopes/CompanyScope.php` | Global scope base |
| `tests/TestCase.php` | Base test com factories |
| `database/factories/EmpresaFactory.php` | Factory para testes |
| `routes/api.php` | Middleware aplicado aqui |

**No `nfe-api` (Serviço de NFe):**

| Arquivo | Responsabilidade |
|---------|------------------|
| `app/Services/CertificateService.php` | Upload, validação e leitura do `.pfx` |
| `app/Services/CertificateEncryptionService.php` | Criptografia com chave mestra dedicada |
| `app/Jobs/Concerns/PreparesSefazGateway.php` | Decriptação só em RAM para assinar |
| `app/Models/ClientCertificate.php` | `$hidden` nos campos criptografados |
| `docs/SECRETS_MANAGEMENT.md` | Gestão e rotação da chave mestra |

---

## Documentação para Novos Desenvolvedores

**Ao adicionar feature nova:**

1. Criar migration com `empresa_id` foreign key
2. Criar model com `addGlobalScope(new CompanyScope)`
3. Criar endpoint com validação explícita de `{id}`
4. Criar testes de vazamento entre 2 empresas
5. Validar SQL com `.toSql()` tem `.where('empresa_id')`
6. Revisar com colega antes de merge

**Erro mais comum:** Esquecer de adicionar `CompanyScope` na model → vazamento de dados.

**Como debugar:** Use `DB::listen()` em test pra ver SQL gerado:
```php
DB::listen(function($query) {
    echo $query->sql . "\n";
});
```

Se não tem `.where('empresa_id')`, adicione scope!
