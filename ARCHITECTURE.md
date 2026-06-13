# Brew & Bean — Architecture

## Overview

Brew & Bean is a full-stack Indian cafe ordering platform built as a pnpm monorepo. Customers browse the menu, add items to cart, and pay via UPI. The admin reviews and approves orders through a password-protected dashboard.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18, Vite 7, TypeScript 5.9 |
| Styling | Tailwind CSS v4, shadcn/ui, Framer Motion |
| Routing | Wouter (client-side SPA) |
| State | React Context (cart, auth) + localStorage |
| API Client | React Query + generated fetch hooks (Orval) |
| Backend | Express 5, Node.js 24, TypeScript |
| Database | PostgreSQL 16 + Drizzle ORM |
| Validation | Zod (server-side input/output validation) |
| File uploads | Multer (disk storage, local `uploads/`) |
| Logging | Pino (structured JSON logs) |
| Build | Vite (frontend), esbuild (backend) |
| Package manager | pnpm 9 workspaces |

---

## Repository Structure

```
brew-bean/
├── artifacts/
│   ├── api-server/              # Express 5 REST API
│   │   ├── src/
│   │   │   ├── index.ts         # Server entrypoint (binds PORT)
│   │   │   ├── app.ts           # Express app (middleware, routes)
│   │   │   ├── lib/logger.ts    # Pino singleton logger
│   │   │   ├── middlewares/     # Custom Express middleware
│   │   │   └── routes/
│   │   │       ├── index.ts     # Router aggregator
│   │   │       ├── orders.ts    # GET/POST/PATCH /orders
│   │   │       ├── upload.ts    # POST /upload (multer)
│   │   │       ├── users.ts     # GET /users (admin)
│   │   │       └── health.ts    # GET /healthz
│   │   ├── uploads/             # Payment screenshot storage
│   │   ├── build.mjs            # esbuild script
│   │   └── package.json
│   │
│   └── brew-bean/               # React + Vite SPA
│       ├── src/
│       │   ├── main.tsx         # App entrypoint
│       │   ├── App.tsx          # Router + providers
│       │   ├── context/
│       │   │   ├── AuthContext.tsx   # Admin auth state
│       │   │   └── CartContext.tsx   # Shopping cart state
│       │   ├── pages/
│       │   │   ├── Home.tsx         # Landing page
│       │   │   ├── Menu.tsx         # Menu browser
│       │   │   ├── Cart.tsx         # Cart review
│       │   │   ├── Checkout.tsx     # UPI payment + upload
│       │   │   ├── Profile.tsx      # Order history by phone
│       │   │   ├── Admin.tsx        # Admin dashboard
│       │   │   └── AdminLogin.tsx   # Admin login form
│       │   ├── components/          # Reusable UI components
│       │   ├── data/menu.ts         # Hardcoded menu items
│       │   └── lib/                 # Utility functions
│       └── public/images/           # AI-generated menu photos
│
├── lib/
│   ├── api-spec/
│   │   ├── openapi.yaml         # OpenAPI 3.0 — source of truth
│   │   └── orval.config.ts      # Code generation config
│   ├── api-client-react/
│   │   └── src/
│   │       ├── generated/       # Auto-generated React Query hooks
│   │       ├── custom-fetch.ts  # Fetch wrapper (base URL, auth)
│   │       └── index.ts         # Public exports
│   ├── api-zod/
│   │   └── src/generated/       # Auto-generated Zod schemas
│   └── db/
│       ├── src/
│       │   ├── index.ts         # Drizzle client singleton
│       │   └── schema/
│       │       └── orders.ts    # Orders table schema
│       └── drizzle.config.ts    # Drizzle migration config
│
├── migration.sql                # Database migration (canonical)
├── Dockerfile                   # Multi-stage production build
├── docker-compose.yml           # Full stack (app + postgres)
├── vercel.json                  # Vercel frontend config
├── railway.toml                 # Railway backend config
└── .env.example                 # Environment variable reference
```

---

## Data Flow

### Customer Order Flow

```
Browser (React SPA)
  │
  ├─ Browses menu (hardcoded data — no API call)
  ├─ Adds to cart (localStorage)
  ├─ Fills checkout form (name, phone)
  ├─ Pays via UPI (PhonePe/GPay deeplink or QR code)
  ├─ Uploads screenshot → POST /api/upload
  │     └─ multer saves to uploads/TIMESTAMP-FILENAME.ext
  │     └─ returns { url: "/api/uploads/..." }
  └─ Creates order → POST /api/orders
        └─ Drizzle inserts into orders table
        └─ Returns { orderId, ... }
```

### Admin Approval Flow

```
Admin (React SPA)
  │
  ├─ Logs in at /admin-login (checks VITE_ADMIN_PHONE + VITE_ADMIN_PIN)
  │     └─ Stores isAdmin flag in sessionStorage
  ├─ Views dashboard at /admin → GET /api/orders
  ├─ Opens order, views screenshot (from /api/uploads/...)
  └─ Approves/rejects → PATCH /api/orders/:id
        └─ Updates payment_status + order_status in DB
```

### Customer Order History Flow

```
Customer → /profile
  ├─ Enters phone number
  └─ GET /api/orders?phone=XXXXXXXXXX
        └─ Returns all orders matching that phone number
```

---

## Authentication

**Admin authentication is client-side only.**

- The admin phone and PIN are embedded in the frontend JavaScript bundle as `VITE_ADMIN_PHONE` and `VITE_ADMIN_PIN`.
- On login, the frontend compares the entered phone/PIN against the embedded values.
- If matched, `isAdmin: true` is stored in `sessionStorage`.
- The session is lost on tab close (sessionStorage is not persisted).
- **No server-side authentication guard exists** — admin API routes are not protected.

> **Security note**: For production hardening, add server-side session authentication (see Security section in the ownership report).

**Customer authentication: None.**
- Customers place orders by providing their name and phone number.
- Order history is retrieved by phone number — no password or session required.

---

## API Routes

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/healthz | Health check |
| GET | /api/orders | List orders (optional ?phone=) |
| POST | /api/orders | Create a new order |
| PATCH | /api/orders/:id | Update payment/order status (admin) |
| POST | /api/upload | Upload a payment screenshot |
| GET | /api/uploads/:filename | Serve uploaded files |

---

## Database Schema

### orders

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| id | SERIAL | NO | auto | Internal primary key |
| order_id | TEXT | NO | — | Unique human-readable ID |
| user_id | TEXT | NO | — | Client-generated identifier |
| customer_name | TEXT | YES | — | Customer's name |
| phone_number | TEXT | NO | — | 10-digit Indian mobile |
| items | JSONB | NO | — | Array of ordered items |
| total_amount | NUMERIC(10,2) | NO | — | INR total |
| screenshot_url | TEXT | YES | — | Path to uploaded screenshot |
| utr | TEXT | YES | — | UPI transaction reference |
| payment_status | TEXT | NO | 'pending' | pending/approved/rejected |
| order_status | TEXT | NO | 'pending' | pending/preparing/ready/completed |
| created_at | TIMESTAMP | NO | NOW() | UTC timestamp |

---

## Deployment Topology

### Docker (single host)
```
Internet → Nginx (port 443) → Express (port 8080)
                                  ├── /api/*      → Express route handlers
                                  ├── /api/uploads/* → Static file serving
                                  └── /*          → SPA (index.html)
                                        ↓
                                   PostgreSQL (port 5432, internal)
```

### Cloud (split host)
```
Internet → Vercel CDN → Built React SPA (static)
                           │
                           └── VITE_API_URL → Railway Node.js app
                                                   ├── /api/* → Express
                                                   └── /api/uploads/* → Static
                                                         ↓
                                                   Railway PostgreSQL
```
