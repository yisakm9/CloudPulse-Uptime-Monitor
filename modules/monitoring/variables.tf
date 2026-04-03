variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "name_prefix" {
  description = "Naming prefix for resources"
  type        = string
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "web_service_name" {
  description = "The name of the Cloud Run web service to monitor"
  type        = string
}

variable "lb_ip_address" {
  description = "The public IP of the load balancer for uptime checks"
  type        = string
}

variable "cloud_sql_instance" {
  description = "The Cloud SQL instance name for monitoring"
  type        = string
}
