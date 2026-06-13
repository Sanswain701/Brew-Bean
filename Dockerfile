# ============================================================
# Brew & Bean — Production Dockerfile
# ============================================================
# Multi-stage build:
#   stage 1 (frontend-build) : pnpm install + vite build
#   stage 2 (backend-build)  : pnpm install + esbuild
#   stage 3 (production)     : minimal Node runtime, no dev tools
#
# Build:
#   docker build \
#     --build-arg VITE_ADMIN_PHONE=9999999999 \
#     --build-arg VITE_ADMIN_PIN=1234 \
#     --build-arg VITE_UPI_ID=yourname@upi \
#     --build-arg "VITE_UPI_NAME=Brew & Bean" \
#     -t brew-bean:latest .
#
# Run (with external DB):
#   docker run -d -p 8080:8080 \
#     -e DATABASE_URL="postgres://user:pass@host:5432/brew_bean" \
#     -v brew_bean_uploads:/app/uploads \
#     brew-bean:latest
#
# Or use docker compose (recommended — includes bundled Postgres):
#   docker compose up -d
# ============================================================

# ---- Stage 1: Build frontend --------------------------------
FROM node:24-alpine AS frontend-build
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy only what the frontend build needs
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json tsconfig.json tsconfig.base.json ./
COPY lib/ ./lib/
COPY artifacts/brew-bean/ ./artifacts/brew-bean/
COPY attached_assets/ ./attached_assets/

RUN pnpm install --frozen-lockfile

# VITE_ vars are baked into the JS bundle at build time.
# Pass them as --build-arg when calling docker build.
ARG VITE_ADMIN_PHONE
ARG VITE_ADMIN_PIN
ARG VITE_UPI_ID
ARG VITE_UPI_NAME
ARG VITE_API_URL

ENV VITE_ADMIN_PHONE=$VITE_ADMIN_PHONE \
    VITE_ADMIN_PIN=$VITE_ADMIN_PIN \
    VITE_UPI_ID=$VITE_UPI_ID \
    VITE_UPI_NAME=$VITE_UPI_NAME \
    VITE_API_URL=$VITE_API_URL \
    PORT=8080 \
    BASE_PATH=/

# Build outputs to artifacts/brew-bean/dist/public/
RUN pnpm --filter @workspace/brew-bean run build

# ---- Stage 2: Build backend ---------------------------------
FROM node:24-alpine AS backend-build
WORKDIR /app

RUN corepack enable && corepack prepare pnpm@latest --activate

COPY pnpm-workspace.yaml pnpm-lock.yaml package.json tsconfig.json tsconfig.base.json ./
COPY lib/ ./lib/
COPY artifacts/api-server/ ./artifacts/api-server/

RUN pnpm install --frozen-lockfile

# Build outputs to artifacts/api-server/dist/index.mjs (esbuild bundle)
RUN pnpm --filter @workspace/api-server run build

# ---- Stage 3: Minimal production runtime --------------------
FROM node:24-alpine AS production
WORKDIR /app

# The esbuild output is self-contained — no node_modules needed.
COPY --from=backend-build /app/artifacts/api-server/dist ./dist

# Frontend static files served by the Express server
COPY --from=frontend-build /app/artifacts/brew-bean/dist/public ./public

# Persistent volume for payment screenshot uploads
RUN mkdir -p uploads

EXPOSE 8080

ENV NODE_ENV=production \
    PORT=8080 \
    FRONTEND_DIST=/app/public

# DATABASE_URL must be provided at runtime via -e or docker compose env
CMD ["node", "--enable-source-maps", "./dist/index.mjs"]
