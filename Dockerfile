# Base com Node + dependências de build
FROM node:22.18.0-alpine AS base
WORKDIR /usr/src/wpp-server

# Variáveis padrão (podem ser sobrescritas no Railway)
ENV NODE_ENV=production \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PORT=8080 \
    HOST=0.0.0.0 \
    SWAGGER=true \
    AUTHENTICATION=false \
    CHROME_PATH=/usr/bin/chromium \
    CHROME_ARGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage"

COPY package.json ./
RUN apk update && apk add --no-cache \
    vips-dev fftw-dev gcc g++ make libc6-compat \
    && rm -rf /var/cache/apk/*
RUN yarn install --production --pure-lockfile && \
    yarn add sharp --ignore-engines && \
    yarn cache clean

# Fase de build (instala dev deps e compila TS -> dist)
FROM base AS build
WORKDIR /usr/src/wpp-server
COPY . .
RUN yarn install --production=false --pure-lockfile && yarn build && yarn cache clean

# Runtime: Chromium + artefatos compilados
FROM base
WORKDIR /usr/src/wpp-server

# Chromium para puppeteer
RUN apk add --no-cache chromium && yarn cache clean

# Criar pasta persistente antes
RUN mkdir -p /usr/src/wpp-server/tokens

# Copia apenas o resultado do build (inclui dist e node_modules completos)
COPY --from=build /usr/src/wpp-server/ /usr/src/wpp-server/

# Expor a porta esperada pelo Railway
EXPOSE 8080

# Entrypoint padrão
ENTRYPOINT ["node", "dist/server.js"]
