# syntax=docker/dockerfile:1

##############################
# Build stage
##############################
FROM node:20-bookworm-slim AS build
WORKDIR /app

# Ferramentas p/ build (git p/ deps via Git; toolchain p/ node-gyp)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates python3 make g++ \
 && rm -rf /var/lib/apt/lists/*

# Força qualquer URL SSH do GitHub a usar HTTPS (sem chaves SSH)
RUN git config --global url."https://github.com/".insteadOf git@github.com: && \
    git config --global url."https://github.com/".insteadOf ssh://git@github.com/

# Instala dependências com npm (evita Yarn/Pnpm)
COPY package*.json ./
RUN rm -f yarn.lock pnpm-lock.yaml
RUN npm ci

# Copia o restante do código
COPY . .

# Provider do Prisma: postgresql (default) ou mysql
ARG DB_PROVIDER=postgresql
ENV DATABASE_PROVIDER=${DB_PROVIDER}

# Gera Prisma Client com o schema do provider
RUN npm run db:generate

# Build TS->JS
RUN npm run build

# Remove devDependencies
RUN npm prune --omit=dev


##############################
# Runtime stage
##############################
FROM node:20-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production

# ✅ Prisma precisa de OpenSSL 3 em runtime (Debian bookworm)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# (Opcional) diretório efêmero usado por alguns exemplos
RUN mkdir -p /evolution/instances && chown -R node:node /evolution

# Artefatos do build
COPY --from=build /app /app

USER node

# Cloud Run publica $PORT; Evolution lê SERVER_PORT (default 8080)
EXPOSE 8080

# Healthcheck simples (ajuste a rota caso tenha /health)
HEALTHCHECK --interval=30s --timeout=5s --retries=5 \
  CMD node -e "require('http').get(`http://127.0.0.1:${process.env.PORT||8080}/health`,res=>process.exit(res.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["sh","-c","export SERVER_PORT=${PORT:-8080} && npm run start"]
