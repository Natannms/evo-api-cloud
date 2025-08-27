FROM node:20-alpine

# Instala dependências do sistema
RUN apk update && apk add --no-cache bash ffmpeg tzdata openssl git

# Define timezone
ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

# Copia package.json e package-lock.json
COPY package*.json ./

# Instala dependências
RUN npm ci --silent

# Copia todo o resto do projeto
COPY . .

# Garante que os scripts tenham permissão de execução
RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

# Expõe porta
EXPOSE 8080

# Comando principal
ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npx tsx ./src/main.ts"]
