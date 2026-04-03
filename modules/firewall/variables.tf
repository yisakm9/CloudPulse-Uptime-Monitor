variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
}
