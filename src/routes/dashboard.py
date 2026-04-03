# ──────────────────────────────────────────────────────────────
# CloudPulse — Dashboard Routes (Server-Rendered HTML)
# ──────────────────────────────────────────────────────────────

import uuid
import logging
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, Request, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import get_db
from models import Endpoint, HealthCheck
from routes.endpoints import calculate_uptime, get_avg_response_time

logger = logging.getLogger("cloudpulse.dashboard")

router = APIRouter(tags=["Dashboard"])

templates = Jinja2Templates(directory="templates")


@router.get("/", response_class=HTMLResponse)
def dashboard(request: Request, db: Session = Depends(get_db)):
    """
    Render the main dashboard showing all monitored endpoints
    with their current status, uptime, and response times.
    """
    endpoints = db.query(Endpoint).order_by(Endpoint.created_at.desc()).all()

    endpoint_data = []
    total_up = 0
    total_down = 0
    total_unknown = 0

    for ep in endpoints:
        # Get latest health check
        latest = (
            db.query(HealthCheck)
            .filter(HealthCheck.endpoint_id == ep.id)
            .order_by(HealthCheck.checked_at.desc())
            .first()
        )

        # Calculate statistics
        uptime_24h = calculate_uptime(db, ep.id, hours=24)
        uptime_7d = calculate_uptime(db, ep.id, hours=168)
        avg_response = get_avg_response_time(db, ep.id, hours=24)

        # Determine current status
        if latest is None:
            current_status = "unknown"
            total_unknown += 1
        elif latest.is_healthy:
            current_status = "up"
            total_up += 1
        else:
            current_status = "down"
            total_down += 1

        endpoint_data.append({
            "id": ep.id,
            "name": ep.name,
            "url": ep.url,
            "is_active": ep.is_active,
            "current_status": current_status,
            "status_code": latest.status_code if latest else None,
            "response_time_ms": latest.response_time_ms if latest else None,
            "uptime_24h": uptime_24h,
            "uptime_7d": uptime_7d,
            "avg_response_ms": avg_response,
            "last_checked": latest.checked_at if latest else None,
            "error_message": latest.error_message if latest and not latest.is_healthy else None,
        })

    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "endpoints": endpoint_data,
        "total_endpoints": len(endpoints),
        "total_up": total_up,
        "total_down": total_down,
        "total_unknown": total_unknown,
        "now": datetime.now(timezone.utc),
    })


@router.get("/endpoints/{endpoint_id}/detail", response_class=HTMLResponse)
def endpoint_detail(
    request: Request,
    endpoint_id: uuid.UUID,
    db: Session = Depends(get_db),
):
    """
    Render the detail page for a specific endpoint showing
    response time history and health check logs.
    """
    endpoint = db.query(Endpoint).filter(Endpoint.id == endpoint_id).first()

    if not endpoint:
        raise HTTPException(status_code=404, detail="Endpoint not found")

    # Get recent health checks for the chart
    checks = (
        db.query(HealthCheck)
        .filter(HealthCheck.endpoint_id == endpoint_id)
        .order_by(HealthCheck.checked_at.desc())
        .limit(100)
        .all()
    )

    # Prepare chart data (reversed for chronological order)
    chart_labels = [
        c.checked_at.strftime("%H:%M") for c in reversed(checks)
    ]
    chart_data = [
        c.response_time_ms if c.response_time_ms else 0
        for c in reversed(checks)
    ]
    chart_status = [
        1 if c.is_healthy else 0
        for c in reversed(checks)
    ]

    # Calculate uptimes
    uptime_24h = calculate_uptime(db, endpoint_id, hours=24)
    uptime_7d = calculate_uptime(db, endpoint_id, hours=168)
    uptime_30d = calculate_uptime(db, endpoint_id, hours=720)

    # Get latest check
    latest = checks[0] if checks else None

    return templates.TemplateResponse("endpoint_detail.html", {
        "request": request,
        "endpoint": endpoint,
        "latest": latest,
        "checks": checks[:20],  # Last 20 for the log table
        "uptime_24h": uptime_24h,
        "uptime_7d": uptime_7d,
        "uptime_30d": uptime_30d,
        "avg_response": get_avg_response_time(db, endpoint_id, hours=24),
        "chart_labels": chart_labels,
        "chart_data": chart_data,
        "chart_status": chart_status,
    })
