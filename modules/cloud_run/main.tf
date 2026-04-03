# ──────────────────────────────────────────────────────────────
# CloudPulse — Cloud Run Module
# ──────────────────────────────────────────────────────────────
# Deploys two Cloud Run services from the same Docker image
# with different entrypoints:
#
#   1. Web Service  — FastAPI dashboard + REST API
#   2. Worker Service — Background health check process
#
# Both connect to Cloud SQL via VPC Connector (private IP).
# Ingress is restricted to internal + load balancer only.
# ──────────────────────────────────────────────────────────────

# ─── Web Service (Dashboard + API) ───────────────────────────

resource "google_cloud_run_v2_service" "web" {
  name     = "${var.name_prefix}-web"
  project  = var.project_id
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = var.web_service_account

    scaling {
      min_instance_count = var.web_min_instances
      max_instance_count = var.web_max_instances
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image   = var.image
      command = ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

      ports {
        container_port = 8000
      }

      resources {
        limits = {
          cpu    = var.web_cpu
          memory = var.web_memory
        }
        cpu_idle = true
      }

      # ─── Environment Variables ──────────────────────────────
      env {
        name  = "APP_ENV"
        value = "production"
      }

      env {
        name  = "DB_HOST"
        value = var.db_host
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_USER"
        value = var.db_user
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      # ─── Secret from Secret Manager ─────────────────────────
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_secret_id
            version = "latest"
          }
        }
      }

      # ─── Health Check ───────────────────────────────────────
      startup_probe {
        http_get {
          path = "/api/health"
          port = 8000
        }
        initial_delay_seconds = 5
        period_seconds        = 10
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/api/health"
          port = 8000
        }
        period_seconds    = 30
        failure_threshold = 3
      }
    }

    labels = var.labels
  }

  labels = var.labels
}

# ─── Worker Service (Health Checker) ─────────────────────────

resource "google_cloud_run_v2_service" "worker" {
  name     = "${var.name_prefix}-worker"
  project  = var.project_id
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = var.worker_service_account

    scaling {
      min_instance_count = var.worker_min_instances
      max_instance_count = var.worker_max_instances
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "ALL_TRAFFIC"
    }

    containers {
      image   = var.image
      command = ["python", "worker.py"]

      ports {
        container_port = 8001
      }

      resources {
        limits = {
          cpu    = var.web_cpu
          memory = var.web_memory
        }
        cpu_idle = false  # Worker must always have CPU allocated
      }

      # ─── Environment Variables ──────────────────────────────
      env {
        name  = "APP_ENV"
        value = "production"
      }

      env {
        name  = "DB_HOST"
        value = var.db_host
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_USER"
        value = var.db_user
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "CHECK_INTERVAL_SECONDS"
        value = "300"
      }

      # ─── Secret from Secret Manager ─────────────────────────
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 8001
        }
        initial_delay_seconds = 10
        period_seconds        = 10
        failure_threshold     = 3
      }
    }

    labels = var.labels
  }

  labels = var.labels
}

# ─── Allow unauthenticated access to Web via LB ──────────────
# The web service is only accessible via the Load Balancer,
# but requests from the LB arrive without IAM authentication.

resource "google_cloud_run_v2_service_iam_member" "web_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.web.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
