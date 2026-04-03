variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "db_password" {
  description = "The database password to store"
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Labels to apply to the secret"
  type        = map(string)
  default     = {}
}
