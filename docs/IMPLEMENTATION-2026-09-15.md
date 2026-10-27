# Implementation Summary — 2026-09-15

## Changes Implemented Today

### 🛡️ **Protection Against Test Database Corruption**

**Problem:** Running `php artisan test` in Docker containers was executing `migrate:fresh` on the development database instead of test database, wiping all data.

**Solution (2-layer protection):**

1. **Layer 1: phpunit.xml with `force="true"`**
   - Both APIs now have `force="true"` in `DB_CONNECTION` and `DB_DATABASE` env vars
   - gestaofacil-api: `gestaofacil_test`
   - nfe-api: `nfe_api_test`

2. **Layer 2: TestCase.php Trava (Circuit Breaker)**
   - Both `tests/TestCase.php` check if database name ends in `_test`
   - If not: throw `RuntimeException` with clear error message
   - Prevents destructive operations before any tests run

**Verification:**
```bash
APP_ENV=testing DB_DATABASE=gestaofacil_test php artisan test tests/Feature/Sales
# ✅ 27 tests pass
```

**Files:**
- `gestaofacil-api/phpunit.xml` (lines 29-30)
- `gestaofacil-api/tests/TestCase.php` (lines 14-23)
- `nfe-api/phpunit.xml` (created)
- `nfe-api/tests/TestCase.php` (updated)

---

### 📋 **Pedidos de Venda (Vendas → Pedidos Renaming)**

**Changes:**
- "Vendas" → "Pedidos de venda" / "Pedidos"
- "PDV" → "Frente de loja"
- "Frente de caixa" → "Frente de loja"

**UI Updates:**
- Layout menu: "📋 Pedidos", "💳 Frente de loja"
- Dashboard: "Abrir frente de loja", "Novo pedido"
- Novo Pedido form title
- Listagem de pedidos title
- Profile descriptions updated for vendors

**Files:**
- `src/pages/Vendas.tsx`
- `src/pages/VendaForm.tsx`
- `src/pages/VendaDetalhe.tsx`
- `src/pages/PDV.tsx`
- `src/pages/Dashboard.tsx`
- `src/pages/Login.tsx`
- `src/pages/UsuarioForm.tsx`
- `src/components/Layout.tsx`

---

### 🔄 **Estoque (baixar_estoque Flag)**

**Backend (gestaofacil-api):**
- New column `vendas.baixar_estoque` (boolean, default true)
- Finalizar venda só baixa estoque se flag = true
- Cancelar venda só devolve estoque se foi baixado
- Adicionar item só valida estoque se pedido vai baixar

**Frontend (gestaofacil-fe):**
- Checkbox "Baixar estoque" no novo pedido (sempre visível)
- VendaDetalhe mostra status: "📦 Estoque será baixado" / "📋 Sem movimentação"
- Mensagem de cancelamento adaptada conforme flag

**Tests:**
- 3 new tests validating behavior without stock deduction
- All 27 sales tests pass

**Files:**
- `gestaofacil-api/database/migrations/2026_09_15_150000_add_baixar_estoque_to_vendas_table.php`
- `gestaofacil-api/app/Models/Venda.php`
- `gestaofacil-api/app/Services/VendaService.php`
- `gestaofacil-api/tests/Feature/Sales/VendaTest.php`
- `gestaofacil-fe/src/types/index.ts`
- `gestaofacil-fe/src/services/api.ts`
- `gestaofacil-fe/src/pages/VendaForm.tsx`
- `gestaofacil-fe/src/pages/VendaDetalhe.tsx`

---

### 🎯 **Pedido Status (Aberta / Finalizada)**

**Changed:** From checkbox "Finalizar agora" to dropdown "Status do pedido"

**New behavior:**
- Status dropdown: Aberta | Finalizada
- **Aberta:** Opcional adicionar pagamentos, estoque não é movimentado
- **Finalizada:** Pagamentos obrigatórios, estoque é movimentado conforme flag

**UI:**
- Always show Pagamentos section (independent of status)
- Button label: "Salvar pedido" (não mais muda)
- Help text adapts to status
- Validação: pagamentos exigidos apenas se status=Finalizada

**Files:**
- `gestaofacil-fe/src/pages/VendaForm.tsx`

---

### 📊 **Table Height Fix**

**Problem:** When few items in Vendas list, table was too small and cut off action buttons.

**Solution:** Add `min-h-96` to table container

**Files:**
- `gestaofacil-fe/src/pages/Vendas.tsx`

---

### 👁️ **Ações da Listagem de Pedidos**

**Changes:**
- Número do pedido (#123) now clickable (opens detalhe)
- Removed `onRowClick` from Table (was opening on any click)
- Added "Visualizar" (👁️) option in AcoesVenda dropdown
- Click on number or "Visualizar" → navigate to `/vendas/{id}`

**Files:**
- `gestaofacil-fe/src/pages/Vendas.tsx`
- `gestaofacil-fe/src/components/AcoesVenda.tsx`

---

### 🔐 **Configuração Fiscal (Upload Certificado)**

**Backend (gestaofacil-api):**
- New `ConfiguracaoFiscalController` with GET and POST endpoints
- Upload de certificado A1 (.pfx/.p12) — criptografado no storage
- Ambiente selector (1=Produção, 2=Homologação)
- Senha do certificado criptografada
- Validação: arquivo máximo 2MB, tipo correto
- Routes: `POST /configuracoes/fiscal`, `GET /configuracoes/fiscal`

**Frontend (gestaofacil-fe):**
- Load fiscal config on page open
- Dropdown ambiente (Homologação/Produção) com indicadores visuais
- File input for certificate (.pfx/.p12)
- Password field (optional, for updates only)
- Visual indicators: certificate status, environment badge
- Save button enabled only if changes

**Files:**
- `gestaofacil-api/app/Http/Controllers/ConfiguracaoFiscalController.php`
- `gestaofacil-api/database/migrations/2026_09_15_160000_add_certificado_fields_to_configuracoes_fiscais.php`
- `gestaofacil-api/app/Models/ConfiguracaoFiscal.php`
- `gestaofacil-api/routes/api.php`
- `gestaofacil-fe/src/pages/ConfiguracaoFiscal.tsx`
- `gestaofacil-fe/src/services/api.ts`

---

## Git Commits

```
gestaofacil-api:
- 3f3410e: feat: adicionar coluna baixar_estoque em vendas com proteção de testes
- a8d72c3: feat: implementar configuração fiscal com upload de certificado

gestaofacil-fe:
- 693eb28: refactor: renomear Vendas → Pedidos, PDV → Frente de loja, adicionar opções de status e baixar_estoque
- 7c48e2a: refactor: substituir 'Finalizar agora' por dropdown de status e sempre mostrar pagamentos
- 905366a: feat: implementar interface de configuração fiscal com upload

nfe-api:
- bff0b59: test: adicionar proteção dupla contra corrupção do banco de dev
```

---

## Database Migrations Applied

- `gestaofacil_test`: 21 tables (fully migrated)
- `nfe_api_test`: All migrations (fully migrated)
- `gestaofacil` (dev): New migration `2026_09_15_160000_add_certificado_fields_to_configuracoes_fiscais`
- `gestaofacil` (dev): New migration `2026_09_15_150000_add_baixar_estoque_to_vendas_table`

---

## Test Data Created

- Empresa: "Teste Empresa Ltda" (CNPJ: 11.222.333/0001-81)
- User: teste@exemplo.com / teste123 (admin)
- Cliente: "Cliente Teste"
- Produtos: 3 items with stock

**Login:** `teste@exemplo.com` / `teste123`

---

## What's Next (Roadmap)

Based on PROGRESS.md, remaining steps:

- ✅ **Fase 0-2:** Setup, Auth, Fiscal Config (DONE)
- ✅ **Fase 3:** Products & Stock (DONE)
- ✅ **Fase 4:** Clients (DONE)
- ✅ **Fase 5:** Vendas (Pedido) — with status & stock deduction (DONE)
- ⏳ **Fase 6:** NFe Emission integration (webhook + polling)
- ⏳ **Fase 7:** PDV auto NFC-e
- ⏳ **Fase 8:** Cancelamento + CC-e
- ⏳ **Fase 9+:** Dashboard, Users, Permissions, Plans

---

## Notes

- All tests isolated to `*_test` databases with protection layers
- Fiscal config stores certificate encrypted on disk
- Pedido workflow now supports "salvar sem finalizar" (aberto status)
- Estoque é baixado ou não conforme flag, permitindo orçamentos/vendas futuras
