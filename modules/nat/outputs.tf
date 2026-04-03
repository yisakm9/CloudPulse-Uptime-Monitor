output "router_name" {
  description = "The name of the Cloud Router"
  value       = google_compute_router.main.name
}

output "nat_name" {
  description = "The name of the Cloud NAT"
  value       = google_compute_router_nat.main.name
}
