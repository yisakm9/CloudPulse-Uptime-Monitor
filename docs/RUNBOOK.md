# Operations Runbook — CloudPulse Uptime Monitor

> **Document Version:** 1.0  
> **Author:** Yisak Mesifin  
> **Last Updated:** April 2026  
> **Environment:** `cloudpulse-uptime-dev` (GCP us-central1)

---

## Table of Contents

1. [Access & Endpoints](#1-access--endpoints)
2. [Monitoring & Alerting](#2-monitoring--alerting)
3. [Deployment Procedures](#3-deployment-procedures)
4. [Troubleshooting](#4-troubleshooting)
5. [Database Operations](#5-database-operations)
6. [Incident Response](#6-incident-response)
7. [Cost Management](#7-cost-management)

---

## 1. Access & Endpoints

### 1.1 Service URLs

| Service | URL | Notes |
|---------|-----|-------|
| Dashboard | `http://35.190.37.1` | Global LB static IP |
| API Docs | `http://35.190.37.1/api/docs` | Swagger/OpenAPI |
| Health Check | `http://35.190.37.1/api/health` | Used by LB and uptime check |
| GitHub Repo | `github.com/yisakm9/CloudPulse-Uptime-Monitor` | Source code |
| GCP Console | `console.cloud.google.com/run?project=cloudpulse-uptime-dev` | Cloud Run services |
| Monitoring | `console.cloud.google.com/monitoring?project=cloudpulse-uptime-dev` | Alerts and metrics |

### 1.2 GCP Authentication

```bash
# Authenticate to GCP
gcloud auth login

# Set project
gcloud config set project cloudpulse-uptime-dev

# Verify access
gcloud projects describe cloudpulse-uptime-dev
```

### 1.3 Terraform State

```bash
# State is stored in GCS
gsutil ls gs://cloudpulse-terraform-state-dev/

# List resources in state
cd environments/dev
terraform init
terraform state list
```

---

## 2. Monitoring & Alerting

### 2.1 Alert Policies

| Policy Name | Condition | Notification |
|------------|-----------|--------------|
| `cloudpulse-dev-site-down` | LB uptime check fails for 5 min | Email |
| `cloudpulse-dev-endpoint-down` | Worker detects endpoint DOWN | Email |
| `cloudpulse-dev-cloud-run-5xx-errors` | >5 server errors in 5 min | Email |
| `cloudpulse-dev-cloud-sql-high-cpu` | CPU > 80% for 5 min | Email |
| `cloudpulse-dev-cloud-sql-disk-usage` | Disk > 80% for 5 min | Email |

### 2.2 Check Alert Status

```bash
# List all alert policies
gcloud alpha monitoring policies list --project=cloudpulse-uptime-dev \
  --format="table(displayName,enabled,conditions.displayName)"

# Check notification channels
gcloud alpha monitoring channels list --project=cloudpulse-uptime-dev \
  --format="table(displayName,type,labels.email_address)"

# View recent alert incidents
gcloud alpha monitoring incidents list --project=cloudpulse-uptime-dev
```

### 2.3 View Custom Metrics

```bash
# Check if endpoint_down metrics have been written
gcloud monitoring metrics-descriptors list --project=cloudpulse-uptime-dev \
  --filter="type:custom.googleapis.com/cloudpulse" \
  --format="table(type,metricKind,valueType)"
```

### 2.4 View Logs

```bash
# Web service logs (last 30 entries)
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="cloudpulse-dev-web"' \
  --project=cloudpulse-uptime-dev --limit=30 \
  --format="table(timestamp,textPayload)"

# Worker service logs (last 30 entries)
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="cloudpulse-dev-worker"' \
  --project=cloudpulse-uptime-dev --limit=30 \
  --format="table(timestamp,textPayload)"

# Worker errors only
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="cloudpulse-dev-worker" AND severity>=ERROR' \
  --project=cloudpulse-uptime-dev --limit=20 \
  --format="table(timestamp,textPayload)"

# Filter for DOWN alerts
gcloud logging read 'resource.type="cloud_run_revision" AND textPayload:"ENDPOINT DOWN"' \
  --project=cloudpulse-uptime-dev --limit=20 \
  --format="table(timestamp,textPayload)"
```

---

## 3. Deployment Procedures

### 3.1 Standard Deployment (via CI/CD)

```bash
# Push changes to main — pipeline runs automatically
git add . && git commit -m "feat: description" && git push origin main
```

Pipeline stages:
1. **Validate** (~1 min) — fmt, lint, security scan, pytest
2. **Infrastructure** (~3-5 min) — terraform apply (targeted)
3. **Build** (~2-3 min) — docker build + push
4. **Deploy** (~3-5 min) — terraform apply (full)

### 3.2 Manual Deployment (Emergency)

```bash
# Authenticate
gcloud auth login
gcloud config set project cloudpulse-uptime-dev

# Build and push image manually
cd src
docker build -t us-central1-docker.pkg.dev/cloudpulse-uptime-dev/cloudpulse-dev-repo/cloudpulse:emergency .
docker push us-central1-docker.pkg.dev/cloudpulse-uptime-dev/cloudpulse-dev-repo/cloudpulse:emergency

# Deploy to Cloud Run directly
gcloud run deploy cloudpulse-dev-web \
  --image=us-central1-docker.pkg.dev/cloudpulse-uptime-dev/cloudpulse-dev-repo/cloudpulse:emergency \
  --region=us-central1

gcloud run deploy cloudpulse-dev-worker \
  --image=us-central1-docker.pkg.dev/cloudpulse-uptime-dev/cloudpulse-dev-repo/cloudpulse:emergency \
  --region=us-central1
```

### 3.3 Rollback

```bash
# List Cloud Run revisions
gcloud run revisions list --service=cloudpulse-dev-web \
  --project=cloudpulse-uptime-dev --region=us-central1

# Roll back to a previous revision
gcloud run services update-traffic cloudpulse-dev-web \
  --to-revisions=REVISION_NAME=100 \
  --project=cloudpulse-uptime-dev --region=us-central1
```

### 3.4 Full Destroy and Rebuild

```bash
# Via GitHub Actions (recommended)
# 1. Go to Actions → "Destroy CloudPulse - Dev"
# 2. Run workflow → type "destroy all resources"
# 3. Wait for completion (~5-10 min)
# 4. Push a commit to trigger redeploy
```

---

## 4. Troubleshooting

### 4.1 Dashboard Returns 502 / 503

**Symptoms:** Browser shows "502 Bad Gateway" or "503 Service Unavailable"

**Diagnosis:**
```bash
# Check if Cloud Run services are running
gcloud run services list --project=cloudpulse-uptime-dev --region=us-central1

# Check web service revision status
gcloud run revisions list --service=cloudpulse-dev-web \
  --project=cloudpulse-uptime-dev --region=us-central1

# Check recent logs for startup errors
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="cloudpulse-dev-web" AND severity>=WARNING' \
  --project=cloudpulse-uptime-dev --limit=10
```

**Common Causes:**
| Cause | Fix |
|-------|-----|
| Cold start timeout | Wait 30s and retry; increase min instances to 1 |
| Database connection failure | Check Cloud SQL status, VPC Connector health |
| Bad deployment | Rollback to previous revision (see 3.3) |

### 4.2 Worker Not Checking Endpoints

**Symptoms:** Dashboard shows stale "Last checked" timestamps

**Diagnosis:**
```bash
# Check worker status
gcloud run services describe cloudpulse-dev-worker \
  --project=cloudpulse-uptime-dev --region=us-central1 \
  --format="value(status.conditions)"

# Check worker logs
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="cloudpulse-dev-worker"' \
  --project=cloudpulse-uptime-dev --limit=20 \
  --format="table(timestamp,textPayload)"
```

**Common Causes:**
| Cause | Fix |
|-------|-----|
| Worker crashed | Check logs for Python exceptions, redeploy |
| DB connection pool exhausted | Check Cloud SQL connections, restart worker |
| VPC Connector unhealthy | Check connector status in VPC Network → Connectors |

### 4.3 Terraform State Lock

**Symptoms:** `Error acquiring the state lock`

```bash
# Force unlock the state (use with caution)
cd environments/dev
terraform force-unlock LOCK_ID
```

### 4.4 CI/CD Pipeline Failures

| Error | Cause | Fix |
|-------|-------|-----|
| `Permission denied` | Missing IAM role | Grant role to GitHub SA (see README) |
| `Resource already exists` | Orphaned resource | `terraform import` the resource |
| `Image not found` | AR not created yet | Re-run pipeline (Stage 2 creates AR) |
| `State lock` | Concurrent run | Cancel duplicate runs, force-unlock |

---

## 5. Database Operations

### 5.1 Connect to Cloud SQL

```bash
# Via Cloud SQL Proxy (for local access)
cloud-sql-proxy cloudpulse-uptime-dev:us-central1:cloudpulse-dev-db

# In another terminal
psql -h 127.0.0.1 -U cloudpulse_user -d cloudpulse
```

### 5.2 Get Database Password

```bash
# From Secret Manager
gcloud secrets versions access latest \
  --secret=cloudpulse-dev-db-password \
  --project=cloudpulse-uptime-dev
```

### 5.3 Database Schema

```sql
-- Endpoints table
SELECT * FROM endpoints LIMIT 10;

-- Health check history
SELECT * FROM health_checks ORDER BY checked_at DESC LIMIT 20;

-- Uptime calculation for an endpoint
SELECT
  e.name,
  COUNT(*) as total_checks,
  SUM(CASE WHEN hc.is_healthy THEN 1 ELSE 0 END) as healthy_checks,
  ROUND(
    SUM(CASE WHEN hc.is_healthy THEN 1 ELSE 0 END)::decimal /
    COUNT(*) * 100, 2
  ) as uptime_pct
FROM health_checks hc
JOIN endpoints e ON e.id = hc.endpoint_id
WHERE hc.checked_at > NOW() - INTERVAL '24 hours'
GROUP BY e.name;
```

### 5.4 Backup & Restore

```bash
# List backups
gcloud sql backups list --instance=cloudpulse-dev-db \
  --project=cloudpulse-uptime-dev

# Restore from a backup
gcloud sql backups restore BACKUP_ID \
  --restore-instance=cloudpulse-dev-db \
  --project=cloudpulse-uptime-dev
```

---

## 6. Incident Response

### 6.1 Severity Levels

| Level | Description | Example | Response Time |
|-------|-------------|---------|--------------|
| **P1** | Complete outage | Dashboard unreachable | < 15 min |
| **P2** | Partial degradation | Alerts not sending | < 1 hour |
| **P3** | Minor issue | Slow response times | < 4 hours |
| **P4** | Cosmetic | UI rendering issue | Next business day |

### 6.2 P1 Response Checklist

```markdown
1. [ ] Check Cloud Run service status (is it running?)
2. [ ] Check Cloud SQL status (is the database up?)
3. [ ] Check VPC Connector health (is networking working?)
4. [ ] Check recent deployment (did a bad push break things?)
5. [ ] If bad deployment → rollback (Section 3.3)
6. [ ] If infrastructure issue → check Terraform state
7. [ ] If DB issue → check connections, restart if needed
8. [ ] Document the incident and root cause
```

---

## 7. Cost Management

### 7.1 Current Cost Breakdown

| Resource | Monthly Cost | Optimization |
|----------|-------------|-------------|
| Cloud Run (web) | ~$5-8 | Scale-to-zero enabled |
| Cloud Run (worker) | ~$5-8 | cpu_idle = false (required) |
| Cloud SQL | ~$8-10 | db-f1-micro tier |
| Load Balancer | ~$18 | Fixed cost, no optimization |
| VPC Connector | ~$6 | e2-micro × 2 (minimum) |
| NAT + Monitoring | ~$2-4 | Minimal usage |
| **Total** | **~$45-55** | |

### 7.2 Cost Reduction Options

| Action | Savings | Trade-off |
|--------|---------|-----------|
| Remove LB, use Cloud Run URL directly | -$18/month | No stable IP, CORS issues |
| Pause worker when not needed | -$5-8/month | No monitoring during pause |
| Use Cloud SQL proxy instead of VPC Connector | -$6/month | More complex networking |
| Switch to SQLite (Cloud Run volume mount) | -$14/month | No managed backups, less reliable |

### 7.3 Monitor Costs

```bash
# Check current month billing
gcloud billing accounts list
gcloud billing projects describe cloudpulse-uptime-dev

# View cost breakdown in Console
# → https://console.cloud.google.com/billing
```

---

## Appendix A: Service Account Reference

| Service Account | Purpose | Managed By |
|----------------|---------|-----------|
| `cloudpulse-dev-web-sa` | Web dashboard + API | Terraform |
| `cloudpulse-dev-worker-sa` | Health check worker | Terraform |
| `cloudpulse-dev-github-sa` | CI/CD pipeline | Manual (bootstrap) |

## Appendix B: Environment Variables

| Variable | Service | Source |
|----------|---------|--------|
| `APP_ENV` | Both | Terraform (hardcoded) |
| `DB_HOST` | Both | Terraform (Cloud SQL private IP) |
| `DB_NAME` | Both | Terraform (hardcoded) |
| `DB_USER` | Both | Terraform (hardcoded) |
| `DB_PORT` | Both | Terraform (hardcoded: 5432) |
| `DB_PASSWORD` | Both | Secret Manager |
| `CHECK_INTERVAL_SECONDS` | Worker | Terraform (hardcoded: 300) |
| `PROJECT_ID` | Worker | Terraform (project ID) |
