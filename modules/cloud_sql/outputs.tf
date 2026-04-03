output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.main.name
}

output "private_ip" {
  description = "The private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.main.private_ip_address
}

output "connection_name" {
  description = "The connection name for Cloud SQL Auth Proxy"
  value       = google_sql_database_instance.main.connection_name
}

output "db_name" {
  description = "The name of the database"
  value       = google_sql_database.main.name
}

output "db_user" {
  description = "The database user name"
  value       = google_sql_user.main.name
}

output "db_password" {
  description = "The database user password"
  value       = random_password.db_password.result
  sensitive   = true
}
