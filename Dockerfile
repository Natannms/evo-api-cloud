FROM node:20-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl dos2unix

WORKDIR /evolution

# Copia configs básicas
COPY package*.json ./
COPY tsconfig.json ./
COPY tsup.config.ts ./

# Instala dependências
RUN npm ci --silent

# Copia o código-fonte
COPY src ./src
COPY public ./public
COPY prisma ./prisma
COPY manager ./manager
COPY .env.example ./.env
COPY runWithProvider.js ./
COPY Docker ./Docker

# Ajusta scripts
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# Gera código do Prisma
RUN ./Docker/scripts/generate_database.sh

# Compila código para dist/
RUN npm run build

# -------------------------
# Imagem final
# -------------------------
FROM node:20-alpine AS final

RUN apk update && \
    apk add --no-cache tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

# Copia apenas o necessário
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js

EXPOSE 8080

# Usa build já pronto
ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod" ]
