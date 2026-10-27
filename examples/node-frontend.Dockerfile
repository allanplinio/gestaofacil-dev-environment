# ═══════════════════════════════════════════════════════════════════════════
#  EXEMPLO — Dockerfile multi-stage para frontend Node.js (Vite/React ou Vue)
# ═══════════════════════════════════════════════════════════════════════════
#  O stage `dev` é o que o ambiente local usa (build.target: dev).
#  Os stages `builder` + runtime existem para a imagem de produção sair do
#  MESMO arquivo — evita o clássico "funciona em dev, quebra no deploy".
# ═══════════════════════════════════════════════════════════════════════════

# ─── DEV: dev server com HMR ───────────────────────────────────────────────
FROM node:20-alpine AS dev
WORKDIR /app

# Camada separada: só reinstala quando o manifesto muda.
COPY package*.json ./
RUN npm ci || npm install

COPY . .

EXPOSE 3000
# --host 0.0.0.0 é obrigatório: sem isso o Vite escuta só em 127.0.0.1
# DENTRO do container e o proxy não alcança.
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

# ─── BUILD: bundle de produção ─────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# ─── RUNTIME: serve os estáticos ───────────────────────────────────────────
FROM node:20-alpine AS production
WORKDIR /app
RUN npm install -g serve
COPY --from=builder /app/dist ./dist
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000',r=>{if(r.statusCode!==200)throw new Error(r.statusCode)})" || exit 1
CMD ["serve", "-s", "dist", "-l", "3000"]
