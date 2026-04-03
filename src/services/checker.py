# ──────────────────────────────────────────────────────────────
# CloudPulse — Health Check Service
# ──────────────────────────────────────────────────────────────
# Core logic for performing HTTP health checks on endpoints.
# Measures response time, captures status codes, and handles
# timeouts and connection errors gracefully.
# ──────────────────────────────────────────────────────────────

import time
import logging
from dataclasses import dataclass
from typing import Optional

import httpx

from config import settings

logger = logging.getLogger("cloudpulse.checker")


@dataclass
class CheckResult:
    """Result of a single health check against an endpoint."""
    url: str
    is_healthy: bool
    status_code: Optional[int] = None
    response_time_ms: Optional[int] = None
    error_message: Optional[str] = None


async def check_endpoint(url: str) -> CheckResult:
    """
    Perform an HTTP GET health check against the given URL.

    A check is considered healthy if:
      - The HTTP response status code is 2xx or 3xx
      - The response is received within the timeout window

    Args:
        url: The full URL to check (e.g., https://example.com)

    Returns:
        CheckResult with status, response time, and any error details.
    """
    start_time = time.monotonic()

    try:
        async with httpx.AsyncClient(
            timeout=settings.check_timeout_seconds,
            follow_redirects=True,
            verify=True,
        ) as client:
            response = await client.get(url)

        elapsed_ms = int((time.monotonic() - start_time) * 1000)
        is_healthy = response.status_code < 400

        result = CheckResult(
            url=url,
            is_healthy=is_healthy,
            status_code=response.status_code,
            response_time_ms=elapsed_ms,
            error_message=None if is_healthy else f"HTTP {response.status_code}",
        )

        log_level = logging.INFO if is_healthy else logging.WARNING
        logger.log(
            log_level,
            f"{'✓' if is_healthy else '✗'} {url} → "
            f"{response.status_code} ({elapsed_ms}ms)"
        )

        return result

    except httpx.TimeoutException:
        elapsed_ms = int((time.monotonic() - start_time) * 1000)
        logger.warning(f"✗ {url} → TIMEOUT ({elapsed_ms}ms)")
        return CheckResult(
            url=url,
            is_healthy=False,
            response_time_ms=elapsed_ms,
            error_message=f"Timeout after {settings.check_timeout_seconds}s",
        )

    except httpx.ConnectError as e:
        elapsed_ms = int((time.monotonic() - start_time) * 1000)
        logger.warning(f"✗ {url} → CONNECTION ERROR: {e}")
        return CheckResult(
            url=url,
            is_healthy=False,
            response_time_ms=elapsed_ms,
            error_message=f"Connection error: {str(e)[:200]}",
        )

    except Exception as e:
        elapsed_ms = int((time.monotonic() - start_time) * 1000)
        logger.error(f"✗ {url} → UNEXPECTED ERROR: {e}")
        return CheckResult(
            url=url,
            is_healthy=False,
            response_time_ms=elapsed_ms,
            error_message=f"Error: {str(e)[:200]}",
        )
