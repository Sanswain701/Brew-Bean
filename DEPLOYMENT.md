# Brew & Bean — Deployment Guide

Three deployment options are available. Choose the one that fits your setup.

---

## Option A: Docker (Recommended for VPS / Self-Hosting)

The simplest production setup — everything runs in a single container alongside a bundled PostgreSQL database.

### Prerequisites
- A server with Docker and Docker Compose installed
- A domain name (optional but recommended for HTTPS)

### Steps

**1. Clone the repo on your server**
```bash
git clone https://github.com/YOUR_USERNAME/brew-bean.git
cd brew-bean
```

**2. Configure environment**
```bash
cp .env.example .env
nano .env   # fill in all required values
```

Key values to set:
```env
VITE_ADMIN_PHONE=9999999999
VITE_ADMIN_PIN=yourpin
VITE_UPI_ID=yourname@upi
VITE_UPI_NAME=Brew & Bean
POSTGRES_PASSWORD=a-strong-password
```

**3. Build and start**
```bash
docker compose up -d --build
```

The app will be available at `http://your-server-ip:8080`.

**4. Apply database schema (first run only)**

The `migration.sql` file is automatically mounted and applied when the Postgres container starts for the first time. No manual step needed.

**5. Configure HTTPS with Nginx (recommended)**

Install Nginx and Certbot:
```bash
sudo apt install nginx certbot python3-certbot-nginx
```

Create `/etc/nginx/sites-available/brew-bean`:
```nginx
server {
    server_name yourdomain.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 10M;
    }
}
```

Enable and get SSL certificate:
```bash
sudo ln -s /etc/nginx/sites-available/brew-bean /etc/nginx/sites-enabled/
sudo certbot --nginx -d yourdomain.com
sudo systemctl reload nginx
```

### Maintenance

```bash
# View logs
docker compose logs -f app

# Update after a code push
git pull
docker compose up -d --build

# Backup the database
docker compose exec postgres pg_dump -U brewbean brew_bean > backup-$(date +%Y%m%d).sql

# Restore from backup
cat backup.sql | docker compose exec -T postgres psql -U brewbean -d brew_bean

# Backup uploaded files
docker cp $(docker compose ps -q app):/app/uploads ./uploads-backup-$(date +%Y%m%d)
```

---

## Option B: Vercel (Frontend) + Railway (Backend)

Best for low-traffic deployments where you want zero server management.

### Part 1: Deploy the backend on Railway

1. Create an account at [railway.app](https://railway.app)
2. New Project → Deploy from GitHub → select your repo
3. Railway auto-detects `railway.toml` and builds the backend
4. Add a **Postgres** plugin in the Railway dashboard — it injects `DATABASE_URL` automatically
5. Add environment variables in Railway dashboard:
   ```
   PORT=8080
   NODE_ENV=production
   CORS_ORIGIN=https://your-project.vercel.app
   ```
6. Note your Railway backend URL (e.g. `https://brew-bean-api.up.railway.app`)

### Part 2: Deploy the frontend on Vercel

1. Create an account at [vercel.com](https://vercel.com)
2. Import your GitHub repository
3. Vercel auto-detects `vercel.json` — no framework override needed
4. Add environment variables in Vercel dashboard:
   ```
   PORT=8080
   BASE_PATH=/
   VITE_ADMIN_PHONE=9999999999
   VITE_ADMIN_PIN=yourpin
   VITE_UPI_ID=yourname@upi
   VITE_UPI_NAME=Brew & Bean
   VITE_API_URL=https://brew-bean-api.up.railway.app
   ```
5. Deploy

> **Important**: `VITE_API_URL` must be set **before** the first build on Vercel. This value gets baked into the JavaScript bundle. If you change the backend URL later, you must redeploy the frontend.

### Part 3: Apply the database schema

```bash
# Using the Railway DATABASE_URL (shown in Railway dashboard)
psql "postgres://..." -f migration.sql
```

---

## Option C: Manual VPS (Ubuntu)

For full control without Docker.

### Setup

```bash
# Install Node.js 24
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo bash -
sudo apt install -y nodejs

# Install pnpm
npm install -g pnpm

# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql -c "CREATE USER brewbean WITH PASSWORD 'yourpassword';"
sudo -u postgres psql -c "CREATE DATABASE brew_bean OWNER brewbean;"

# Apply schema
psql "postgres://brewbean:yourpassword@localhost:5432/brew_bean" -f migration.sql
```

### Build

```bash
# Clone and install
git clone https://github.com/YOUR_USERNAME/brew-bean.git
cd brew-bean
pnpm install

# Build backend
pnpm --filter @workspace/api-server run build

# Build frontend (fill in your values)
VITE_ADMIN_PHONE=9999999999 \
VITE_ADMIN_PIN=yourpin \
VITE_UPI_ID=yourname@upi \
VITE_UPI_NAME="Brew & Bean" \
PORT=8080 \
BASE_PATH=/ \
pnpm --filter @workspace/brew-bean run build
```

### Run with PM2 (process manager)

```bash
npm install -g pm2

DATABASE_URL="postgres://brewbean:yourpassword@localhost:5432/brew_bean" \
FRONTEND_DIST="$(pwd)/artifacts/brew-bean/dist/public" \
PORT=8080 \
pm2 start artifacts/api-server/dist/index.mjs --name brew-bean

# Auto-start on reboot
pm2 save
pm2 startup
```

### Update

```bash
cd /path/to/brew-bean
git pull
pnpm install
pnpm --filter @workspace/api-server run build
# Rebuild frontend if VITE_ vars changed
pm2 restart brew-bean
```
