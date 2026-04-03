# ──────────────────────────────────────────────────────────────
# CloudPulse — Dev Environment Variable Values
# ──────────────────────────────────────────────────────────────

project_id  = "cloudpulse-uptime-dev"
region      = "us-central1"
environment = "dev"

# ─── Cloud SQL ────────────────────────────────────────────────
db_tier = "db-f1-micro"
db_name = "cloudpulse"
db_user = "cloudpulse_user"

# ─── Cloud Run ────────────────────────────────────────────────
web_min_instances    = 0
web_max_instances    = 5
worker_min_instances = 1
worker_max_instances = 3

# ─── Monitoring ───────────────────────────────────────────────
alert_email = "yisakmesifin@gmail.com"

# ─── Labels ───────────────────────────────────────────────────
labels = {
  project     = "cloudpulse"
  environment = "dev"
  managed-by  = "terraform"
  owner       = "yisakm9"
}
