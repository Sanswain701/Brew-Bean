# Brew & Bean

A premium Indian cafe ordering platform with dark luxury aesthetics, custom phone PIN authentication, UPI payment system, and a full admin dashboard.

## Run & Operate

- `pnpm --filter @workspace/brew-bean run dev` — run the frontend (port 19596)
- `pnpm --filter @workspace/api-server run dev` — run the API server (port 8080)
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Required env: `DATABASE_URL` — Postgres connection string

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- Frontend: React + Vite, Tailwind CSS, Framer Motion, shadcn/ui
- API: Express 5
- DB: PostgreSQL + Drizzle ORM (orders, users tables)
- Auth: Firebase (Anonymous Auth + Firestore for user profiles)
- Storage: Firebase Storage (payment screenshots)
- Validation: Zod (`zod/v4`), `drizzle-zod`
- API codegen: Orval (from OpenAPI spec)
- Build: esbuild (CJS bundle)

## Where things live

- `lib/api-spec/openapi.yaml` — OpenAPI source of truth
- `lib/db/src/schema/orders.ts` — orders table
- `lib/db/src/schema/users.ts` — users table
- `artifacts/brew-bean/src/lib/firebase.ts` — Firebase init
- `artifacts/brew-bean/src/lib/auth.ts` — PIN logic & login
- `artifacts/brew-bean/src/context/AuthContext.tsx` — auth state
- `artifacts/brew-bean/src/context/CartContext.tsx` — cart state
- `artifacts/brew-bean/src/pages/` — all page components
- `artifacts/brew-bean/src/data/menu.ts` — hardcoded menu data
- `artifacts/brew-bean/public/images/` — AI-generated menu images
- `artifacts/api-server/src/routes/orders.ts` — orders API
- `artifacts/api-server/src/routes/users.ts` — users API

## Architecture decisions

- Custom phone PIN auth (no SMS OTP): PIN derived from phone digits using a deterministic formula. Firebase Anonymous Auth is used as the identity layer, with Firestore storing phone + role.
- UPI-only payments: No Stripe. Orders are created in PostgreSQL; payment screenshots stored in Firebase Storage. Admin manually approves/rejects.
- Dual storage: PostgreSQL (via Drizzle) for orders/users API, Firestore for real-time auth user profile sync. These are kept in sync on login.
- Admin role: Controlled by `VITE_ADMIN_PHONE` env var — if the logged-in phone matches, role is set to `admin`.
- Menu is hardcoded on the frontend — no CMS needed for a cafe menu.

## Product

- **Homepage** — cinematic hero, featured coffee/tea/specials sections, testimonials, CTA, footer (public, no auth required)
- **Menu** — full browsable menu with category filters and Add to Cart
- **Cart** — cart management with localStorage persistence
- **Checkout** — UPI payment with PhonePe/GPay/Paytm deep links, QR code, screenshot upload
- **Profile** — order history with payment/order status badges
- **Admin** (/admin) — order management (approve/reject), user management

## User preferences

- Dark luxury coffee theme (deep dark brown, amber/gold primary, Playfair Display + Inter fonts)
- Indian market: INR pricing, UPI payments, Indian phone numbers
- No emojis in UI
- Admin phone configurable via VITE_ADMIN_PHONE env var

## Gotchas

- Firebase Anonymous Auth is used — each login with the same phone generates a new Firebase UID. For production, consider linking accounts via phone verification or storing the Firebase UID in a cookie after first login.
- `VITE_ADMIN_PHONE` must be set to 10 digits (no country code) to grant admin access.
- UPI deep links only work on mobile devices with payment apps installed. On desktop, users should use the QR code or copy UPI ID.
- Firebase Storage rules need to be configured in the Firebase Console to allow authenticated uploads (max 5MB).

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
