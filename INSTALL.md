# Brew & Bean — Local Development Setup

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Node.js | 24+ | `node --version` |
| pnpm | 9+ | `npm install -g pnpm` |
| PostgreSQL | 14+ | Local install or Docker |

---

## 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/brew-bean.git
cd brew-bean
```

---

## 2. Install dependencies

```bash
pnpm install
```

---

## 3. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env` and fill in:

```env
# Required — your PostgreSQL connection string
DATABASE_URL=postgres://user:password@localhost:5432/brew_bean

# Required — baked into the frontend at build time
VITE_ADMIN_PHONE=9999999999   # 10-digit number, no country code
VITE_ADMIN_PIN=1234

# Required — shown on the checkout page
VITE_UPI_ID=yourname@upi
VITE_UPI_NAME=Brew & Bean
```

---

## 4. Set up the database

Create the database and apply the schema:

```bash
# Create the database (if it doesn't exist)
createdb brew_bean

# Apply the migration
psql "$DATABASE_URL" -f migration.sql

# Verify
psql "$DATABASE_URL" -c "\dt"
```

Or using the Drizzle push command (requires DATABASE_URL in environment):

```bash
pnpm --filter @workspace/db run push
```

---

## 5. Run in development mode

You need two terminals (or a process manager):

**Terminal 1 — API server** (port 8080):
```bash
PORT=8080 BASE_PATH=/ pnpm --filter @workspace/api-server run dev
```

**Terminal 2 — Frontend** (port 5173 or similar):
```bash
PORT=5173 BASE_PATH=/ pnpm --filter @workspace/brew-bean run dev
```

Open `http://localhost:5173` in your browser.

> **Note**: The frontend calls the API at `/api/...` using relative URLs by default. Both processes must be running for full functionality. If running on different ports in dev, configure a local proxy or set `VITE_API_URL=http://localhost:8080`.

---

## 6. Build for production (single server)

```bash
# Build frontend (bakes VITE_ vars into the bundle)
PORT=8080 BASE_PATH=/ pnpm --filter @workspace/brew-bean run build

# Build backend
pnpm --filter @workspace/api-server run build

# Run everything on one server
FRONTEND_DIST=./artifacts/brew-bean/dist/public \
DATABASE_URL="postgres://..." \
PORT=8080 \
node artifacts/api-server/dist/index.mjs
```

---

## 7. Regenerate API client (after OpenAPI changes)

```bash
pnpm --filter @workspace/api-spec run codegen
```

---

## Folder structure

```
brew-bean/
├── artifacts/
│   ├── api-server/          # Express 5 backend
│   │   ├── src/
│   │   │   ├── app.ts       # Express app + middleware
│   │   │   ├── index.ts     # Server entrypoint
│   │   │   └── routes/      # API route handlers
│   │   └── uploads/         # Payment screenshot storage
│   └── brew-bean/           # React + Vite frontend
│       ├── src/
│       │   ├── pages/       # Route-level components
│       │   ├── components/  # Shared UI components
│       │   ├── context/     # Cart + auth state
│       │   └── data/        # Hardcoded menu data
│       └── public/          # Static assets
├── lib/
│   ├── api-spec/            # OpenAPI spec (source of truth)
│   ├── api-client-react/    # Generated React Query hooks
│   ├── api-zod/             # Generated Zod schemas
│   └── db/                  # Drizzle ORM schema + client
├── migration.sql            # Database schema migration
├── Dockerfile               # Production container build
├── docker-compose.yml       # Full stack with Postgres
├── vercel.json              # Vercel frontend deployment
└── railway.toml             # Railway backend deployment
```
