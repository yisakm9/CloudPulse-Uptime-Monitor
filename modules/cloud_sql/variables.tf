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

variable "network_id" {
  description = "The self-link of the VPC network for private IP"
  type        = string
}

variable "db_tier" {
  description = "Cloud SQL machine tier (e.g., db-f1-micro, db-custom-1-3840)"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "Name of the PostgreSQL database to create"
  type        = string
}

variable "db_user" {
  description = "Name of the database user to create"
  type        = string
}

variable "disk_size_gb" {
  description = "Initial disk size in GB"
  type        = number
  default     = 10
}

variable "availability_type" {
  description = "Availability type: ZONAL (single zone) or REGIONAL (HA)"
  type        = string
  default     = "ZONAL"
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the Cloud SQL instance"
  type        = map(string)
  default     = {}
}
