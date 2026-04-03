variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "image" {
  description = "Docker image URI from Artifact Registry"
  type        = string
}

variable "vpc_connector_id" {
  description = "The fully qualified ID of the VPC connector"
  type        = string
}

variable "web_service_account" {
  description = "Email of the web service account"
  type        = string
}

variable "worker_service_account" {
  description = "Email of the worker service account"
  type        = string
}

variable "db_secret_id" {
  description = "The Secret Manager secret ID for the DB password"
  type        = string
}

variable "db_host" {
  description = "The private IP of the Cloud SQL instance"
  type        = string
}

variable "db_name" {
  description = "The database name"
  type        = string
}

variable "db_user" {
  description = "The database user"
  type        = string
}

variable "web_cpu" {
  description = "CPU allocation for web containers"
  type        = string
  default     = "1"
}

variable "web_memory" {
  description = "Memory allocation for web containers"
  type        = string
  default     = "512Mi"
}

variable "web_min_instances" {
  description = "Minimum web instances (0 = scale to zero)"
  type        = number
  default     = 0
}

variable "web_max_instances" {
  description = "Maximum web instances"
  type        = number
  default     = 5
}

variable "worker_min_instances" {
  description = "Minimum worker instances"
  type        = number
  default     = 1
}

variable "worker_max_instances" {
  description = "Maximum worker instances"
  type        = number
  default     = 3
}

variable "labels" {
  description = "Labels to apply to services"
  type        = map(string)
  default     = {}
}
