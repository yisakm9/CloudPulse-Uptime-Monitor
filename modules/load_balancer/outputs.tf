output "lb_ip_address" {
  description = "The public IP address of the load balancer"
  value       = google_compute_global_address.main.address
}

output "lb_url" {
  description = "The HTTP URL  of the load balancer"
  value       = "http://${google_compute_global_address.main.address}"
}

output "backend_service_id" {
  description = "The ID of the backend service"
  value       = google_compute_backend_service.web.id
}
