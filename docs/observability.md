# Observability & Logging

## Correlation ID flow
- Dashboard and User Service accept `X-Correlation-Id` on every request; if absent, a UUID is generated in `CorrelationIdMiddleware`.
- The correlation ID is shared into the logging context and echoed back on responses.
- Outbound calls from the dashboard to the user-service forward the same correlation ID so logs can be stitched across services.

## Log format
- Structured JSON (Monolog `JsonFormatter`) written to `storage/logs/app.log`.
- Common fields:
  - `service` – logical service name (`admin-dashboard` or `user-service`)
  - `correlation_id`
  - `method`, `route` (path)
  - `status_code`
  - `latency_ms`
  - `actor` – `admin_uuid` when available

## Inbound request logs
Emitted by `RequestTimingMiddleware` at the end of every request.
```json
{
  "message": "request.completed",
  "service": "user-service",
  "method": "GET",
  "route": "api/v1/users",
  "status_code": 200,
  "latency_ms": 12.5,
  "correlation_id": "9f1d5e1e-1e3d-4d2b-8b39-4c6a0b5f5f1a",
  "actor": "admin-uuid"
}
```

## Outbound HTTP logs (dashboard → user-service)
Emitted by `UserServiceClient` around every HTTP call.
```json
{
  "message": "http.outbound.user_service",
  "service": "admin-dashboard",
  "endpoint": "admins",
  "method": "GET",
  "status_code": 200,
  "latency_ms": 42.7,
  "correlation_id": "9f1d5e1e-1e3d-4d2b-8b39-4c6a0b5f5f1a"
}
```

## Health endpoint enrichment
- `/api/v1/health` (user-service) and `/health` (admin-dashboard) return `status`, `service`, `timestamp/time`, and `version` (from `APP_VERSION` env or git SHA).
