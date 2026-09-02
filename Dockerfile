# syntax=docker/dockerfile:1

FROM node:20-bookworm-slim AS backend-build

WORKDIR /src/backend

COPY backend/package.json backend/package-lock.json ./
RUN npm ci

COPY backend/tsconfig.json ./
COPY backend/src ./src
COPY backend/public ./public
COPY backend/plugins ./plugins

RUN npm run build

FROM node:20-bookworm-slim AS frontend-build

WORKDIR /src/frontend

COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci

COPY frontend ./

ARG BACKEND_URL=http://127.0.0.1:4000
ARG NEXT_PUBLIC_SITE_URL=

ENV BACKEND_URL=${BACKEND_URL}
ENV NEXT_PUBLIC_API_URL=/api
ENV NEXT_PUBLIC_SITE_URL=${NEXT_PUBLIC_SITE_URL}
ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build

FROM node:20-bookworm-slim AS runtime

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
ENV BACKEND_URL=http://127.0.0.1:4000

COPY backend/package.json backend/package-lock.json ./backend/
RUN cd /app/backend && npm ci --omit=dev && npm cache clean --force

COPY --from=backend-build /src/backend/dist ./backend/dist
COPY --from=backend-build /src/backend/public ./backend/public
COPY --from=backend-build /src/backend/plugins ./backend/plugins
COPY --from=frontend-build --chown=node:node /src/frontend/.next/standalone ./frontend
COPY docker-entrypoint.sh ./docker-entrypoint.sh

RUN mkdir -p /app/data/uploads /app/data/plugins \
  && rm -rf /app/backend/public/uploads /app/backend/plugins \
  && ln -s /app/data/uploads /app/backend/public/uploads \
  && ln -s /app/data/plugins /app/backend/plugins \
  && chown -R node:node /app/data /app/backend /app/frontend \
  && chmod +x ./docker-entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["./docker-entrypoint.sh"]
