# ──────────────────────────────────────────────────────────────
# CloudPulse — Cloud SQL PostgreSQL Module
# ──────────────────────────────────────────────────────────────
# Provisions a managed PostgreSQL instance with:
#   - Private IP only (no public access)
#   - Automated daily backups
#   - Deletion protection (configurable)
#   - Secure password generation
# ──────────────────────────────────────────────────────────────

# ─── Generate a secure random password ────────────────────────

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ─── Cloud SQL Instance ──────────────────────────────────────

resource "google_sql_database_instance" "main" {
  name                = "${var.name_prefix}-db"
  project             = var.project_id
  region              = var.region
  database_version    = "POSTGRES_15"
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.db_tier
    availability_type = var.availability_type
    disk_size         = var.disk_size_gb
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services  = true
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
      }
    }

    maintenance_window {
      day          = 7  # Sunday
      hour         = 4  # 4 AM UTC
      update_track = "stable"
    }

    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"  # Log queries slower than 1 second
    }

    user_labels = var.labels
  }
}

# ─── Database ─────────────────────────────────────────────────

resource "google_sql_database" "main" {
  name            = var.db_name
  project         = var.project_id
  instance        = google_sql_database_instance.main.name
  deletion_policy = "ABANDON"
}

# ─── Database User ────────────────────────────────────────────

resource "google_sql_user" "main" {
  name            = var.db_user
  project         = var.project_id
  instance        = google_sql_database_instance.main.name
  password        = random_password.db_password.result
  deletion_policy = "ABANDON"
}
