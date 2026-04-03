# ──────────────────────────────────────────────────────────────
# CloudPulse — Background Worker
# ──────────────────────────────────────────────────────────────
# Long-running process that continuously checks the health of
# all active endpoints at their configured intervals.
#
# Architecture:
#   1. Query all active endpoints from Cloud SQL
#   2. Run async health checks concurrently
#   3. Store results in the health_checks table
#   4. Detect status transitions (UP→DOWN) and log alerts
#   5. Sleep for the check interval and repeat
#
# This runs as a separate Cloud Run service with its own
# container, using the same Docker image with a different
# entrypoint: python worker.py
# ──────────────────────────────────────────────────────────────

import asyncio
import logging
import signal
import sys
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.responses import JSONResponse
import uvicorn
import threading

from config import settings
from database import init_db, SessionLocal
from models import Endpoint, HealthCheck
from services.checker import check_endpoint

# ─── Logging ─────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("cloudpulse.worker")

# ─── Graceful Shutdown ───────────────────────────────────────

shutdown_event = asyncio.Event()


def handle_shutdown(signum, frame):
    """Handle SIGTERM/SIGINT for graceful shutdown."""
    logger.info(f"Received signal {signum}. Initiating graceful shutdown...")
    shutdown_event.set()


signal.signal(signal.SIGTERM, handle_shutdown)
signal.signal(signal.SIGINT, handle_shutdown)


# ─── Health Endpoint for Cloud Run ───────────────────────────
# Cloud Run requires a listening port for health probes

health_app = FastAPI()


@health_app.get("/health")
def worker_health():
    return JSONResponse({"status": "healthy", "service": "cloudpulse-worker"})


def run_health_server():
    """Run a minimal health check server in a background thread."""
    uvicorn.run(health_app, host="0.0.0.0", port=8001, log_level="warning")


# ─── Core Worker Logic ───────────────────────────────────────

async def run_checks():
    """
    Fetch all active endpoints and run health checks concurrently.
    Store results and detect status transitions.
    """
    db = SessionLocal()

    try:
        # Fetch all active endpoints
        endpoints = db.query(Endpoint).filter(Endpoint.is_active == True).all()

        if not endpoints:
            logger.info("No active endpoints to check.")
            return

        logger.info(f"Checking {len(endpoints)} active endpoints...")

        # Run all checks concurrently
        tasks = [check_endpoint(ep.url) for ep in endpoints]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Process results
        for endpoint, result in zip(endpoints, results):
            if isinstance(result, Exception):
                logger.error(f"Check failed for {endpoint.url}: {result}")
                continue

            # Get the previous status for transition detection
            previous_check = (
                db.query(HealthCheck)
                .filter(HealthCheck.endpoint_id == endpoint.id)
                .order_by(HealthCheck.checked_at.desc())
                .first()
            )

            # Store the new check result
            health_check = HealthCheck(
                endpoint_id=endpoint.id,
                status_code=result.status_code,
                response_time_ms=result.response_time_ms,
                is_healthy=result.is_healthy,
                error_message=result.error_message,
                checked_at=datetime.now(timezone.utc),
            )
            db.add(health_check)

            # Detect UP→DOWN transition
            if previous_check and previous_check.is_healthy and not result.is_healthy:
                logger.critical(
                    f"🔴 ENDPOINT DOWN: {endpoint.name} ({endpoint.url}) "
                    f"→ {result.error_message}"
                )

            # Detect DOWN→UP transition (recovery)
            if previous_check and not previous_check.is_healthy and result.is_healthy:
                logger.info(
                    f"🟢 ENDPOINT RECOVERED: {endpoint.name} ({endpoint.url}) "
                    f"→ {result.status_code} ({result.response_time_ms}ms)"
                )

        db.commit()
        logger.info(f"Completed checking {len(endpoints)} endpoints.")

    except Exception as e:
        logger.error(f"Error during health check cycle: {e}")
        db.rollback()
    finally:
        db.close()


async def worker_loop():
    """
    Main worker loop: run checks, sleep, repeat.
    Respects the configured check interval and graceful shutdown.
    """
    logger.info("=" * 60)
    logger.info("CloudPulse Worker started.")
    logger.info(f"Check interval: {settings.check_interval_seconds}s")
    logger.info(f"Check timeout: {settings.check_timeout_seconds}s")
    logger.info(f"Database: {settings.db_host}:{settings.db_port}/{settings.db_name}")
    logger.info("=" * 60)

    while not shutdown_event.is_set():
        await run_checks()

        # Sleep in 1-second increments so we can respond to shutdown quickly
        for _ in range(settings.check_interval_seconds):
            if shutdown_event.is_set():
                break
            await asyncio.sleep(1)

    logger.info("Worker shutdown complete.")


# ─── Entry Point ─────────────────────────────────────────────

def main():
    """Start the worker process."""
    logger.info("Initializing database...")
    init_db()

    # Start health check server in background thread
    health_thread = threading.Thread(target=run_health_server, daemon=True)
    health_thread.start()
    logger.info("Health server started on port 8001")

    # Run the main worker loop
    asyncio.run(worker_loop())


if __name__ == "__main__":
    main()
