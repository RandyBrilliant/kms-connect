"""
Minimal views for backend (e.g. health check for Docker/load balancer).
"""
from django.http import JsonResponse
from django.db import connection
from django.core.cache import cache


def health(request):
    """
    Health check endpoint for Docker healthcheck and load balancers.
    Checks: app, DB (read), optional Redis cache.
    Returns 200 with status and optional details; 503 if DB or required cache fails.
    """
    result = {"status": "ok"}
    checks = {}
    failed = False

    # Database
    try:
        connection.ensure_connection()
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        checks["database"] = "ok"
    except Exception as e:
        checks["database"] = str(e)
        failed = True

    # Cache (Redis when CELERY_BROKER_URL is redis) – optional; don't fail if cache is down
    try:
        cache.set("health_check_ping", 1, 5)
        if cache.get("health_check_ping") == 1:
            checks["cache"] = "ok"
        else:
            checks["cache"] = "miss"
    except Exception as e:
        checks["cache"] = str(e)

    result["checks"] = checks
    if failed:
        result["status"] = "degraded"
        return JsonResponse(result, status=503)
    return JsonResponse(result, status=200)
