# ──────────────────────────────────────────────────────────────
# CloudPulse — Uptime Monitoring Platform
# Root Module — Dev Environment
# ──────────────────────────────────────────────────────────────
#
# This file orchestrates all infrastructure modules in the
# correct dependency order for the CloudPulse platform.
#
# Architecture:
#   Internet → Global LB → Cloud Run (Web) → Cloud SQL
#              Cloud Run (Worker) → Cloud SQL + External URLs
#
# ──────────────────────────────────────────────────────────────

locals {
  project_name = "cloudpulse"
  name_prefix  = "${local.project_name}-${var.environment}"

  labels = merge(var.labels, {
    environment = var.environment
  })
}

# ──────────────────────────────────────────────────────────────
# 1. Enable Required GCP APIs
# ──────────────────────────────────────────────────────────────

module "apis" {
  source = "../../modules/apis"

  project_id = var.project_id
}

# ──────────────────────────────────────────────────────────────
# 2. VPC Network — Foundation
# ──────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  subnet_cidr = var.vpc_cidr
  labels      = local.labels

  depends_on = [module.apis]
}

# ──────────────────────────────────────────────────────────────
# 3. Cloud NAT — Outbound Internet for Private Resources
# ──────────────────────────────────────────────────────────────

module "nat" {
  source = "../../modules/nat"

  project_id   = var.project_id
  region       = var.region
  name_prefix  = local.name_prefix
  network_name = module.vpc.network_name

  depends_on = [module.vpc]
}

# ──────────────────────────────────────────────────────────────
# 4. Serverless VPC Connector — Cloud Run ↔ VPC Bridge
# ──────────────────────────────────────────────────────────────

module "vpc_connector" {
  source = "../../modules/vpc_connector"

  project_id     = var.project_id
  region         = var.region
  name_prefix    = local.name_prefix
  network_name   = module.vpc.network_name
  connector_cidr = var.connector_cidr

  depends_on = [module.vpc]
}

# ──────────────────────────────────────────────────────────────
# 5. Firewall Rules — Network Access Control
# ──────────────────────────────────────────────────────────────

module "firewall" {
  source = "../../modules/firewall"

  project_id   = var.project_id
  name_prefix  = local.name_prefix
  network_name = module.vpc.network_name

  depends_on = [module.vpc]
}

# ──────────────────────────────────────────────────────────────
# 6. Cloud SQL — PostgreSQL Database (Private IP)
# ──────────────────────────────────────────────────────────────

module "cloud_sql" {
  source = "../../modules/cloud_sql"

  project_id         = var.project_id
  region             = var.region
  name_prefix        = local.name_prefix
  network_id         = module.vpc.network_id
  db_tier            = var.db_tier
  db_name            = var.db_name
  db_user            = var.db_user
  labels             = local.labels

  depends_on = [module.vpc, module.apis]
}

# ──────────────────────────────────────────────────────────────
# 7. Secret Manager — Database Credentials
# ──────────────────────────────────────────────────────────────

module "secrets" {
  source = "../../modules/secrets"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  db_password = module.cloud_sql.db_password
  labels      = local.labels

  depends_on = [module.cloud_sql, module.apis]
}

# ──────────────────────────────────────────────────────────────
# 8. Artifact Registry — Docker Image Repository
# ──────────────────────────────────────────────────────────────

module "artifact_registry" {
  source = "../../modules/artifact_registry"

  project_id  = var.project_id
  region      = var.region
  name_prefix = local.name_prefix
  labels      = local.labels

  depends_on = [module.apis]
}

# ──────────────────────────────────────────────────────────────
# 9. IAM — Service Accounts & Permissions
# ──────────────────────────────────────────────────────────────

module "iam" {
  source = "../../modules/iam"

  project_id       = var.project_id
  name_prefix      = local.name_prefix
  db_secret_id     = module.secrets.secret_id

  depends_on = [module.secrets, module.apis]
}

# ──────────────────────────────────────────────────────────────
# 10. Cloud Run — Web & Worker Services
# ──────────────────────────────────────────────────────────────

module "cloud_run" {
  source = "../../modules/cloud_run"

  project_id           = var.project_id
  region               = var.region
  name_prefix          = local.name_prefix
  image                = var.web_image
  vpc_connector_id     = module.vpc_connector.connector_id
  web_service_account  = module.iam.web_service_account_email
  worker_service_account = module.iam.worker_service_account_email
  db_secret_id         = module.secrets.secret_id
  db_host              = module.cloud_sql.private_ip
  db_name              = var.db_name
  db_user              = var.db_user
  web_cpu              = var.web_cpu
  web_memory           = var.web_memory
  web_min_instances    = var.web_min_instances
  web_max_instances    = var.web_max_instances
  worker_min_instances = var.worker_min_instances
  worker_max_instances = var.worker_max_instances
  labels               = local.labels

  depends_on = [
    module.vpc_connector,
    module.cloud_sql,
    module.secrets,
    module.iam,
    module.artifact_registry
  ]
}

# ──────────────────────────────────────────────────────────────
# 11. Global HTTP(S) Load Balancer
# ──────────────────────────────────────────────────────────────

module "load_balancer" {
  source = "../../modules/load_balancer"

  project_id      = var.project_id
  region          = var.region
  name_prefix     = local.name_prefix
  cloud_run_name  = module.cloud_run.web_service_name
  labels          = local.labels

  depends_on = [module.cloud_run]
}

# ──────────────────────────────────────────────────────────────
# 12. Cloud Monitoring — Alerts & Dashboards
# ──────────────────────────────────────────────────────────────

module "monitoring" {
  source = "../../modules/monitoring"

  project_id        = var.project_id
  name_prefix       = local.name_prefix
  alert_email       = var.alert_email
  web_service_name  = module.cloud_run.web_service_name
  lb_ip_address     = module.load_balancer.lb_ip_address
  cloud_sql_instance = module.cloud_sql.instance_name

  depends_on = [module.cloud_run, module.load_balancer]
}
