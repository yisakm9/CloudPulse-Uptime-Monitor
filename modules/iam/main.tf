# ──────────────────────────────────────────────────────────────
# CloudPulse — IAM Module
# ──────────────────────────────────────────────────────────────
# Creates dedicated service accounts with least-privilege
# permissions for each component:
#   - Web service account (dashboard + API)
#   - Worker service account (health checker)
#   - GitHub Actions service account (CI/CD deployment)
#
# Each service only gets the exact permissions it needs.
# ──────────────────────────────────────────────────────────────

# ─── Web Service Account ─────────────────────────────────────
# Permissions: Cloud SQL client, read secrets, write logs/metrics

resource "google_service_account" "web" {
  account_id   = "${var.name_prefix}-web-sa"
  project      = var.project_id
  display_name = "CloudPulse Web Service Account"
  description  = "Service account for the CloudPulse web dashboard"
}

resource "google_project_iam_member" "web_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.web.email}"
}

resource "google_project_iam_member" "web_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.web.email}"
}

resource "google_project_iam_member" "web_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.web.email}"
}

resource "google_secret_manager_secret_iam_member" "web_secret_access" {
  project   = var.project_id
  secret_id = var.db_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.web.email}"
}

# ─── Worker Service Account ──────────────────────────────────
# Permissions: Cloud SQL client, read secrets, write logs/metrics

resource "google_service_account" "worker" {
  account_id   = "${var.name_prefix}-worker-sa"
  project      = var.project_id
  display_name = "CloudPulse Worker Service Account"
  description  = "Service account for the CloudPulse health check worker"
}

resource "google_project_iam_member" "worker_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_project_iam_member" "worker_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_project_iam_member" "worker_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_secret_manager_secret_iam_member" "worker_secret_access" {
  project   = var.project_id
  secret_id = var.db_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.worker.email}"
}

# ─── GitHub Actions Service Account ──────────────────────────
# Used via Workload Identity Federation for CI/CD deployment.
# Permissions: deploy Cloud Run, push to Artifact Registry,
# impersonate service accounts, read Terraform state.

resource "google_service_account" "github" {
  account_id   = "${var.name_prefix}-github-sa"
  project      = var.project_id
  display_name = "CloudPulse GitHub Actions Service Account"
  description  = "Service account for GitHub Actions CI/CD pipeline"
}

# Cloud Run Admin — deploy new revisions
resource "google_project_iam_member" "github_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github.email}"
}

# Artifact Registry Writer — push Docker images
resource "google_project_iam_member" "github_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github.email}"
}

# Service Account User — attach SAs to Cloud Run services
resource "google_project_iam_member" "github_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github.email}"
}

# Storage Admin — manage Terraform state in GCS
resource "google_project_iam_member" "github_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.github.email}"
}

# Compute Network Viewer — read VPC connector info during deploy
resource "google_project_iam_member" "github_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.github.email}"
}
