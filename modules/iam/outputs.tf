output "web_service_account_email" {
  description = "Email of the web service account"
  value       = google_service_account.web.email
}

output "worker_service_account_email" {
  description = "Email of the worker service account"
  value       = google_service_account.worker.email
}

output "github_service_account_email" {
  description = "Email of the GitHub Actions service account"
  value       = google_service_account.github.email
}

output "github_service_account_id" {
  description = "The fully qualified ID of the GitHub service account"
  value       = google_service_account.github.id
}
