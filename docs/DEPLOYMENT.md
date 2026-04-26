# Deployment Guide

## 1. Google Cloud Setup

```bash
# Create project
gcloud projects create fairscan-2026 --name="FairScan"
gcloud config set project fairscan-2026
gcloud billing projects link fairscan-2026 --billing-account=YOUR_BILLING_ACCOUNT

# Enable APIs
gcloud services enable \
  run.googleapis.com \
  aiplatform.googleapis.com \
  firestore.googleapis.com \
  storage.googleapis.com \
  bigquery.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com

# Create Artifact Registry repo
gcloud artifacts repositories create fairscan \
  --repository-format=docker \
  --location=asia-south1
```

## 2. Get Your API Keys

### Gemini API Key
1. Go to https://aistudio.google.com/app/apikey
2. Create new API key
3. Add to .env: GEMINI_API_KEY=your_key

### Firebase Setup
```bash
npm install -g firebase-tools
firebase login
firebase init   # select: Firestore, Storage, Hosting, Authentication
```

## 3. Deploy Backend to Cloud Run

```bash
cd backend
cp .env.example .env
# Edit .env with your values

# Option A: Deploy from source (easiest)
gcloud run deploy fairscan-api \
  --source . \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars "GCP_PROJECT=fairscan-2026,GEMINI_API_KEY=your_key"

# Option B: Build + push Docker manually
docker build -t asia-south1-docker.pkg.dev/fairscan-2026/fairscan/api:latest .
docker push asia-south1-docker.pkg.dev/fairscan-2026/fairscan/api:latest
gcloud run deploy fairscan-api \
  --image asia-south1-docker.pkg.dev/fairscan-2026/fairscan/api:latest \
  --region asia-south1
```

After deploy, get your URL:
```bash
gcloud run services describe fairscan-api --region asia-south1 --format 'value(status.url)'
```

## 4. Deploy Flutter Web to Firebase Hosting

```bash
cd frontend
# Update API_BASE_URL in lib/services/api_service.dart with your Cloud Run URL

flutter build web --dart-define=API_BASE_URL=https://your-cloudrun-url/api/v1
firebase deploy --only hosting
```

## 5. Set Up CI/CD (optional but impressive for judges)

```bash
# Connect Cloud Build to your GitHub repo
gcloud beta builds triggers create github \
  --repo-name=fairscan \
  --repo-owner=YOUR_GITHUB_USERNAME \
  --branch-pattern=main \
  --build-config=deploy/cloudrun/cloudbuild.yaml
```

## 6. Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

## Environment Variables Summary

| Variable | Where to get it |
|----------|----------------|
| GEMINI_API_KEY | https://aistudio.google.com/app/apikey |
| GCP_PROJECT | Your GCP project ID |
| FIREBASE_SERVICE_ACCOUNT | Firebase Console > Project Settings > Service Accounts |
| VERTEX_AI_LOCATION | asia-south1 (Mumbai) |
