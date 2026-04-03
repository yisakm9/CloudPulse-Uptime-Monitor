output "secret_id" {
  description = "The fully qualified secret ID"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "secret_name" {
  description = "The resource name of the secret"
  value       = google_secret_manager_secret.db_password.name
}

output "secret_version" {
  description = "The version of the stored secret"
  value       = google_secret_manager_secret_version.db_password.name
}
