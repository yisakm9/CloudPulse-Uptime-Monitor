-- ──────────────────────────────────────────────────────────────
-- CloudPulse — Database Initialization Script
-- ──────────────────────────────────────────────────────────────
-- This script is run automatically by SQLAlchemy on first boot.
-- It's provided here as reference and for manual execution.
-- ──────────────────────────────────────────────────────────────

-- Ensure UUID extension is available
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Endpoints table
CREATE TABLE IF NOT EXISTS endpoints (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    url             VARCHAR(2048) NOT NULL,
    check_interval  INTEGER DEFAULT 300,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Health checks table
CREATE TABLE IF NOT EXISTS health_checks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    endpoint_id     UUID REFERENCES endpoints(id) ON DELETE CASCADE,
    status_code     INTEGER,
    response_time_ms INTEGER,
    is_healthy      BOOLEAN NOT NULL,
    error_message   TEXT,
    checked_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Performance index for time-range queries
CREATE INDEX IF NOT EXISTS idx_health_checks_endpoint_time
    ON health_checks(endpoint_id, checked_at DESC);

-- Index for active endpoints (worker query)
CREATE INDEX IF NOT EXISTS idx_endpoints_active
    ON endpoints(is_active) WHERE is_active = TRUE;
