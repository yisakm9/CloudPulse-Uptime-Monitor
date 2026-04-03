# ──────────────────────────────────────────────────────────────
# CloudPulse — Terraform Remote State Configuration
# ──────────────────────────────────────────────────────────────

terraform {
  backend "gcs" {
    bucket = "cloudpulse-terraform-state-dev"
    prefix = "terraform/state"
  }
}