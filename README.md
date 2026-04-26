---
title: Fairscan Backend
emoji: 🚀
colorFrom: blue
colorTo: green
sdk: docker
pinned: false
---
# FairScan — AI Fairness Auditor
> Google Solution Challenge 2026 · SDG 10: Reduced Inequalities · SDG 16: Peace & Justice

FairScan lets any organisation upload their AI decision dataset (hiring, loans, healthcare) and instantly receive a plain-language bias audit report powered by Gemini AI — no coding required.

---

## What it does

1. **Upload** a CSV of AI decisions (e.g. loan approvals, job shortlists)
2. **Scan** — computes demographic parity, disparate impact, equalized odds
3. **Explain** — Gemini 1.5 Pro generates a plain-language report citing Indian law
4. **Fix** — Vertex AI recommends concrete remediation steps
5. **Export** — Download a compliance-ready PDF audit report

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (iOS + Android + Web) |
| Backend API | Python FastAPI on Cloud Run |
| AI Reports | Gemini 1.5 Pro API |
| ML Scoring | Vertex AI |
| Auth | Firebase Authentication |
| Database | Firestore |
| File Storage | Cloud Storage |
| Analytics | BigQuery |

---

## Quick Start

### 1. Clone & setup GCP
```bash
git clone https://github.com/YOUR_USERNAME/fairscan.git
cd fairscan

gcloud projects create fairscan-2026 --name="FairScan"
gcloud config set project fairscan-2026
gcloud services enable run.googleapis.com aiplatform.googleapis.com \
  firestore.googleapis.com storage.googleapis.com bigquery.googleapis.com
```

### 2. Backend (Cloud Run)
```bash
cd backend
cp .env.example .env   # fill in your keys
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### 3. Deploy backend
```bash
gcloud run deploy fairscan-api \
  --source . \
  --region asia-south1 \
  --allow-unauthenticated
```

### 4. Flutter frontend
```bash
cd frontend
flutter pub get
flutter run
# Web deploy:
flutter build web && firebase deploy --only hosting
```

---

## SDG Alignment
- **SDG 10** — Reduced Inequalities
- **SDG 16** — Peace, Justice & Strong Institutions  
- **SDG 8** — Decent Work & Economic Growth

## License
MIT
