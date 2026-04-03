# ──────────────────────────────────────────────────────────────
# CloudPulse — Database Models
# ──────────────────────────────────────────────────────────────

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column, String, Integer, Boolean, Text,
    DateTime, ForeignKey, Index
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from database import Base


class Endpoint(Base):
    """
    Represents a URL/API endpoint to monitor.
    Each endpoint has a name, URL, check interval, and active status.
    """
    __tablename__ = "endpoints"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    name = Column(String(255), nullable=False)
    url = Column(String(2048), nullable=False)
    check_interval = Column(Integer, default=300)  # seconds
    is_active = Column(Boolean, default=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relationship: one endpoint has many health checks
    health_checks = relationship(
        "HealthCheck",
        back_populates="endpoint",
        cascade="all, delete-orphan",
        order_by="HealthCheck.checked_at.desc()",
    )

    def __repr__(self):
        return f"<Endpoint(name='{self.name}', url='{self.url}')>"


class HealthCheck(Base):
    """
    Represents a single health check result for an endpoint.
    Stores HTTP status code, response time, and whether it was healthy.
    """
    __tablename__ = "health_checks"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    endpoint_id = Column(
        UUID(as_uuid=True),
        ForeignKey("endpoints.id", ondelete="CASCADE"),
        nullable=False,
    )
    status_code = Column(Integer, nullable=True)
    response_time_ms = Column(Integer, nullable=True)
    is_healthy = Column(Boolean, nullable=False)
    error_message = Column(Text, nullable=True)
    checked_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )

    # Relationship back to endpoint
    endpoint = relationship("Endpoint", back_populates="health_checks")

    # Index for fast time-range queries per endpoint
    __table_args__ = (
        Index(
            "idx_health_checks_endpoint_time",
            "endpoint_id",
            checked_at.desc(),
        ),
    )

    def __repr__(self):
        status = "UP" if self.is_healthy else "DOWN"
        return f"<HealthCheck(endpoint={self.endpoint_id}, status={status})>"
