# ──────────────────────────────────────────────────────────────
# CloudPulse — Root Outputs
# ──────────────────────────────────────────────────────────────

output "load_balancer_ip" {
  description = "The public IP address of the Global HTTP(S) Load Balancer"
  value       = module.load_balancer.lb_ip_address
}

output "web_service_url" {
  description = "The direct Cloud Run web service URL (internal use)"
  value       = module.cloud_run.web_service_url
}

output "cloud_sql_private_ip" {
  description = "The private IP of the Cloud SQL instance"
  value       = module.cloud_sql.private_ip
  sensitive   = true
}

output "artifact_registry_url" {
  description = "The Artifact Registry repository URL for pushing Docker images"
  value       = module.artifact_registry.repository_url
}

output "dashboard_url" {
  description = "The public URL to access the CloudPulse dashboard"
  value       = "http://${module.load_balancer.lb_ip_address}"
}
