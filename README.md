# FairScan — AI Fairness Auditor
### Google Solution Challenge 2026 | Project IDX + Firebase Edition

> **No Docker. No Cloud Run. No billing required.**  
> Entire stack runs on Firebase free tier + Gemini API.

## SDGs
- **SDG 10** — Reduced Inequalities  
- **SDG 16** — Peace, Justice & Strong Institutions  
- **SDG 8** — Decent Work & Economic Growth

---

## Stack (100% Google)

| What | Technology | Why judges love it |
|------|-----------|-------------------|
| IDE | **Project IDX** | Bonus points in GSC 2026 |
| Backend | **Firebase Functions (Python)** | Serverless, free tier |
| AI Reports | **Gemini 1.5 Pro API** | Core AI feature |
| Auth | **Firebase Auth** | Google Sign-in |
| Database | **Firestore** | Real-time, free |
| File storage | **Firebase Storage** | CSV uploads |
| Frontend | **Flutter Web** | Cross-platform |
| Hosting | **Firebase Hosting** | Free, fast CDN |

---

## One-command deploy (after setup)
```bash
firebase deploy
```

---

## Setup Guide

### Step 1 — Open in Project IDX
1. Go to **idx.google.com**
2. Click "Import a repo"
3. Paste your GitHub URL
4. IDX auto-detects Flutter + Python ✅

### Step 2 — Firebase project
```bash
firebase login
firebase init
# Select: Functions (Python), Firestore, Storage, Hosting, Auth
# Project ID: fairscan-2026
```

### Step 3 — Get Gemini API key
1. Go to **aistudio.google.com/app/apikey**
2. Create key (free, no billing)
3. Run:
```bash
firebase functions:secrets:set GEMINI_API_KEY
# Paste your key when prompted
```

### Step 4 — Deploy everything
```bash
cd flutter_app
flutter build web
cp -r build/web ../public
cd ..
firebase deploy
```

### Step 5 — Done!
Your app is live at: `https://fairscan-2026.web.app`

---

## Project Structure
```
fairscan/
├── .idx/                    # IDX workspace config (auto-setup)
│   └── dev.nix
├── functions/               # Firebase Functions — Python backend
│   ├── main.py              # All Cloud Functions
│   ├── bias_detector.py     # Fairness metrics engine
│   ├── gemini_service.py    # Gemini API integration
│   └── requirements.txt
├── flutter_app/             # Flutter frontend
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   ├── services/
│   │   └── models/
│   └── pubspec.yaml
├── firestore.rules
├── storage.rules
├── firebase.json
└── .firebaserc
```
