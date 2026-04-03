# ──────────────────────────────────────────────────────────────
# CloudPulse — Health Check Route
# ──────────────────────────────────────────────────────────────
# Simple health endpoint used by:
#   1. Global HTTP(S) Load Balancer health probes
#   2. Cloud Run startup/liveness probes
#   3. GCP Uptime Checks
# ──────────────────────────────────────────────────────────────

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text

from database import get_db

router = APIRouter(prefix="/api", tags=["Health"])


@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    """
    Health check endpoint that verifies both the application
    and database connection are operational.

    Returns 200 if healthy, 503 if database is unreachable.
    """
    try:
        # Verify database connectivity
        db.execute(text("SELECT 1"))
        return {
            "status": "healthy",
            "service": "cloudpulse-web",
            "database": "connected",
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "service": "cloudpulse-web",
            "database": "disconnected",
            "error": str(e),
        }
