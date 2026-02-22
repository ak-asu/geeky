# Mobile Testing Setup — Cloudflare Tunnel + Firebase Spark + Gemini

Complete step-by-step guide to test your Flutter Geeky app on real phones (5 users, ~200MB) with zero billing.

**Time required:** ~45 minutes total
**No credit card required**

---

## Overview

```
Your Laptop (localhost:8000)
    ↓
[Cloudflare Tunnel] — HTTPS tunnel (no server needed)
    ↓
Public URL (https://geeky-api.cfargotunnel.com)
    ↓
Phone 1-5 (ANY network — WiFi, cellular)
```

All persistent data lives in cloud Firebase, so restarting your laptop doesn't lose data.

---

## Step 1: Create Firebase Spark Project (Free, No Card) — 10 min

### 1.1 Create Firebase Project

1. Go to **console.firebase.google.com** (no card needed — Spark plan is always free)
2. Click **"Add project"**
3. **Project name:** `geeky-mobile-test` (or any name)
4. **Location:** Leave as default (US)
5. Click **Create project** — wait 2-3 minutes

### 1.2 Enable Services (All Free on Spark)

**Cloud Firestore:**
- In Firebase console → **Firestore Database** (left sidebar)
- Click **Create Database**
- **Location:** `nam5` (North America)
- **Security rules:** Start in **test mode** (allows all reads/writes — fine for testing)
- Click **Create**

**Authentication:**
- **Authentication** (left sidebar) → **Get Started**
- **Sign-in method** → Enable **Email/Password** (click the icon, toggle **Enable**, Save)
- Optionally enable **Google** (just toggle on, click Save)

**Cloud Messaging (optional, for notifications):**
- **Messaging** (left sidebar) — just view the key for now, we won't use it yet

### 1.3 Get Firebase Credentials

**Option A: Service Account (Recommended for backend)**

1. **Project Settings** (gear icon, top right) → **Service Accounts**
2. **Language:** Python (dropdown)
3. Click **Generate new private key** → downloads `geeky-mobile-test-firebase-adminsdk-*.json`
4. **Copy this file** → save as `backend/credentials/firebase-sa.json` (create the `credentials/` folder if it doesn't exist)

**Option B: Just use Project ID (Simpler)**

1. **Project Settings** → **General** tab
2. Copy **Project ID** (you'll need this for `.env`)

### 1.4 Download Flutter google-services.json

For the Flutter app to authenticate:

1. **Project Settings** → **General** tab
2. Scroll down → under "Your apps" → click the Android app icon (or create one if not present)
3. If creating: **Package name:** `com.example.geeky` (or match your Flutter app's package name)
4. Click **Register app**
5. Step 1 (Google Services): **Download `google-services.json`**
6. **Copy file** → replace `android/app/google-services.json` in your Flutter project

---

## Step 2: Get Gemini API Key (Free, 250 req/day) — 5 min

1. Go to **aistudio.google.com** (Google AI Studio)
2. Click **Get API key** (top right)
3. Click **Create API key in new project**
4. Copy the key (it starts with `AIzaSy...`)
5. **Save it securely** — you'll add it to `.env` in Step 4

---

## Step 3: Set Up Cloudflare Tunnel (Free, No Card) — 15 min

Cloudflare Tunnel creates a publicly accessible HTTPS URL pointing to your `localhost:8000`.

### 3.1 Create Cloudflare Account

1. Go to **cloudflare.com** → **Sign up** (no card needed for free account)
2. After signing in, go to **[one.dash.cloudflare.com](https://one.dash.cloudflare.com)**
3. In the left sidebar, go to **Networks → Connectors → Cloudflare Tunnels**
4. Click **Create a tunnel**
5. Choose **Cloudflared** as the connector type → click **Next**
6. **Name:** `geeky-local` → Click **Save tunnel**

### 3.2 Install Cloudflared

**Windows:**

```powershell
# Option 1: Using winget (recommended)
winget install cloudflare.cloudflared

# Option 2: Manual download
# Go to https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
# Download cloudflared.exe for Windows
# Add to PATH or run from current directory
```

**macOS:**
```bash
brew install cloudflare/cloudflare/cloudflared
```

**Linux:**
```bash
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-x86_64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

### 3.3 Run the Tunnel

**Recommended — Quick Tunnel (zero config, no domain needed):**

Skip all dashboard configuration and just run:

```bash
# Linux / macOS
cloudflared tunnel --url http://localhost:8000

# Windows (PowerShell)
.\cloudflared.exe tunnel --url http://localhost:8000
```

Cloudflare will print a random free HTTPS URL in the output, e.g.:
```
INF +--------------------------------------------------------------------------------------------+
INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
INF |  https://abc-def-ghi.trycloudflare.com                                                      |
INF +--------------------------------------------------------------------------------------------+
```

**Copy that URL** — use it as `API_BASE_URL` in Step 6. No account, no domain, no extra config needed.

**Keep this running in a terminal** — your tunnel is active as long as the process runs.

---

**Alternative — Use your existing named tunnel (requires a domain in Cloudflare):**

If you have a domain managed by Cloudflare and want a stable URL:

1. In **[one.dash.cloudflare.com](https://one.dash.cloudflare.com)** → **Networks → Connectors → Cloudflare Tunnels**
2. Click on your tunnel name (`geeky-local`)
3. Click **Edit** → go to the **Public Hostnames** tab
4. Click **Add a public hostname**:
   - **Subdomain:** `geeky-api`
   - **Domain:** your Cloudflare domain
   - **Type:** HTTP  /  **URL:** `localhost:8000`
   - Click **Save hostname**
5. Get the token: click the **...** menu on your tunnel → **Configure** → copy the `--token` value
6. Run it:
   ```bash
   cloudflared tunnel --no-autoupdate run --token <YOUR_TUNNEL_TOKEN>
   ```

Your URL will be: `https://geeky-api.yourdomain.com`

**Verify it works:**

```bash
# From a browser on any device:
curl https://your-tunnel-url.com/health

# Should return: {"status":"ok"} or similar
```

---

## Step 4: Configure Backend .env — 5 min

### 4.1 Create `.env` File

```bash
cd backend
cp .env.example .env
```

### 4.2 Edit `.env` with Your Credentials

Replace these sections in `backend/.env`:

```bash
# === App ===
APP_NAME=Geeky API
APP_VERSION=0.1.0
DEBUG=true
ENVIRONMENT=development
LOG_LEVEL=INFO
CORS_ORIGINS=["*"]  # Allow all origins for testing

# === Firebase ===
# Option 1: Path to service account JSON (recommended, if you downloaded it in Step 1.3)
FIREBASE_CREDENTIALS_PATH=./credentials/firebase-sa.json

# Option 2: Or just use project ID (if ADC or GOOGLE_APPLICATION_CREDENTIALS is set)
FIREBASE_PROJECT_ID=geeky-mobile-test

# === Gemini AI ===
GEMINI_API_KEY=AIzaSy_YOUR_KEY_HERE           # Paste your key from Step 2
GEMINI_MODEL=gemini-2.5-flash
GEMINI_EMBEDDING_MODEL=models/embedding-001
GEMINI_EMBEDDING_DIMENSIONS=768

# === ChromaDB ===
CHROMADB_HOST=chromadb                        # Docker service name (keep as is)
CHROMADB_PORT=8000
CHROMADB_COLLECTION_NAME=geeky_chunks

# === Redis / Celery ===
REDIS_URL=redis://redis:6379/0                # Docker service name (keep as is)
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/1

# === Pipeline ===
PIPELINE_MAX_CONCURRENT=10
PIPELINE_TIMEOUT_SECONDS=30
CHUNK_TARGET_WORDS=1000
CHUNK_OVERLAP_WORDS=200
DEDUP_SEMANTIC_THRESHOLD=0.85
DEDUP_NEAR_THRESHOLD=0.9
ANTI_DENSITY_MAX_PER_SOURCE=50

# === RAG ===
RAG_TOP_K=10
RAG_MMR_LAMBDA=0.7
RAG_CONTEXT_MAX_TOKENS=4000
RAG_REDUNDANCY_THRESHOLD=0.92

# === Recommendation ===
REC_WEIGHT_RELEVANCE=0.4
REC_WEIGHT_CAPABILITY=0.3
REC_WEIGHT_NOVELTY=0.3

# === FSRS ===
FSRS_DESIRED_RETENTION=0.9

# === Source Polling ===
SOURCE_POLL_INTERVAL_MINUTES=60
```

**Important:**
- Replace `AIzaSy_YOUR_KEY_HERE` with your actual Gemini key from Step 2
- Replace `geeky-mobile-test` with your Firebase project ID
- Keep Docker service names as-is (chromadb, redis, etc.)

---

## Step 5: Start Backend Services — 5 min

**In a new terminal (keep Cloudflare tunnel running in another terminal):**

```bash
cd backend

# Start all services (API + worker + beat + ChromaDB + Redis)
docker-compose up

# Wait for "Uvicorn running on http://0.0.0.0:8000"
# And "chromadb" to show healthy
# And "redis" to show healthy
```

**Verify backend is running:**

```bash
# From your laptop browser:
curl http://localhost:8000/health

# Should see: {"status":"ok"}
```

---

## Step 6: Build & Deploy Flutter App to Phone — 5 min

### 6.1 Get Your Tunnel URL

From Step 3.4, note your tunnel URL. Example: `https://geeky-api.cfargotunnel.com`

### 6.2 Build APK (Android)

```bash
# Navigate to Flutter project root
cd path/to/geeky

# Build APK with your tunnel URL
flutter build apk \
  --dart-define=API_BASE_URL=https://your-tunnel-url-here.com \
  --release

# Release (install a release build on connected Android device)
flutter run --release --dart-define=API_BASE_URL=https://abc-def-ghi.trycloudflare.com -d <device-id>

# APK will be at: build/app/outputs/flutter-app/release/app-release.apk
```

**Replace `your-tunnel-url-here.com` with your actual tunnel URL!**

### 6.3 Install on Phone

```bash
# Option 1: Using adb (USB debugging enabled on phone)
adb install build/app/outputs/flutter-app/release/app-release.apk

# Option 2: Copy to phone via USB and install manually
# Or send the APK file via email/Slack and install from phone's file browser
```

### 6.4 Verify on Phone

1. Open Geeky app on phone
2. **Sign up** with email + password (using Firebase Auth)
3. You should be able to:
   - Create a note
   - See it appear in Firestore console on your laptop
   - Trigger background processing (shorts, flashcards generation — the Celery worker on your laptop will process these)

---

## Testing Checklist

| What | Expected | How to Verify |
|------|----------|---------------|
| Phone can reach backend | HTTP 200 on `/health` | Phone browser: visit tunnel URL + `/health` |
| Phone can authenticate | Sign up/login works | Try create account in app |
| Note creation | Note appears in Firestore | Create note → check `notes/{userId}/data/{noteId}` in Firestore console |
| Processing | Shorts/flashcards generated | Create note → wait 30s → check backend logs for Celery tasks |
| Search/RAG | Search returns results | Create note → search for keyword in app |
| Cost | $0 | Check Firebase console billing (it says free) |

---

## Troubleshooting

### Phone can't reach tunnel URL

**Problem:** Phone gets connection timeout or DNS error

**Solutions:**
1. Verify `cloudflared tunnel run` is still running on your laptop
2. Verify the URL in Flutter build command matches your tunnel URL exactly
3. Try from phone browser first: `https://your-tunnel-url/health` in phone's browser
4. Check Cloudflare dashboard → Tunnels → Analytics → see if requests are coming through

### Firebase auth fails on phone

**Problem:** "Invalid sign-up response" or 401 errors

**Solutions:**
1. Verify `google-services.json` is correct (downloaded from Firebase console)
2. In Firestore console → **Authentication** → make sure Email/Password is enabled
3. Try creating an account directly in Firebase console first (Authentication tab → Create user)

### Backend can't connect to Firebase

**Problem:** 401 / 403 errors, "Permission denied" in backend logs

**Solutions:**
1. Verify `firebase-sa.json` exists at `backend/credentials/firebase-sa.json`
2. Verify `FIREBASE_PROJECT_ID` in `.env` matches your actual project ID
3. Check Firebase console → **Firestore Database** → **Rules** allow reads/writes (should say "test mode")
4. Verify `FIRESTORE_CREDENTIALS_PATH` in `.env` is correct

### Celery worker not processing tasks

**Problem:** Notes created but no shorts/flashcards generated, worker logs show nothing

**Solutions:**
1. Check `docker-compose up` output — ensure **worker** service is running (not just api)
2. Check Redis is running: `redis-cli ping` should return "PONG"
3. Look at worker logs: `docker-compose logs worker` — see errors
4. Verify `CELERY_BROKER_URL` in `.env` is `redis://redis:6379/0`

### Gemini API key not found

**Problem:** Backend returns "Gemini API key not configured" error

**Solutions:**
1. Verify `GEMINI_API_KEY` is in `.env` (not commented out)
2. Verify key starts with `AIzaSy`
3. Verify key is from **aistudio.google.com** (not GCP console)
4. Try creating a new key in AI Studio if old one doesn't work

---

## What's Next?

### To Add More Testers

1. Ask testers to sign up with their own email in the app
2. Each user is auto-isolated (Firestore security rules enforce `user_id` filtering)
3. No additional setup needed — they can use the app via the tunnel URL

### To Make It Production-Ready

Once testing is done, move to **Option 2** in the initial guide:
- Deploy API to Render (free tier)
- Use Supabase pgvector for cloud vector storage
- Testers can use the app 24/7 without your laptop

### To Use Real Cloud (GCP)

- Swap Render for Cloud Run
- Swap Supabase for Vertex AI Matching Engine (requires billing)
- Same code, just different `dependencies.py` wiring

---

## Files Changed / Created

```
backend/
  .env                          # Created from .env.example with your credentials
  credentials/
    firebase-sa.json            # Downloaded from Firebase console

android/app/
  google-services.json          # Downloaded from Firebase console
```

**No code changes needed** — just configuration.

---

## Keep Running

**Terminal 1 (Cloudflare Tunnel — keep running):**
```bash
cloudflared tunnel --url http://localhost:8000
```

**Terminal 2 (Backend services — keep running):**
```bash
cd backend
docker-compose up
```

**Phone:** Open Geeky app → test

---

## Support

**Get help on:**
- Firebase Spark setup: https://firebase.google.com/docs/projects/learn-more
- Cloudflare Tunnels: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
- Gemini API: https://ai.google.dev/

Good luck! 🚀
