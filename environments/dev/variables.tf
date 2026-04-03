# ──────────────────────────────────────────────────────────────
# CloudPulse — Root Variables
# ──────────────────────────────────────────────────────────────

# ─── Project ──────────────────────────────────────────────────

variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "region" {
  description = "The GCP region for resource deployment"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ─── Networking ───────────────────────────────────────────────

variable "vpc_cidr" {
  description = "Primary CIDR range for the VPC subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "connector_cidr" {
  description = "CIDR range for the Serverless VPC Connector"
  type        = string
  default     = "10.8.0.0/28"
}

# ─── Cloud SQL ────────────────────────────────────────────────

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "cloudpulse"
}

variable "db_user" {
  description = "Database user name"
  type        = string
  default     = "cloudpulse_user"
}

# ─── Cloud Run ────────────────────────────────────────────────

variable "web_image" {
  description = "Docker image URI for the web service (set by CI/CD)"
  type        = string
  default     = "us-central1-docker.pkg.dev/PROJECT_ID/cloudpulse-repo-dev/cloudpulse:latest"
}

variable "web_cpu" {
  description = "CPU allocation for web service"
  type        = string
  default     = "1"
}

variable "web_memory" {
  description = "Memory allocation for web service"
  type        = string
  default     = "512Mi"
}

variable "web_min_instances" {
  description = "Minimum number of web instances"
  type        = number
  default     = 0
}

variable "web_max_instances" {
  description = "Maximum number of web instances"
  type        = number
  default     = 5
}

variable "worker_min_instances" {
  description = "Minimum number of worker instances"
  type        = number
  default     = 1
}

variable "worker_max_instances" {
  description = "Maximum number of worker instances"
  type        = number
  default     = 3
}

# ─── Monitoring ───────────────────────────────────────────────

variable "alert_email" {
  description = "Email address for monitoring alert notifications"
  type        = string
}

# ─── Labels ───────────────────────────────────────────────────

variable "labels" {
  description = "Common labels applied to all resources"
  type        = map(string)
  default = {
    project    = "cloudpulse"
    managed-by = "terraform"
  }
}
