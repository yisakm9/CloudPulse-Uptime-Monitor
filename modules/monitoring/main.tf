# ──────────────────────────────────────────────────────────────
# CloudPulse — Cloud Monitoring Module
# ──────────────────────────────────────────────────────────────
# Sets up:
#   1. Email notification channel for alerts
#   2. Uptime check on the Load Balancer URL
#   3. Alert policies for Cloud Run and Cloud SQL
#   4. Monitoring dashboard
# ──────────────────────────────────────────────────────────────

# ─── Notification Channel (Email) ────────────────────────────

resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.name_prefix}-email-alerts"
  project      = var.project_id
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

# ─── Uptime Check — Monitor the LB endpoint ─────────────────

resource "google_monitoring_uptime_check_config" "lb_health" {
  display_name = "${var.name_prefix}-lb-uptime-check"
  project      = var.project_id
  timeout      = "10s"
  period       = "300s"

  http_check {
    path         = "/api/health"
    port         = 80
    use_ssl      = false
    request_method = "GET"

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.lb_ip_address
    }
  }
}

# ─── Alert: Cloud Run 5xx Error Rate ─────────────────────────

resource "google_monitoring_alert_policy" "cloud_run_5xx" {
  display_name = "${var.name_prefix}-cloud-run-5xx-errors"
  project      = var.project_id
  combiner     = "OR"

  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]

  conditions {
    display_name = "Cloud Run 5xx Error Rate > 5%"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.web_service_name}\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

# ─── Alert: Cloud SQL CPU > 80% ──────────────────────────────

resource "google_monitoring_alert_policy" "cloud_sql_cpu" {
  display_name = "${var.name_prefix}-cloud-sql-high-cpu"
  project      = var.project_id
  combiner     = "OR"

  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]

  conditions {
    display_name = "Cloud SQL CPU Utilization > 80%"

    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND resource.labels.database_id = \"${var.project_id}:${var.cloud_sql_instance}\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

# ─── Alert: Cloud SQL Disk Usage > 80% ───────────────────────

resource "google_monitoring_alert_policy" "cloud_sql_disk" {
  display_name = "${var.name_prefix}-cloud-sql-disk-usage"
  project      = var.project_id
  combiner     = "OR"

  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]

  conditions {
    display_name = "Cloud SQL Disk Utilization > 80%"

    condition_threshold {
      filter          = "resource.type = \"cloudsql_database\" AND resource.labels.database_id = \"${var.project_id}:${var.cloud_sql_instance}\" AND metric.type = \"cloudsql.googleapis.com/database/disk/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

# ─── Alert: Uptime Check Failure (Site Down) ─────────────────
# This is the most important alert — emails you when the
# dashboard becomes unreachable via the Load Balancer.

resource "google_monitoring_alert_policy" "uptime_check_failure" {
  display_name = "${var.name_prefix}-site-down"
  project      = var.project_id
  combiner     = "OR"

  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]

  conditions {
    display_name = "Uptime Check Failure - Site Unreachable"

    condition_threshold {
      filter          = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"${google_monitoring_uptime_check_config.lb_health.uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.project_id"]
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}

# ─── Alert: Monitored Endpoint Down ──────────────────────────
# Fires when the CloudPulse worker detects that a monitored
# endpoint has transitioned from UP → DOWN. This sends a
# custom metric which triggers this alert → email notification.

resource "google_monitoring_alert_policy" "endpoint_down" {
  display_name = "${var.name_prefix}-endpoint-down"
  project      = var.project_id
  combiner     = "OR"

  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]

  conditions {
    display_name = "Monitored Endpoint Down"

    condition_threshold {
      filter          = "resource.type = \"global\" AND metric.type = \"custom.googleapis.com/cloudpulse/endpoint_down\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}
