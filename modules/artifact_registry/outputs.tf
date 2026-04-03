output "repository_id" {
  description = "The ID of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.repository_id
}

output "repository_url" {
  description = "The full URL for pushing Docker images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}
