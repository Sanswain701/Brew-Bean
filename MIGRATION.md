# Brew & Bean — Migration Guide

How to export your data from Replit and import it into any PostgreSQL host.

---

## 1. Database Export from Replit

### Full dump (schema + data)

In the Replit shell:
```bash
pg_dump "$DATABASE_URL" > brew_bean_backup.sql
```

This creates a complete dump including the schema and all order data.

### Data only (no schema)

```bash
pg_dump "$DATABASE_URL" --data-only > brew_bean_data.sql
```

### Schema only (no data)

```bash
pg_dump "$DATABASE_URL" --schema-only > brew_bean_schema.sql
```

Alternatively, use the provided `migration.sql` file at the root of this repo — it recreates the schema from scratch.

---

## 2. Import to a New PostgreSQL Server

### Fresh database (recommended)

```bash
# 1. Create the database
createdb brew_bean
# Or for a cloud provider, create the DB in the dashboard.

# 2. Apply schema + data from the full dump
psql "$NEW_DATABASE_URL" < brew_bean_backup.sql

# 3. Verify
psql "$NEW_DATABASE_URL" -c "SELECT COUNT(*) FROM orders;"
```

### Schema only (then import data separately)

```bash
psql "$NEW_DATABASE_URL" -f migration.sql
psql "$NEW_DATABASE_URL" < brew_bean_data.sql
```

### Cloud providers — connection strings

| Provider | Example connection string |
|----------|--------------------------|
| Supabase | `postgres://postgres.xxxx:password@aws-0-ap-south-1.pooler.supabase.com:6543/postgres` |
| Neon | `postgres://user:password@ep-xxx.ap-southeast-1.aws.neon.tech/brew_bean?sslmode=require` |
| Railway | `postgres://postgres:password@containers-us-west-xxx.railway.app:5432/railway` |
| Aiven | `postgres://avnadmin:password@pg-xxx.aivencloud.com:12345/defaultdb?sslmode=require` |

Add `?sslmode=require` for cloud providers that require SSL.

---

## 3. File Storage Migration (Payment Screenshots)

Payment screenshots uploaded by customers are stored locally in:
```
artifacts/api-server/uploads/
```

### Export from Replit

Download the entire uploads directory:
```bash
# In Replit shell — create a tar archive
tar -czf uploads_backup.tar.gz artifacts/api-server/uploads/
```

Then download `uploads_backup.tar.gz` from the Replit file panel.

### Import to Docker / VPS

```bash
# Copy to the server
scp uploads_backup.tar.gz user@your-server:/tmp/

# Extract into Docker volume (app must be running)
tar -xzf /tmp/uploads_backup.tar.gz
docker cp artifacts/api-server/uploads/. $(docker compose ps -q app):/app/uploads/

# Or for VPS without Docker
tar -xzf /tmp/uploads_backup.tar.gz -C /path/to/brew-bean/
```

### Migrate to Cloud Storage (Optional — for Vercel)

Vercel is serverless and has no persistent disk. If you deploy the backend on Vercel Functions (not recommended for this app) or want off-server storage, migrate uploads to an object storage service.

**Recommended: Cloudflare R2 (free tier, S3-compatible)**

1. Create an R2 bucket at [dash.cloudflare.com](https://dash.cloudflare.com)
2. Install the AWS SDK:
   ```bash
   pnpm --filter @workspace/api-server add @aws-sdk/client-s3 @aws-sdk/s3-request-presigner
   ```
3. Update `artifacts/api-server/src/routes/upload.ts` to use S3 client instead of `multer` disk storage
4. Add environment variables:
   ```env
   S3_ENDPOINT=https://xxx.r2.cloudflarestorage.com
   S3_ACCESS_KEY_ID=your_access_key
   S3_SECRET_ACCESS_KEY=your_secret_key
   S3_BUCKET=brew-bean-uploads
   S3_PUBLIC_URL=https://pub-xxx.r2.dev
   ```
5. Upload existing files:
   ```bash
   # Using AWS CLI with R2 endpoint
   aws s3 sync artifacts/api-server/uploads/ s3://brew-bean-uploads/ \
     --endpoint-url https://xxx.r2.cloudflarestorage.com
   ```

---

## 4. Environment Migration Checklist

When moving from Replit to a new host:

- [ ] Export `DATABASE_URL` value from Replit Secrets
- [ ] Export `VITE_ADMIN_PHONE` and `VITE_ADMIN_PIN`
- [ ] Export `VITE_UPI_ID` and `VITE_UPI_NAME`
- [ ] Download `artifacts/api-server/uploads/` directory
- [ ] Run database dump from Replit shell
- [ ] Apply dump to new database
- [ ] Update `DATABASE_URL` in new host environment
- [ ] Rebuild frontend with new env vars baked in
- [ ] Test admin login at `/admin-login`
- [ ] Test customer checkout flow end-to-end
- [ ] Confirm uploaded screenshots are accessible

---

## 5. Data Verification After Migration

Run these queries to confirm data integrity:

```sql
-- Total order count
SELECT COUNT(*) as total_orders FROM orders;

-- Orders by status
SELECT payment_status, COUNT(*) as count
FROM orders
GROUP BY payment_status;

-- Most recent 5 orders
SELECT order_id, customer_name, total_amount, payment_status, created_at
FROM orders
ORDER BY created_at DESC
LIMIT 5;

-- Check for any null required fields
SELECT COUNT(*) as invalid
FROM orders
WHERE order_id IS NULL
   OR user_id IS NULL
   OR phone_number IS NULL
   OR items IS NULL
   OR total_amount IS NULL;
```

Expected: `invalid` count = 0.
