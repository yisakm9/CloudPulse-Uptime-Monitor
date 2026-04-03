output "notification_channel_id" {
  description = "The ID of the email notification channel"
  value       = google_monitoring_notification_channel.email.name
}

output "uptime_check_id" {
  description = "The ID of the LB uptime check"
  value       = google_monitoring_uptime_check_config.lb_health.uptime_check_id
}
