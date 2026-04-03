# ──────────────────────────────────────────────────────────────
# CloudPulse — Serverless VPC Connector Module
# ──────────────────────────────────────────────────────────────
# Bridges Cloud Run services into the VPC, enabling them to
# access private resources like Cloud SQL via private IP.
# ──────────────────────────────────────────────────────────────

resource "google_vpc_access_connector" "main" {
  name          = "${var.name_prefix}-conn"
  project       = var.project_id
  region        = var.region
  network       = var.network_name
  ip_cidr_range = var.connector_cidr
  machine_type  = "e2-micro"

  min_instances = 2
  max_instances = 3

  min_throughput = 200
  max_throughput = 300
}
