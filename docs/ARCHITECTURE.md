# FairScan Architecture

## System Overview

```
[Flutter App] ──> [Cloud Run: FastAPI]
                         │
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
     [Gemini API]  [Vertex AI]   [Firestore]
     plain reports  severity+fix  audit history
                         │
                    [BigQuery]
                    large datasets
```

## Cloud Run (Mumbai - asia-south1)
- Memory: 1 GiB | CPU: 1 | Max instances: 10 | Scale to zero
- Timeout: 300s for large CSV analysis

## Firestore Schema
```
audits/{auditId}
  audit_id, user_id, domain
  overall_fairness_score: 0-100
  bias_detected: bool
  affected_groups: string[]
  metrics: { demographic_parity_difference, disparate_impact_ratio, ... }
  gemini_report: string
  remediation_steps: []
  legal_references: []
  created_at: ISO8601
```

## Cost (demo scale ~500 audits/month)
- Cloud Run: ~$0.50
- Gemini API: ~$2.50
- Firestore: ~$0.10
- Total: ~$3.10/month (free tier covers most)
