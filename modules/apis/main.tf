# ──────────────────────────────────────────────────────────────
# CloudPulse — Enable Required GCP APIs
# ──────────────────────────────────────────────────────────────
# GCP requires APIs to be explicitly enabled before resources
# can be created. This module enables all services upfront.
# ──────────────────────────────────────────────────────────────

locals {
  required_apis = [
    "run.googleapis.com",                # Cloud Run
    "sqladmin.googleapis.com",           # Cloud SQL Admin
    "compute.googleapis.com",            # VPC, Firewall, LB, NAT
    "vpcaccess.googleapis.com",          # Serverless VPC Connector
    "artifactregistry.googleapis.com",   # Artifact Registry
    "secretmanager.googleapis.com",      # Secret Manager
    "servicenetworking.googleapis.com",  # Private Service Access (Cloud SQL private IP)
    "cloudresourcemanager.googleapis.com", # Resource Manager
    "iam.googleapis.com",               # IAM
    "monitoring.googleapis.com",         # Cloud Monitoring
    "logging.googleapis.com",            # Cloud Logging
    "iamcredentials.googleapis.com",     # Workload Identity Federation
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false

  timeouts {
    create = "10m"
    update = "10m"
  }
}
