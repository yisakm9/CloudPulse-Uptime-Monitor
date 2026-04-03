output "enabled_apis" {
  description = "List of enabled API services"
  value       = [for api in google_project_service.apis : api.service]
}
