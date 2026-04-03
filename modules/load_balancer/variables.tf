variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for the serverless NEG"
  type        = string
}

variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "cloud_run_name" {
  description = "The name of the Cloud Run web service to route to"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
