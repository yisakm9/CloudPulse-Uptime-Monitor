# Architecture Decision Record — CloudPulse Uptime Monitor

> **Document Version:** 1.0  
> **Author:** Yisak Mesifin  
> **Date:** April 2026  
> **Status:** Accepted — In Production

---

## 1. Executive Summary

CloudPulse is a cloud-native uptime monitoring platform deployed on Google Cloud Platform. It continuously monitors the health of websites and APIs, provides a real-time dashboard with response time analytics, and sends email alerts when monitored services go down.

The system is fully serverless, defined entirely as Infrastructure as Code (Terraform), and deployed via a CI/CD pipeline with zero manual console interaction. This document records the key architectural decisions made during the design and implementation of the platform.

---

## 2. System Context

### 2.1 Problem Statement

Organizations need to monitor the availability and performance of their web services. When a service goes down, engineers must be notified immediately to minimize downtime. Existing solutions (Pingdom, UptimeRobot, Datadog) are SaaS products with recurring costs and limited customization.

### 2.2 Solution

CloudPulse provides a **self-hosted, cloud-native** alternative that:
- Runs on the organization's own GCP project
- Costs ~$45-55/month (covered by the $300 GCP free trial)
- Is fully customizable and extensible
- Demonstrates production-grade cloud engineering practices

### 2.3 Stakeholders

| Stakeholder | Interest |
|-------------|----------|
| Platform Engineers | Infrastructure reliability, automation |
| Application Developers | API availability, response time visibility |
| Engineering Managers | Uptime SLA compliance, cost control |

---

## 3. Architecture Decisions

### ADR-001: Serverless Over VMs

**Decision:** Use Cloud Run (serverless containers) instead of Compute Engine VMs or GKE.

**Context:** The monitoring workload is event-driven — the worker checks endpoints every 5 minutes, and the dashboard serves requests on-demand. Neither component requires persistent compute.

**Rationale:**
- **Cost efficiency:** Cloud Run scales to zero when idle, eliminating costs during off-peak hours
- **Operational simplicity:** No server patching, OS updates, or capacity planning
- **Auto-scaling:** Handles traffic spikes without pre-configured instance counts
- **Container portability:** Same Docker image can run on GKE, Cloud Run, or locally

**Trade-offs:**
- Cold start latency (~1-2 seconds) on first request after scale-to-zero
- No persistent local storage (requires external database)
- Limited to HTTP-based health probes

**Alternatives Considered:**
| Alternative | Rejected Because |
|-------------|-----------------|
| Compute Engine | Higher cost (always-on VMs), more operational overhead |
| GKE Autopilot | Kubernetes complexity unnecessary for 2-service architecture |
| Cloud Functions | Too limiting for a long-running worker process |

---

### ADR-002: Cloud SQL PostgreSQL with Private IP

**Decision:** Use Cloud SQL for PostgreSQL 15 with private IP only (no public endpoint).

**Context:** The application needs a relational database to store monitored endpoints and their health check history. PostgreSQL was chosen for its robust feature set and wide adoption.

**Rationale:**
- **Security:** Private IP means the database is only accessible within the VPC — no internet exposure
- **Managed service:** Automated backups, point-in-time recovery, maintenance windows, and HA options
- **VPC Connector integration:** Cloud Run connects to Cloud SQL through the Serverless VPC Connector
- **Cost optimization:** `db-f1-micro` tier (~$8/month) is sufficient for monitoring workloads

**Trade-offs:**
- Requires VPC Connector (~$6/month) for Cloud Run → Cloud SQL connectivity
- Private IP requires Private Service Access peering (adds VPC complexity)
- Cannot connect directly from a local development machine

**Mitigation:** Docker Compose provides a local PostgreSQL instance for development.

---

### ADR-003: Modular Terraform Architecture

**Decision:** Organize infrastructure as 12 independent, reusable Terraform modules.

**Context:** The project requires ~59 GCP resources spanning networking, compute, database, monitoring, and IAM. A monolithic Terraform configuration would be unmaintainable.

**Rationale:**
- **Separation of concerns:** Each module owns a single domain (VPC, Cloud SQL, IAM, etc.)
- **Reusability:** Modules can be used in staging/production with different `terraform.tfvars`
- **Testing isolation:** Individual modules can be validated and planned independently
- **Team scaling:** Different engineers can own different modules
- **Dependency clarity:** Explicit `depends_on` and variable passing makes resource ordering clear

**Module Dependency Graph:**
```
APIs → VPC → NAT, VPC Connector, Firewall
APIs → Cloud SQL ← VPC (private service access)
APIs → Secrets ← Cloud SQL (password)
APIs → IAM
APIs → Artifact Registry
Cloud SQL, IAM, VPC Connector, Secrets → Cloud Run
Cloud Run → Load Balancer
Cloud Run, Cloud SQL → Monitoring
```

---

### ADR-004: Workload Identity Federation (Keyless CI/CD)

**Decision:** Use Workload Identity Federation (WIF) instead of service account key files for CI/CD authentication.

**Context:** GitHub Actions needs to authenticate with GCP to run Terraform and push Docker images. Traditional approaches use exported JSON key files stored as GitHub secrets.

**Rationale:**
- **No secrets to rotate:** WIF uses OIDC tokens — no long-lived credentials
- **No secrets to leak:** No JSON key file exists anywhere
- **Auditability:** Every CI/CD action is traced to a specific GitHub Actions run
- **Attribute conditions:** Can restrict which repository/branch can authenticate
- **GCP best practice:** Google recommends WIF as the primary method for external workloads

**Implementation:**
```
GitHub Actions Run
  → GitHub OIDC Provider issues JWT token
  → google-github-actions/auth@v2 exchanges JWT for GCP access token
  → Access token used for all gcloud/terraform/docker operations
  → Token expires after 1 hour (non-renewable)
```

**Security Controls:**
- `attribute-condition` restricts authentication to the specific GitHub repository
- Service account has least-privilege roles (8 roles, each justified)
- No service account key export possible

---

### ADR-005: 4-Stage CI/CD Pipeline

**Decision:** Structure the CI/CD pipeline as 4 sequential stages with explicit dependencies.

**Context:** A naive single-stage pipeline fails because Cloud Run references docker images from the Artifact Registry, but the Artifact Registry must exist before images can be pushed.

**Rationale:**
```
Stage 1: Validate    (lint, security scan, unit tests)
Stage 2: Infra       (terraform apply -target: APIs, VPC, SQL, IAM, AR)
Stage 3: Build       (docker build + push to newly created AR)
Stage 4: Deploy      (terraform apply: Cloud Run, LB, Monitoring)
```

- **Stage 1** catches errors before any infrastructure changes
- **Stage 2** creates the Artifact Registry so Stage 3 has somewhere to push
- **Stage 3** builds and pushes the Docker image with a SHA-based tag
- **Stage 4** deploys Cloud Run services referencing the new image

**Trade-offs:**
- Longer pipeline execution (~8-12 minutes total)
- `-target` flag is not recommended for routine use (acceptable for bootstrap)

---

### ADR-006: Custom Cloud Monitoring Metrics for Endpoint Alerts

**Decision:** Use custom Cloud Monitoring metrics to bridge application-level DOWN detection to GCP-native alerting.

**Context:** When the worker detects that a monitored endpoint has gone DOWN, it needs to send an email alert. Options include: direct SMTP, SendGrid API, Pub/Sub, or Cloud Monitoring custom metrics.

**Rationale:**
- **Unified alerting:** All alerts (infrastructure + application) go through the same Cloud Monitoring pipeline
- **No additional services:** No need for SendGrid, Mailgun, or SMTP configuration
- **Policy-driven:** Alert conditions, thresholds, and notification channels are managed declaratively in Terraform
- **Audit trail:** All alert events are visible in the Cloud Monitoring console
- **Scalable:** Adding Slack, PagerDuty, or SMS alerts is a single Terraform change

**Implementation Flow:**
```
Worker detects DOWN
  → services/alerts.py writes custom metric
    (custom.googleapis.com/cloudpulse/endpoint_down)
  → Cloud Monitoring evaluates alert policy
  → Condition met (metric value > 0)
  → Notification channel sends email
```

**Pre-created Metric Descriptors:** Terraform creates the metric descriptors at infrastructure time so alert policies can reference them before any data points exist.

---

### ADR-007: Global HTTP(S) Load Balancer

**Decision:** Use a Global External HTTP(S) Load Balancer with a static IP address.

**Context:** Cloud Run services have auto-generated URLs that change on redeployment. A stable entry point is needed for users and monitoring.

**Rationale:**
- **Stable IP:** Static IP address (`35.190.37.1`) that never changes
- **Global reach:** Google's edge network routes users to the nearest backend
- **Health checking:** Built-in health checks for Cloud Run backend
- **Future-proof:** Easy to add Cloud CDN, Cloud Armor WAF, or custom domain + SSL
- **Ingress control:** Cloud Run set to `INGRESS_TRAFFIC_INTERNAL_ONLY` — only accepts traffic from the LB

**Trade-offs:**
- Cost (~$18/month) — the most expensive single resource
- HTTP only (no HTTPS without a custom domain and SSL certificate)

---

### ADR-008: Destroy Lifecycle with Deletion Policies

**Decision:** Use `deletion_policy = "ABANDON"` on Cloud SQL resources and VPC peering to enable clean `terraform destroy`.

**Context:** When destroying infrastructure, Terraform processes resources in parallel. Cloud SQL cannot be deleted while Cloud Run services hold active connections, and VPC peering cannot be deleted while Cloud SQL exists. This creates circular destruction failures.

**Rationale:**
- `deletion_policy = "ABANDON"` on Cloud SQL database, user, and VPC peering tells Terraform to remove them from state without attempting deletion
- The parent resources (Cloud SQL instance, VPC) handle cleanup when they are destroyed
- The destroy workflow applies config changes first, then destroys in order: Cloud Run → Cloud SQL → VPC

**3-Stage Destroy Pipeline:**
```
Stage 1: terraform apply (pick up deletion_policy changes)
Stage 2: terraform destroy -target=module.cloud_run (release DB connections)
Stage 3: terraform destroy (remaining infrastructure)
```

---

## 4. Security Architecture

### 4.1 Defense in Depth

```
Layer 1: Network     → VPC + Firewall deny-all + Private IPs
Layer 2: Identity    → WIF (keyless) + Least-privilege IAM
Layer 3: Secrets     → Secret Manager (no env vars or code)
Layer 4: Transport   → VPC Connector (private path to SQL)
Layer 5: Container   → Non-root user + Multi-stage build
Layer 6: Audit       → VPC Flow Logs + Cloud Logging
```

### 4.2 IAM Role Inventory

**Application Service Accounts (Terraform-managed):**

| Account | Roles | Scope |
|---------|-------|-------|
| `cloudpulse-dev-web-sa` | `cloudsql.client`, `logging.logWriter`, `monitoring.metricWriter`, `secretmanager.secretAccessor` | Web dashboard |
| `cloudpulse-dev-worker-sa` | `cloudsql.client`, `logging.logWriter`, `monitoring.metricWriter`, `secretmanager.secretAccessor` | Health check worker |

**CI/CD Service Account (manually configured):**

| Account | Roles |
|---------|-------|
| `cloudpulse-dev-github-sa` | `editor`, `compute.networkAdmin`, `servicenetworking.networksAdmin`, `run.admin`, `iam.serviceAccountAdmin`, `iam.serviceAccountUser`, `resourcemanager.projectIamAdmin`, `secretmanager.admin` |

---

## 5. Non-Functional Requirements

| Requirement | Target | How Achieved |
|-------------|--------|-------------|
| **Availability** | 99.5% (dashboard) | Cloud Run auto-scaling, LB health checks |
| **Latency** | < 500ms (dashboard load) | Cloud Run, LB edge caching |
| **Recovery** | < 15 min (RTO) | CI/CD redeploy, Cloud SQL auto-backup |
| **Cost** | < $60/month | Scale-to-zero, db-f1-micro, minimal infra |
| **Alerting** | < 5 min (notification) | Cloud Monitoring custom metrics |
| **Deployment** | < 15 min (end-to-end) | 4-stage CI/CD pipeline |

---

## 6. Appendix

### 6.1 GCP Resources Created (59 total)

| Module | Resource Count |
|--------|---------------|
| APIs | 12 |
| VPC + Subnet + Peering | 4 |
| NAT + Router | 2 |
| VPC Connector | 1 |
| Firewall | 3 |
| Cloud SQL + DB + User | 4 |
| Secrets | 2 |
| Artifact Registry | 1 |
| IAM | 10 |
| Cloud Run | 4 |
| Load Balancer | 7 |
| Monitoring | 9 |

### 6.2 References

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Terraform Google Provider v6](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Monitoring Custom Metrics](https://cloud.google.com/monitoring/custom-metrics)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
