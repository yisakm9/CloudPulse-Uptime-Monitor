# ──────────────────────────────────────────────────────────────
# CloudPulse — VPC Network Module
# ──────────────────────────────────────────────────────────────
# Creates a custom-mode VPC with a regional subnet,
# Private Google Access, and VPC Flow Logs for auditing.
# ──────────────────────────────────────────────────────────────

# ─── VPC Network ──────────────────────────────────────────────

resource "google_compute_network" "main" {
  name                    = "${var.name_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "CloudPulse VPC - custom mode network"
}

# ─── Regional Subnet ─────────────────────────────────────────

resource "google_compute_subnetwork" "main" {
  name                     = "${var.name_prefix}-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.main.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ─── Private Service Access (for Cloud SQL Private IP) ────────
# This creates a peering range that Google uses to assign
# private IPs to managed services like Cloud SQL.

resource "google_compute_global_address" "private_service_range" {
  name          = "${var.name_prefix}-private-svc-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_service" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
}
