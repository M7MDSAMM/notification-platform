# Observability & Logging

This document describes the cross-cutting observability infrastructure shared by all five services in the Notification Platform.

---

## Correlation ID Flow

Every service includes a `CorrelationIdMiddleware`:

1. If the inbound request carries an `X-Correlation-Id` header, it is reused.
2. Otherwise, a new UUID v4 is generated.
3. The ID is shared into Monolog's context via `Log::shareContext()`, so **every** log line within that request automatically includes it.
4. The ID is echoed back on the response via `X-Correlation-Id` header.
5. Outbound HTTP calls forward the same ID, enabling end-to-end trace stitching across services.

---

## Structured Logging

All services use Monolog's `JsonFormatter` via a `structured` logging channel, producing machine-parseable JSON logs at `storage/logs/laravel.json`.

### Common Fields (injected by `AddCommonContext` tap)

| Field | Source | Example |
|---|---|---|
| `service` | `SERVICE_NAME` env / `app.name` config | `"notification-service"` |
| `correlation_id` | `X-Correlation-Id` header (via `Log::shareContext`) | `"9f1d5e1e-..."` |

### Channel Configuration

```php
// config/logging.php
'structured' => [
    'driver'    => 'single',
    'path'      => storage_path('logs/laravel.json'),
    'level'     => env('LOG_LEVEL', 'debug'),
    'tap'       => [App\Logging\AddCommonContext::class],
    'formatter' => Monolog\Formatter\JsonFormatter::class,
],
```

The `structured` channel is included in the default `stack` channel alongside `single`.

---

## Inbound Request Logging

`RequestTimingMiddleware` runs on every request across all services. It emits a `request.completed` log entry after the response is generated:

```json
{
  "message": "request.completed",
  "context": {
    "method": "GET",
    "url": "http://localhost:8001/api/v1/users",
    "status_code": 200,
    "latency_ms": 12.5,
    "ip": "127.0.0.1",
    "user_agent": "GuzzleHttp/7",
    "correlation_id": "9f1d5e1e-1e3d-4d2b-8b39-4c6a0b5f5f1a"
  },
  "extra": {
    "service": "user-service"
  }
}
```

---

## Outbound HTTP Logging

Services that make outbound HTTP calls log latency and status for each call.

### Admin Dashboard → All Backend Services

Each service client (`UserServiceClient`, `NotificationServiceClient`, `TemplateServiceClient`, `MessagingServiceClient`) wraps calls in `timedRequest()`:

```json
{
  "message": "http.outbound.user_service",
  "context": {
    "service": "admin-dashboard",
    "endpoint": "admins",
    "method": "GET",
    "status_code": 200,
    "latency_ms": 42.7,
    "correlation_id": "9f1d5e1e-..."
  }
}
```

### Notification Service → User / Template / Messaging Services

The `MakesHttpRequests` trait provides shared `timedRequest()` logging:

```json
{
  "message": "http.outbound",
  "context": {
    "endpoint": "users/abc-123",
    "method": "GET",
    "status_code": 200,
    "latency_ms": 15.3,
    "correlation_id": "9f1d5e1e-..."
  }
}
```

---

## Health Endpoints

Every service exposes a `GET /health` (or `GET /api/v1/health`) endpoint returning an enriched JSON envelope:

```json
{
  "success": true,
  "data": {
    "service": "notification-service",
    "status": "healthy",
    "timestamp": "2026-03-15T12:00:00+00:00",
    "version": "1.0.0",
    "environment": "local",
    "queue_connection": "database"
  },
  "correlation_id": "9f1d5e1e-..."
}
```

| Field | Description |
|---|---|
| `service` | Logical service name |
| `status` | Always `"healthy"` if responding |
| `timestamp` | ISO 8601 server time |
| `version` | From `config('app.version')` or `APP_VERSION` env |
| `environment` | From `app()->environment()` |
| `queue_connection` | Queue driver in use (only on services with queues) |

### Service Health URLs

| Service | URL |
|---|---|
| Admin Dashboard | `http://localhost:8000/health` |
| User Service | `http://localhost:8001/api/v1/health` |
| Notification Service | `http://localhost:8002/api/v1/health` |
| Messaging Service | `http://localhost:8003/api/v1/health` |
| Template Service | `http://localhost:8004/api/v1/health` |

---

## Middleware Stack (per service)

All services register the following global middleware in `bootstrap/app.php`:

1. `CorrelationIdMiddleware` — generates/forwards correlation ID, shares into log context
2. `RequestTimingMiddleware` — measures and logs request latency

---

## Adding Observability to a New Service

1. Copy `CorrelationIdMiddleware` and `RequestTimingMiddleware` from any existing service.
2. Create `app/Logging/AddCommonContext.php` with the service name.
3. Add the `structured` channel to `config/logging.php`.
4. Register both middleware in `bootstrap/app.php`.
5. Add an enriched `/health` endpoint.
6. Forward `X-Correlation-Id` on all outbound HTTP calls.
