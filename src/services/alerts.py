# ──────────────────────────────────────────────────────────────
# CloudPulse — Alert Service
# ──────────────────────────────────────────────────────────────
# Writes custom metrics to Google Cloud Monitoring when an
# endpoint transitions UP→DOWN or DOWN→UP. These metrics
# trigger alert policies that email the configured address.
# ──────────────────────────────────────────────────────────────

import logging
import os

logger = logging.getLogger("cloudpulse.alerts")


def send_down_alert(endpoint_name: str, endpoint_url: str, error_message: str):
    """
    Write a custom metric to Cloud Monitoring when an endpoint goes DOWN.
    This fires the alert policy → notification channel → email.
    """
    try:
        # Only use Cloud Monitoring in non-local environments
        app_env = os.environ.get("APP_ENV", "local")
        if app_env == "local":
            logger.warning(
                f"[LOCAL] Would send DOWN alert for {endpoint_name}: {error_message}"
            )
            return

        from google.cloud import monitoring_v3
        from google.api import metric_pb2
        from google.protobuf import timestamp_pb2
        import time

        project_id = os.environ.get("PROJECT_ID", "")
        if not project_id:
            logger.error("PROJECT_ID not set, cannot send Cloud Monitoring alert")
            return

        client = monitoring_v3.MetricServiceClient()
        project_name = f"projects/{project_id}"

        # Create a time series data point
        series = monitoring_v3.TimeSeries()
        series.metric.type = "custom.googleapis.com/cloudpulse/endpoint_down"
        series.metric.labels["endpoint_name"] = endpoint_name[:64]
        series.metric.labels["endpoint_url"] = endpoint_url[:128]

        series.resource.type = "global"
        series.resource.labels["project_id"] = project_id

        now = time.time()
        seconds = int(now)
        nanos = int((now - seconds) * 10**9)

        interval = monitoring_v3.TimeInterval(
            end_time={"seconds": seconds, "nanos": nanos}
        )
        point = monitoring_v3.Point(
            interval=interval,
            value=monitoring_v3.TypedValue(int64_value=1),
        )
        series.points = [point]

        client.create_time_series(
            request={"name": project_name, "time_series": [series]}
        )

        logger.info(
            f"📊 Custom metric sent to Cloud Monitoring: "
            f"{endpoint_name} is DOWN ({error_message})"
        )

    except Exception as e:
        logger.error(f"Failed to send Cloud Monitoring metric: {e}")


def send_recovery_alert(endpoint_name: str, endpoint_url: str):
    """
    Write a custom metric to Cloud Monitoring when an endpoint recovers.
    """
    try:
        app_env = os.environ.get("APP_ENV", "local")
        if app_env == "local":
            logger.info(f"[LOCAL] Would send RECOVERY alert for {endpoint_name}")
            return

        from google.cloud import monitoring_v3
        import time

        project_id = os.environ.get("PROJECT_ID", "")
        if not project_id:
            return

        client = monitoring_v3.MetricServiceClient()
        project_name = f"projects/{project_id}"

        series = monitoring_v3.TimeSeries()
        series.metric.type = "custom.googleapis.com/cloudpulse/endpoint_recovered"
        series.metric.labels["endpoint_name"] = endpoint_name[:64]
        series.metric.labels["endpoint_url"] = endpoint_url[:128]

        series.resource.type = "global"
        series.resource.labels["project_id"] = project_id

        now = time.time()
        seconds = int(now)
        nanos = int((now - seconds) * 10**9)

        interval = monitoring_v3.TimeInterval(
            end_time={"seconds": seconds, "nanos": nanos}
        )
        point = monitoring_v3.Point(
            interval=interval,
            value=monitoring_v3.TypedValue(int64_value=1),
        )
        series.points = [point]

        client.create_time_series(
            request={"name": project_name, "time_series": [series]}
        )

        logger.info(
            f"📊 Custom metric sent to Cloud Monitoring: "
            f"{endpoint_name} RECOVERED"
        )

    except Exception as e:
        logger.error(f"Failed to send Cloud Monitoring recovery metric: {e}")
