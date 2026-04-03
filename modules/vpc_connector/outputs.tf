output "connector_id" {
  description = "The fully qualified ID of the VPC connector"
  value       = google_vpc_access_connector.main.id
}

output "connector_name" {
  description = "The name of the VPC connector"
  value       = google_vpc_access_connector.main.name
}
