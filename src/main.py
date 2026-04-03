# ──────────────────────────────────────────────────────────────
# CloudPulse — FastAPI Application Entry Point
# ──────────────────────────────────────────────────────────────

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from config import settings
from database import init_db
from routes.health import router as health_router
from routes.endpoints import router as endpoints_router
from routes.dashboard import router as dashboard_router

# ─── Logging Configuration ───────────────────────────────────
# Structured JSON logs are automatically captured by Cloud Logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("cloudpulse")


# ─── Application Lifespan ────────────────────────────────────
# Runs on startup and shutdown

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database tables on startup."""
    logger.info("CloudPulse Web starting up...")
    logger.info(f"Environment: {settings.app_env}")
    logger.info(f"Database host: {settings.db_host}")
    init_db()
    logger.info("Database tables initialized.")
    yield
    logger.info("CloudPulse Web shutting down.")


# ─── Create FastAPI Application ──────────────────────────────

app = FastAPI(
    title="CloudPulse — Uptime Monitoring Platform",
    description=(
        "A cloud-native uptime monitoring service that continuously "
        "checks the health of your endpoints, tracks response times, "
        "and alerts you when services go down."
    ),
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    lifespan=lifespan,
)

# ─── Static Files ────────────────────────────────────────────

app.mount("/static", StaticFiles(directory="static"), name="static")

# ─── Register Route Modules ─────────────────────────────────

app.include_router(health_router)
app.include_router(dashboard_router)
app.include_router(endpoints_router)

logger.info("CloudPulse application initialized.")
