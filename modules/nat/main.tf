# ──────────────────────────────────────────────────────────────
# CloudPulse — Cloud NAT Module
# ──────────────────────────────────────────────────────────────
# Cloud NAT provides outbound internet access for resources
# in private subnets without exposing them to inbound traffic.
# Required for Cloud Run worker to reach external URLs.
# ──────────────────────────────────────────────────────────────

resource "google_compute_router" "main" {
  name    = "${var.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = var.network_name

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.name_prefix}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.main.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
