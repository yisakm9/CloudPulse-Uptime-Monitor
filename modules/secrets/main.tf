# ──────────────────────────────────────────────────────────────
# CloudPulse — Secret Manager Module
# ──────────────────────────────────────────────────────────────
# Stores the database password in Secret Manager.
# Cloud Run services access this secret at runtime via
# IAM-controlled secretmanager.secretAccessor role.
# ──────────────────────────────────────────────────────────────

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.name_prefix}-db-password"
  project   = var.project_id

  labels = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}
