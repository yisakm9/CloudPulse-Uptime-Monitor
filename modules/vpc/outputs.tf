output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.main.name
}

output "network_id" {
  description = "The self-link ID of the VPC network"
  value       = google_compute_network.main.id
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.main.name
}

output "subnet_id" {
  description = "The self-link ID of the subnet"
  value       = google_compute_subnetwork.main.id
}

output "private_service_connection" {
  description = "The private service networking connection (for Cloud SQL dependency)"
  value       = google_service_networking_connection.private_service.id
}
