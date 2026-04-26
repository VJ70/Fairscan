# FairScan — Complete Setup Guide
## Project IDX + Firebase (Zero billing required)

---

## Step 1 — Push to GitHub

```bash
cd fairscan-idx
git init
git branch -m main
git add .
git config user.email "you@email.com"
git config user.name "Your Name"
git commit -m "Initial commit: FairScan - AI Fairness Auditor"
git remote add origin https://github.com/YOUR_USERNAME/FairScan.git
git push -u origin main
```

---

## Step 2 — Open in Project IDX

1. Go to **idx.google.com**
2. Click **"Import a repo"**
3. Paste your GitHub URL
4. IDX installs Flutter, Python, Firebase CLI automatically via dev.nix ✅
5. Wait ~2 minutes for workspace to boot

---

## Step 3 — Create Firebase Project (free)

1. Go to **console.firebase.google.com**
2. Click "Add project" → name it **fairscan-2026**
3. Disable Google Analytics (not needed)
4. Enable these (all free tier):
   - **Authentication** → Google sign-in provider
   - **Firestore** → Start in test mode → pick `asia-south1`
   - **Storage** → Start in test mode
   - **Functions** → Upgrade to Blaze plan (required for Python functions)
     > ⚠️ Blaze plan is pay-as-you-go. At demo scale you will pay $0.
     > Free tier: 2M function calls/month, 400K GB-seconds compute
5. Go to Project Settings → copy your **Web app config**

---

## Step 4 — Get Gemini API Key (free)

1. Go to **aistudio.google.com/app/apikey**
2. Click "Create API Key"
3. Copy the key

---

## Step 5 — Configure in IDX terminal

```bash
# In the IDX terminal:

# Login to Firebase
firebase login --no-localhost

# Set your project
firebase use fairscan-2026

# Set Gemini secret (paste your key when prompted)
firebase functions:secrets:set GEMINI_API_KEY

# Install function dependencies
cd functions
pip install -r requirements.txt
cd ..
```

---

## Step 6 — Update Firebase config in Flutter

Open `flutter_app/lib/main.dart` and replace the FirebaseOptions with your project's values:

```dart
// Get these from: Firebase Console → Project Settings → Your apps → Web app
options: const FirebaseOptions(
  apiKey:            "AIza...",        // from Firebase console
  authDomain:        "fairscan-2026.firebaseapp.com",
  projectId:         "fairscan-2026",
  storageBucket:     "fairscan-2026.appspot.com",
  messagingSenderId: "123456789",      // from Firebase console
  appId:             "1:123...",       // from Firebase console
),
```

OR use the recommended way (auto-generates the config):
```bash
cd flutter_app
dart pub global activate flutterfire_cli
flutterfire configure --project=fairscan-2026
# This creates firebase_options.dart automatically
```

---

## Step 7 — Test locally with emulators

```bash
# Terminal 1: start Firebase emulators
firebase emulators:start

# Terminal 2: run Flutter web
cd flutter_app
flutter run -d web-server --web-port 3000

# Open: http://localhost:3000
```

IDX also shows a live preview automatically in the sidebar.

---

## Step 8 — Deploy everything 🚀

```bash
# Build Flutter web
cd flutter_app
flutter build web --release
cp -r build/web/* ../public/
cd ..

# Deploy functions + hosting + rules in one command
firebase deploy

# Done! Your app is live at:
# https://fairscan-2026.web.app
```

---

## What gets deployed

| Component | Where |
|-----------|-------|
| Flutter Web UI | Firebase Hosting (CDN) |
| Bias detection | Firebase Functions (Python) |
| Gemini reports | Firebase Functions → Gemini API |
| User data | Firestore |
| CSV uploads | Firebase Storage |
| Auth | Firebase Auth |

---

## Costs (all free at demo scale)

| Service | Free tier | Your usage |
|---------|-----------|-----------|
| Firebase Functions | 2M calls/month | ~500 |
| Firestore | 50k reads, 20k writes/day | ~100 |
| Firebase Storage | 5 GB | <1 GB |
| Firebase Hosting | 10 GB/month | <1 GB |
| Gemini API | 60 QPM free | ~500 calls |
| **Total** | | **$0** |

---

## Troubleshooting

**"Functions must be on Blaze plan"**
→ In Firebase console, click "Upgrade" → Blaze. Enter a card (won't be charged at demo scale).

**"GEMINI_API_KEY not found"**
→ Run: `firebase functions:secrets:set GEMINI_API_KEY` again in IDX terminal.

**"flutter: command not found" in IDX**
→ IDX installs Flutter automatically. Wait for workspace setup to complete (check the status bar).

**CORS error from Flutter web**
→ Firebase Functions callable functions handle CORS automatically. Make sure you're using `cloud_functions` package (not direct HTTP calls).
