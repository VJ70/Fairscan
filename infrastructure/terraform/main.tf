terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "Your GCP project ID"
  type        = string
}

variable "region" {
  default = "us-central1"
}

# ── Enable required APIs ──────────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "bigquery.googleapis.com",
    "firestore.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
  ])
  service            = each.key
  disable_on_destroy = false
}

# ── Artifact Registry for Docker images ──────────────────────────────────
resource "google_artifact_registry_repository" "fairscan" {
  location      = var.region
  repository_id = "fairscan"
  format        = "DOCKER"
  depends_on    = [google_project_service.apis]
}

# ── Cloud Storage bucket for CSV uploads ─────────────────────────────────
resource "google_storage_bucket" "uploads" {
  name          = "${var.project_id}-fairscan-uploads"
  location      = "US"
  force_destroy = false
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition { age = 30 }
    action    { type = "Delete" }
  }
}

# ── BigQuery dataset ──────────────────────────────────────────────────────
resource "google_bigquery_dataset" "fairscan" {
  dataset_id = "fairscan_analytics"
  location   = "US"
  depends_on = [google_project_service.apis]
}

# ── Pub/Sub topic for async audit jobs ────────────────────────────────────
resource "google_pubsub_topic" "audit_jobs" {
  name       = "fairscan-audit-jobs"
  depends_on = [google_project_service.apis]
}

# ── Cloud Run service (deployed separately via Cloud Build) ───────────────
# Outputs the expected service URL pattern
output "cloud_run_url_pattern" {
  value = "https://fairscan-backend-<hash>-uc.a.run.app"
  description = "Deployed via cloudbuild.yaml — run: gcloud run services describe fairscan-backend --region=${var.region}"
}

output "artifact_registry" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/fairscan/backend"
}
