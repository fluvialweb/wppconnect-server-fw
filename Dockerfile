# Base com Node + dependências de build
FROM node:22.17.1-alpine AS base
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
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
COPY package.json ./
RUN yarn install --production=false --pure-lockfile && yarn cache clean
COPY . .
RUN yarn build

# Runtime: Chromium + artefatos compilados
FROM base
WORKDIR /usr/src/wpp-server
RUN apk add --no-cache chromium && yarn cache clean

# Copia código e pasta dist da etapa de build
COPY . .
COPY --from=build /usr/src/wpp-server/ /usr/src/wpp-server/

# Pasta de sessões (persistência)
RUN mkdir -p /usr/src/wpp-server/tokens

# Expor a porta que o Railway usará
EXPOSE 8080

# Entry correto do WPPConnect Server
ENTRYPOINT ["node", "dist/index.js"]
