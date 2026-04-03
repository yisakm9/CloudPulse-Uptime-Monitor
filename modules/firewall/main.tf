# ──────────────────────────────────────────────────────────────
# CloudPulse — Firewall Rules Module
# ──────────────────────────────────────────────────────────────
# Implements defense-in-depth network security:
#   1. Default deny all ingress
#   2. Allow Google health check probes (required for LB)
#   3. Allow internal communication within VPC
# ──────────────────────────────────────────────────────────────

# ─── Default: Deny all ingress traffic ────────────────────────

resource "google_compute_firewall" "deny_all_ingress" {
  name        = "${var.name_prefix}-deny-all-ingress"
  project     = var.project_id
  network     = var.network_name
  description = "Default deny all ingress traffic"
  direction   = "INGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# ─── Allow Google health check probes ─────────────────────────
# These IP ranges are Google's health check probe sources.
# Required for the Global HTTP(S) Load Balancer to function.

resource "google_compute_firewall" "allow_health_checks" {
  name        = "${var.name_prefix}-allow-health-checks"
  project     = var.project_id
  network     = var.network_name
  description = "Allow Google LB health check probes"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }

  source_ranges = [
    "130.211.0.0/22",  # Google health check range 1
    "35.191.0.0/16",   # Google health check range 2
  ]

  target_tags = ["cloudpulse-web"]
}

# ─── Allow internal VPC communication ─────────────────────────

resource "google_compute_firewall" "allow_internal" {
  name        = "${var.name_prefix}-allow-internal"
  project     = var.project_id
  network     = var.network_name
  description = "Allow internal communication within VPC"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}
