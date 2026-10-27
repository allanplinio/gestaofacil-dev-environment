# 🐳 Orquestrador Docker Compose

> ## ⚠️ Documento histórico — este arranjo foi substituído
>
> O ambiente local dos três microsserviços passou a viver em um repositório
> próprio, **[`gestaofacil-dev-environment/`](../README.md)**:
>
> ```bash
> cd gestaofacil-dev-environment
> make doctor && make setup
> ```
>
> **O que mudou e por quê:**
>
> | Antes (este documento) | Agora |
> |---|---|
> | 4 `docker-compose.yml` (raiz + 3 projetos) | 1, no orquestrador |
> | 3 containers Nginx, portas 80/8000/8001 | 1 proxy reverso na porta 80 |
> | 3 instâncias de Redis | 1 compartilhada, com database numerado por app |
> | 2 bancos `gestaofacil` (5434 e 15434) | 1 (`gestaofacil_db`) |
> | URLs por porta (`localhost:8001`) | Domínios (`nfe.gestaofacil.localhost`) |
>
> O texto abaixo descreve a stack antiga e é mantido só como referência de
> migração. Os `docker-compose.yml` e `Makefile` que ele documenta continuam
> no disco, marcados como obsoletos — rodá-los junto com a stack nova recria
> o problema dos bancos duplicados.

---


Este arquivo explica como usar o `docker-compose.yml` e `Makefile` da raiz `/nfe/` para rodar ambas as aplicações (nfe-api e gestaofacil-api) em uma única orquestração.

## 📋 Estrutura

```
/nfe/
├── docker-compose.yml      ← Orquestrador (não versionado)
├── Makefile                ← Comandos facilitadores (não versionado)
├── DOCKER-COMPOSE.md       ← Este arquivo
├── nfe-api/
│   ├── docker-compose.yml  ← Config original (versionada)
│   └── ...
└── gestaofacil-api/
    ├── docker-compose.yml  ← Config original (versionada)
    └── ...
```

## 🚀 Começando

### 1. Setup Inicial

```bash
cd /media/e185d5ed-d3f5-43a5-a3bd-4357c5c22975/Documentos/projects/nfe
make up
```

Isso inicia todos os containers:
- **nfe-api** em http://localhost:8001
- **gestaofacil-api** em http://localhost:8000

### 2. Instalar Dependências

```bash
# NFE-API
make install-nfe

# GestãoFácil
make install-gestao
```

### 3. Migrations e Seeds

```bash
# NFE-API
make migrate-nfe
make seed-nfe

# GestãoFácil
make migrate-gestao
make seed-gestao
```

## 🔧 Comandos Disponíveis

### Gerais
```bash
make up          # Iniciar tudo
make down        # Parar tudo
make restart     # Reiniciar tudo
make clean       # Parar e remover tudo
make status      # Ver status dos containers
make logs        # Ver logs de tudo
```

### NFE-API
```bash
make logs-nfe        # Logs
make bash-nfe        # Entrar no bash
make install-nfe     # Instalar composer
make migrate-nfe     # Migrations
make seed-nfe        # Seed
```

### GestãoFácil
```bash
make logs-gestao       # Logs
make bash-gestao       # Entrar no bash
make install-gestao    # Instalar composer
make migrate-gestao    # Migrations
make seed-gestao       # Seed
```

## 🔌 Portas

| Serviço | Porta | URL |
|---------|-------|-----|
| nfe-nginx | 8001 | http://localhost:8001 |
| nfe-app | 9001 | (interno) |
| nfe-db | 5433 | localhost:5433 |
| nfe-redis | 6379 | localhost:6379 |
| gestao-nginx | 8000 | http://localhost:8000 |
| gestao-app | 9002 | (interno) |
| gestao-db | 5434 | localhost:5434 |
| gestao-redis | 6380 | localhost:6380 |

Os composes individuais (`nfe-api/docker-compose.yml` e `gestaofacil-api/docker-compose.yml`)
usam as mesmas portas de banco e cache do orquestrador (5433/6379 e 5434/6380). Eles sao
**alternativas** ao compose da raiz, nunca devem subir junto com ele.

### Conexao no DBeaver

| Conexao | Host | Porta | Database | User | Password |
|---------|------|-------|----------|------|----------|
| NFe-API | localhost | 5433 | nfe_api | nfe_api | `NFE_DB_PASSWORD` (default `secret`) |
| GestaoFacil | localhost | 5434 | gestaofacil | gestaofacil | `GESTAO_DB_PASSWORD` (default `secret`) |

## 📝 Notas Importantes

1. **Git**: Os arquivos `docker-compose.yml` e `Makefile` na raiz **NÃO são versionados** (estão em `.gitignore`)
   - Cada projeto mantém seu próprio docker-compose na sua pasta
   - Este é apenas para facilitar o desenvolvimento local

2. **Environment**: Crie um `.env` na raiz `/nfe/` se precisar de variáveis personalizadas:
   ```
   NFE_DB_PASSWORD=seu_password
   GESTAO_DB_PASSWORD=seu_password
   ```

3. **Redes Isoladas**: Cada app tem sua própria network (nfe-net e gestao-net)
   - Não há conflito entre aplicações
   - Cada uma tem seu banco e cache separados

4. **Produção**: Em produção, cada serviço rodará de forma independente
   - Este compose é apenas para desenvolvimento local
   - Pode evoluir para Kubernetes, Docker Swarm, etc

## 🔄 Fluxo Típico de Desenvolvimento

```bash
# Primeira vez
cd /nfe
make up
make install-nfe
make migrate-nfe
make seed-nfe
make install-gestao
make migrate-gestao
make seed-gestao

# Próximas vezes
make up

# Parar trabalho
make down

# Ver logs
make logs-nfe
make logs-gestao

# Entrar em um container
make bash-nfe
make bash-gestao
```

## ❓ Troubleshooting

### Porta já em uso
```bash
make clean
make up
```

### Container crashando
```bash
make logs-nfe
# ou
make logs-gestao
```

### Resetar banco de dados
```bash
make down
docker volume rm nfe-pgdata gestao-pgdata
make up
make migrate-nfe && make seed-nfe
make migrate-gestao && make seed-gestao
```

---

**Desenvolvido para facilitar o desenvolvimento local de múltiplos microserviços! 🚀**
