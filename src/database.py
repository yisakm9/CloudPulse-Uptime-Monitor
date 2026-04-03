# ──────────────────────────────────────────────────────────────
# CloudPulse — Database Engine & Session Management
# ──────────────────────────────────────────────────────────────

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from config import settings


# ─── SQLAlchemy Engine ────────────────────────────────────────
# Creates a connection pool to Cloud SQL PostgreSQL.
# Pool settings are tuned for Cloud Run's concurrency model.

engine = create_engine(
    settings.database_url,
    pool_size=5,
    max_overflow=10,
    pool_timeout=30,
    pool_recycle=1800,   # Recycle connections every 30 min
    pool_pre_ping=True,  # Verify connection is alive before use
)

# ─── Session Factory ─────────────────────────────────────────

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


# ─── Base Class for Models ────────────────────────────────────

class Base(DeclarativeBase):
    pass


# ─── Dependency: Get DB Session ───────────────────────────────
# Used as a FastAPI dependency to inject a session per request.

def get_db():
    """Yield a database session and ensure it is closed after use."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ─── Database Initialization ─────────────────────────────────

def init_db():
    """Create all tables if they don't exist."""
    Base.metadata.create_all(bind=engine)
