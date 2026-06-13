# Brew & Bean — Ownership & Independence Report

Generated: 2026-06-12

---

## Ownership Status

| Component | Owner | Notes |
|-----------|-------|-------|
| Source Code | **You** | Fully portable pnpm monorepo |
| Database Schema | **You** | Recreatable via `migration.sql` |
| Database Data | **You** | Export with `pg_dump` at any time |
| Admin Authentication | **You** | Custom env-var based, no third party |
| File Storage | **You** | Local disk (`uploads/`), Docker volume |
| Frontend Build | **You** | Standard Vite output |
| Backend Runtime | **You** | Standard Node.js / Express |
| Deployment Config | **You** | Dockerfile, docker-compose, Vercel, Railway |

---

## Replit Dependencies Audit

### Packages

| Package | Usage | Status | Action |
|---------|-------|--------|--------|
| `@replit/vite-plugin-runtime-error-modal` | Error overlay in dev | **Safe** | Only loads when `REPL_ID` is set (Replit env). Never loads outside Replit. |
| `@replit/vite-plugin-cartographer` | Source mapper | **Safe** | Conditionally loaded — only in Replit dev env |
| `@replit/vite-plugin-dev-banner` | Dev banner | **Safe** | Conditionally loaded — only in Replit dev env |

**Result**: All Replit packages are dev-only and gated behind `REPL_ID`. They never activate outside Replit. No code change required for standalone operation.

### Environment Variables

| Variable | Used By | Replit-Specific? | Notes |
|----------|---------|-----------------|-------|
| `DATABASE_URL` | API server (Drizzle) | No — standard PostgreSQL | Works with any Postgres provider |
| `SESSION_SECRET` | Declared but unused | No | Reserved for future session middleware |
| `REPL_ID` | `vite.config.ts` | Yes — Replit detection | Only used to decide whether to load Replit plugins. Works correctly when absent (plugins disabled). |
| `REPLIT_DOMAINS` | Not referenced | N/A | Not used in this codebase |

### APIs and Services

| Service | Usage | Replit-Specific? | Replacement |
|---------|-------|-----------------|-------------|
| Replit PostgreSQL | Database | Yes — provisioned by Replit | Export with `pg_dump`, import to any PostgreSQL host |
| Replit Secrets | Env var storage | Yes — Replit UI | Use `.env` file, Docker env vars, or hosting dashboard |
| Replit Auth | **Not used** | — | Custom admin auth already in place |
| Firebase | **Removed** | — | No Firebase dependencies remain |
| Replit Hosting | Proxy routing | Yes | Replaced by Nginx / Vercel / Railway |

---

## Remaining External Dependencies

These are third-party services that remain in use after migration. None are Replit-specific.

| Service | Purpose | Free Tier | Replacement |
|---------|---------|-----------|-------------|
| PostgreSQL | Order database | Self-host or free tier at Supabase/Neon | Any PostgreSQL 14+ instance |
| UPI Payment Apps | Customer payments | N/A (Indian payment infrastructure) | No replacement — UPI is the design choice |

**No subscription, API key, or third-party account is required to run Brew & Bean independently.**

---

## Production Readiness Assessment

### Docker / VPS
| Check | Status | Notes |
|-------|--------|-------|
| Multi-stage Docker build | Ready | See `Dockerfile` |
| Persistent volume for uploads | Ready | Named Docker volume in `docker-compose.yml` |
| Auto DB migration on first start | Ready | `migration.sql` mounted in `docker-entrypoint-initdb.d/` |
| Process restart on crash | Ready | `restart: unless-stopped` in compose |
| HTTPS / SSL | Manual step | See `DEPLOYMENT.md` — Nginx + Certbot instructions |
| Health check endpoint | Ready | `GET /api/healthz` |

**Verdict: Ready for Docker deployment.**

### Vercel (Frontend) + Railway (Backend)
| Check | Status | Notes |
|-------|--------|-------|
| Static frontend build | Ready | `vercel.json` configured |
| SPA routing (404 → index.html) | Ready | Rewrites in `vercel.json` |
| API external URL support | Ready | Set `VITE_API_URL` before building |
| Railway build config | Ready | `railway.toml` included |
| CORS restricted to frontend domain | Ready | Set `CORS_ORIGIN` env var |
| File uploads on Railway | Ready | Local disk (persistent on Railway) |
| File uploads on Vercel | **Not applicable** | Backend runs on Railway, not Vercel |

**Verdict: Ready for Vercel + Railway deployment.**

### Self-Hosting (Manual VPS)
| Check | Status | Notes |
|-------|--------|-------|
| Node.js 24 runtime | Standard | Any Ubuntu/Debian server |
| PM2 process manager | Standard | `npm install -g pm2` |
| Build scripts | Ready | See `INSTALL.md` |
| HTTPS | Manual step | Nginx + Certbot |

**Verdict: Ready for manual VPS deployment.**

---

## Security Review

### Critical (fix before public launch)

| Issue | Severity | Fix |
|-------|----------|-----|
| Admin credentials embedded in JS bundle | HIGH | Visible to anyone who inspects the bundle. Mitigation: add server-side session auth so the PIN is validated server-side and never exposed in the bundle. |
| No server-side auth guard on admin routes | HIGH | `PATCH /api/orders/:id` is accessible without authentication. Any client can approve/reject orders. Add middleware that validates a session cookie. |
| Uploads served with no auth | MEDIUM | Any URL of the form `/api/uploads/filename` is publicly accessible. Add signed URL generation or auth check if screenshots are sensitive. |

### Moderate

| Issue | Severity | Fix |
|-------|----------|-----|
| No rate limiting | MEDIUM | An attacker can spam `/api/orders` or `/api/upload`. Add `express-rate-limit`. |
| CORS allows all origins by default | MEDIUM | In production, set `CORS_ORIGIN` to your frontend domain only. |
| No file type validation on uploads | MEDIUM | Currently accepts any file. Add MIME type check (images only) and max size limit in multer config. |
| ORDER BY without pagination | LOW | Large order tables will return all rows. Add `LIMIT` + `OFFSET` or cursor pagination. |

### Already Handled

- Input validation via Zod schemas on all API routes
- SQL injection impossible — Drizzle ORM uses parameterised queries
- `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy` headers set by Vercel config
- Structured logging with Pino (no secrets logged)

---

## Final Independence Checklist

- [x] Source code in your GitHub repository
- [x] Database schema in `migration.sql` — recreatable from scratch
- [x] Database data — export anytime with `pg_dump "$DATABASE_URL"`
- [x] All uploaded files — download from `artifacts/api-server/uploads/`
- [x] No Replit Auth — custom admin auth with your own credentials
- [x] No Firebase — completely removed
- [x] Dockerfile — runs anywhere Docker is available
- [x] docker-compose.yml — full stack including database
- [x] Vercel + Railway configs — cloud deployment in two commands
- [x] `.env.example` — complete list of every environment variable
- [x] `INSTALL.md` — local dev setup
- [x] `DEPLOYMENT.md` — three deployment paths
- [x] `MIGRATION.md` — data export/import instructions
- [x] `ARCHITECTURE.md` — system overview

**Brew & Bean is fully independent from Replit.**
You own every component. The application will continue to function permanently without Replit.
