# ──────────────────────────────────────────────────────────────
# CloudPulse — Endpoint CRUD Routes (REST API)
# ──────────────────────────────────────────────────────────────

import uuid
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, HttpUrl
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import get_db
from models import Endpoint, HealthCheck

logger = logging.getLogger("cloudpulse.endpoints")

router = APIRouter(prefix="/api/endpoints", tags=["Endpoints"])


# ─── Pydantic Schemas ────────────────────────────────────────

class EndpointCreate(BaseModel):
    """Schema for creating a new endpoint to monitor."""
    name: str
    url: str
    check_interval: int = 300
    is_active: bool = True


class EndpointUpdate(BaseModel):
    """Schema for updating an existing endpoint."""
    name: Optional[str] = None
    url: Optional[str] = None
    check_interval: Optional[int] = None
    is_active: Optional[bool] = None


class EndpointResponse(BaseModel):
    """Schema for endpoint API responses."""
    id: uuid.UUID
    name: str
    url: str
    check_interval: int
    is_active: bool
    created_at: datetime
    updated_at: datetime
    current_status: Optional[bool] = None
    uptime_24h: Optional[float] = None
    avg_response_time_ms: Optional[float] = None

    class Config:
        from_attributes = True


class HealthCheckResponse(BaseModel):
    """Schema for health check API responses."""
    id: uuid.UUID
    status_code: Optional[int]
    response_time_ms: Optional[int]
    is_healthy: bool
    error_message: Optional[str]
    checked_at: datetime

    class Config:
        from_attributes = True


# ─── Helper: Calculate Uptime Percentage ─────────────────────

def calculate_uptime(db: Session, endpoint_id: uuid.UUID, hours: int = 24) -> float:
    """Calculate uptime percentage over the specified number of hours."""
    since = datetime.now(timezone.utc) - timedelta(hours=hours)

    total = db.query(func.count(HealthCheck.id)).filter(
        HealthCheck.endpoint_id == endpoint_id,
        HealthCheck.checked_at >= since,
    ).scalar()

    if total == 0:
        return 100.0

    healthy = db.query(func.count(HealthCheck.id)).filter(
        HealthCheck.endpoint_id == endpoint_id,
        HealthCheck.checked_at >= since,
        HealthCheck.is_healthy == True,
    ).scalar()

    return round((healthy / total) * 100, 2)


def get_avg_response_time(db: Session, endpoint_id: uuid.UUID, hours: int = 24) -> float:
    """Calculate average response time in ms over the specified hours."""
    since = datetime.now(timezone.utc) - timedelta(hours=hours)

    avg = db.query(func.avg(HealthCheck.response_time_ms)).filter(
        HealthCheck.endpoint_id == endpoint_id,
        HealthCheck.checked_at >= since,
        HealthCheck.response_time_ms.isnot(None),
    ).scalar()

    return round(avg, 1) if avg else 0.0


# ─── POST /api/endpoints — Create endpoint ───────────────────

@router.post("/", response_model=EndpointResponse, status_code=status.HTTP_201_CREATED)
def create_endpoint(payload: EndpointCreate, db: Session = Depends(get_db)):
    """Add a new endpoint to monitor."""
    endpoint = Endpoint(
        name=payload.name,
        url=payload.url,
        check_interval=payload.check_interval,
        is_active=payload.is_active,
    )
    db.add(endpoint)
    db.commit()
    db.refresh(endpoint)

    logger.info(f"Created endpoint: {endpoint.name} ({endpoint.url})")

    return EndpointResponse(
        id=endpoint.id,
        name=endpoint.name,
        url=endpoint.url,
        check_interval=endpoint.check_interval,
        is_active=endpoint.is_active,
        created_at=endpoint.created_at,
        updated_at=endpoint.updated_at,
    )


# ─── GET /api/endpoints — List all endpoints ─────────────────

@router.get("/", response_model=list[EndpointResponse])
def list_endpoints(db: Session = Depends(get_db)):
    """List all monitored endpoints with current status and uptime."""
    endpoints = db.query(Endpoint).order_by(Endpoint.created_at.desc()).all()

    results = []
    for ep in endpoints:
        # Get the latest health check
        latest = (
            db.query(HealthCheck)
            .filter(HealthCheck.endpoint_id == ep.id)
            .order_by(HealthCheck.checked_at.desc())
            .first()
        )

        results.append(EndpointResponse(
            id=ep.id,
            name=ep.name,
            url=ep.url,
            check_interval=ep.check_interval,
            is_active=ep.is_active,
            created_at=ep.created_at,
            updated_at=ep.updated_at,
            current_status=latest.is_healthy if latest else None,
            uptime_24h=calculate_uptime(db, ep.id, hours=24),
            avg_response_time_ms=get_avg_response_time(db, ep.id, hours=24),
        ))

    return results


# ─── GET /api/endpoints/{id} — Get endpoint details ──────────

@router.get("/{endpoint_id}", response_model=EndpointResponse)
def get_endpoint(endpoint_id: uuid.UUID, db: Session = Depends(get_db)):
    """Get details for a specific endpoint including uptime stats."""
    endpoint = db.query(Endpoint).filter(Endpoint.id == endpoint_id).first()

    if not endpoint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Endpoint {endpoint_id} not found",
        )

    latest = (
        db.query(HealthCheck)
        .filter(HealthCheck.endpoint_id == endpoint.id)
        .order_by(HealthCheck.checked_at.desc())
        .first()
    )

    return EndpointResponse(
        id=endpoint.id,
        name=endpoint.name,
        url=endpoint.url,
        check_interval=endpoint.check_interval,
        is_active=endpoint.is_active,
        created_at=endpoint.created_at,
        updated_at=endpoint.updated_at,
        current_status=latest.is_healthy if latest else None,
        uptime_24h=calculate_uptime(db, endpoint.id, hours=24),
        avg_response_time_ms=get_avg_response_time(db, endpoint.id, hours=24),
    )


# ─── GET /api/endpoints/{id}/history — Get check history ─────

@router.get("/{endpoint_id}/history", response_model=list[HealthCheckResponse])
def get_endpoint_history(
    endpoint_id: uuid.UUID,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    """Get the health check history for an endpoint."""
    endpoint = db.query(Endpoint).filter(Endpoint.id == endpoint_id).first()

    if not endpoint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Endpoint {endpoint_id} not found",
        )

    checks = (
        db.query(HealthCheck)
        .filter(HealthCheck.endpoint_id == endpoint_id)
        .order_by(HealthCheck.checked_at.desc())
        .limit(limit)
        .all()
    )

    return [
        HealthCheckResponse(
            id=c.id,
            status_code=c.status_code,
            response_time_ms=c.response_time_ms,
            is_healthy=c.is_healthy,
            error_message=c.error_message,
            checked_at=c.checked_at,
        )
        for c in checks
    ]


# ─── PUT /api/endpoints/{id} — Update endpoint ───────────────

@router.put("/{endpoint_id}", response_model=EndpointResponse)
def update_endpoint(
    endpoint_id: uuid.UUID,
    payload: EndpointUpdate,
    db: Session = Depends(get_db),
):
    """Update an existing monitored endpoint."""
    endpoint = db.query(Endpoint).filter(Endpoint.id == endpoint_id).first()

    if not endpoint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Endpoint {endpoint_id} not found",
        )

    if payload.name is not None:
        endpoint.name = payload.name
    if payload.url is not None:
        endpoint.url = payload.url
    if payload.check_interval is not None:
        endpoint.check_interval = payload.check_interval
    if payload.is_active is not None:
        endpoint.is_active = payload.is_active

    endpoint.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(endpoint)

    logger.info(f"Updated endpoint: {endpoint.name}")

    return EndpointResponse(
        id=endpoint.id,
        name=endpoint.name,
        url=endpoint.url,
        check_interval=endpoint.check_interval,
        is_active=endpoint.is_active,
        created_at=endpoint.created_at,
        updated_at=endpoint.updated_at,
    )


# ─── DELETE /api/endpoints/{id} — Remove endpoint ────────────

@router.delete("/{endpoint_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_endpoint(endpoint_id: uuid.UUID, db: Session = Depends(get_db)):
    """Remove an endpoint and all its health check history."""
    endpoint = db.query(Endpoint).filter(Endpoint.id == endpoint_id).first()

    if not endpoint:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Endpoint {endpoint_id} not found",
        )

    logger.info(f"Deleting endpoint: {endpoint.name} ({endpoint.url})")
    db.delete(endpoint)
    db.commit()
