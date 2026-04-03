output "web_service_name" {
  description = "The name of the web Cloud Run service"
  value       = google_cloud_run_v2_service.web.name
}

output "web_service_url" {
  description = "The URL of the web Cloud Run service"
  value       = google_cloud_run_v2_service.web.uri
}

output "worker_service_name" {
  description = "The name of the worker Cloud Run service"
  value       = google_cloud_run_v2_service.worker.name
}

output "worker_service_url" {
  description = "The URL of the worker Cloud Run service"
  value       = google_cloud_run_v2_service.worker.uri
}
