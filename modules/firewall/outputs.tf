output "deny_all_rule_name" {
  description = "Name of the default deny-all ingress rule"
  value       = google_compute_firewall.deny_all_ingress.name
}

output "health_check_rule_name" {
  description = "Name of the health check allow rule"
  value       = google_compute_firewall.allow_health_checks.name
}
