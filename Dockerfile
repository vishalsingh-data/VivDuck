# One image: builds the Flutter web app, then serves it and the API from Node.
#   docker build -t vivduck .
#   docker run -p 8000:8000 -e LLM_API_KEY=... vivduck

# ── 1. Flutter web build ─────────────────────────────────────────────────────
FROM debian:bookworm-slim AS web
ARG FLUTTER_VERSION=3.44.1
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl unzip xz-utils ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics && flutter precache --web
WORKDIR /src/app
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get
COPY app/ ./
RUN flutter build web --release

# ── 2. Node server ───────────────────────────────────────────────────────────
FROM node:22-slim
ENV NODE_ENV=production PORT=8000 DATA_DIR=/data PUBLIC_DIR=/srv/public
WORKDIR /srv/backend
COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev
COPY backend/ai ./ai
COPY backend/server ./server
COPY shared /srv/shared
COPY --from=web /src/app/build/web /srv/public
RUN mkdir -p /data && chown node:node /data
USER node
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "server/server.js"]
