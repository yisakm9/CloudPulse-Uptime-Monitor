# ──────────────────────────────────────────────────────────────
# CloudPulse — Artifact Registry Module
# ──────────────────────────────────────────────────────────────
# Private Docker repository for storing CloudPulse container
# images. Includes cleanup policy to control storage costs.
# ──────────────────────────────────────────────────────────────

resource "google_artifact_registry_repository" "main" {
  repository_id = "${var.name_prefix}-repo"
  project       = var.project_id
  location      = var.region
  format        = "DOCKER"
  description   = "CloudPulse Docker images"

  labels = var.labels

  cleanup_policies {
    id     = "keep-recent-images"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old-images"
    action = "DELETE"

    condition {
      older_than = "2592000s" # 30 days
    }
  }
}
