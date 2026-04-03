# ──────────────────────────────────────────────────────────────
# CloudPulse — Global HTTP(S) Load Balancer Module
# ──────────────────────────────────────────────────────────────
# Creates a Google-managed Global External Application LB
# that routes traffic to the Cloud Run web service.
#
# Components:
#   1. Serverless NEG (Network Endpoint Group) → Cloud Run
#   2. Backend Service with health checking
#   3. URL Map (routing rules)
#   4. HTTP Proxy
#   5. Global Forwarding Rule (public IP)
# ──────────────────────────────────────────────────────────────

# ─── Reserve a static global IP ──────────────────────────────

resource "google_compute_global_address" "main" {
  name    = "${var.name_prefix}-lb-ip"
  project = var.project_id
}

# ─── Serverless Network Endpoint Group ────────────────────────
# Points to the Cloud Run web service

resource "google_compute_region_network_endpoint_group" "web_neg" {
  name                  = "${var.name_prefix}-web-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_name
  }
}

# ─── Backend Service ─────────────────────────────────────────

resource "google_compute_backend_service" "web" {
  name        = "${var.name_prefix}-backend"
  project     = var.project_id
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.web_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# ─── URL Map ─────────────────────────────────────────────────
# Defines routing rules (all traffic → web backend)

resource "google_compute_url_map" "main" {
  name            = "${var.name_prefix}-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.web.id
}

# ─── HTTP Proxy ──────────────────────────────────────────────

resource "google_compute_target_http_proxy" "main" {
  name    = "${var.name_prefix}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.main.id
}

# ─── Global Forwarding Rule (Entry Point) ────────────────────
# Binds the static IP to the HTTP proxy on port 80

resource "google_compute_global_forwarding_rule" "http" {
  name        = "${var.name_prefix}-http-rule"
  project     = var.project_id
  target      = google_compute_target_http_proxy.main.id
  port_range  = "80"
  ip_address  = google_compute_global_address.main.address
  ip_protocol = "TCP"

  labels = var.labels
}
