# API Response Standard

All microservices in the Notification Platform return responses using a standardized JSON envelope. Dashboard clients enforce strict parsing of this envelope.

---

## Success Response

```json
{
  "success": true,
  "message": "Human-readable success message",
  "data": { "..." },
  "meta": {},
  "correlation_id": "9f1d5e1e-1e3d-4d2b-8b39-4c6a0b5f5f1a"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `success` | `bool` | Yes | Always `true` for success responses |
| `message` | `string` | Yes | Human-readable message (may be empty) |
| `data` | `object\|array\|null` | Yes | Response payload |
| `meta` | `object` | Yes | Always present; empty `{}` when no metadata |
| `correlation_id` | `string` | Yes | UUID for distributed tracing |

### Pagination

List endpoints include pagination metadata in `meta.pagination`:

```json
{
  "success": true,
  "message": "",
  "data": [{ "..." }, { "..." }],
  "meta": {
    "pagination": {
      "current_page": 1,
      "per_page": 15,
      "total": 42,
      "last_page": 3
    }
  },
  "correlation_id": "..."
}
```

---

## Error Response

```json
{
  "success": false,
  "message": "Human-readable error message",
  "errors": {},
  "error_code": "VALIDATION_ERROR",
  "correlation_id": "9f1d5e1e-1e3d-4d2b-8b39-4c6a0b5f5f1a",
  "meta": {}
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `success` | `bool` | Yes | Always `false` for error responses |
| `message` | `string` | Yes | Human-readable error description |
| `errors` | `object` | Yes | Field-level errors; empty `{}` when not applicable |
| `error_code` | `string` | Yes | Machine-readable error identifier |
| `correlation_id` | `string` | Yes | UUID for distributed tracing |
| `meta` | `object` | Yes | Always present; empty `{}` |

---

## Error Codes

| Code | HTTP Status | Description |
|---|---|---|
| `VALIDATION_ERROR` | 422 | Request payload failed validation |
| `AUTH_INVALID` | 401 | Missing or invalid authentication |
| `TOKEN_EXPIRED` | 401 | JWT token has expired |
| `FORBIDDEN` | 403 | Authenticated but insufficient permissions |
| `NOT_FOUND` | 404 | Requested resource does not exist |
| `USER_NOT_FOUND` | 404 | User UUID not found |
| `TEMPLATE_NOT_FOUND` | 404 | Template key not found |
| `CONFLICT` | 409 | Resource conflict (e.g., duplicate key) |
| `IDEMPOTENCY_CONFLICT` | 409 | Duplicate idempotency key |
| `RATE_LIMIT_EXCEEDED` | 429 | Rate limit exceeded |
| `EXTERNAL_SERVICE_ERROR` | 502 | Downstream service call failed |
| `DELIVERY_FAILED` | 502 | Message delivery to provider failed |
| `SERVER_ERROR` | 500 | Unhandled server error |

---

## Examples

### Validation Error (422)

```json
{
  "success": false,
  "message": "Validation failed.",
  "errors": {
    "email": ["The email field is required."],
    "name": ["The name must be at least 2 characters."]
  },
  "error_code": "VALIDATION_ERROR",
  "correlation_id": "...",
  "meta": {}
}
```

### Unauthorized (401)

```json
{
  "success": false,
  "message": "Unauthorized.",
  "errors": {},
  "error_code": "AUTH_INVALID",
  "correlation_id": "...",
  "meta": {}
}
```

### Not Found (404)

```json
{
  "success": false,
  "message": "Resource not found.",
  "errors": {},
  "error_code": "NOT_FOUND",
  "correlation_id": "...",
  "meta": {}
}
```

### Created (201)

```json
{
  "success": true,
  "message": "Resource created.",
  "data": {
    "uuid": "abc-123",
    "name": "New Resource"
  },
  "meta": {},
  "correlation_id": "..."
}
```

---

## Dashboard Client Parsing Rules

Admin Dashboard service clients enforce strict envelope parsing:

1. **Do NOT trust HTTP status codes alone** — a 200 response with `"success": false` is treated as an error.
2. **Check `success` field first** — only extract `data` when `success === true`.
3. **On `success: false`** — throw `ExternalServiceException` with `message`, `error_code`, `correlation_id`, and HTTP status from the response.
4. **On 401/403** — throw `UnauthorizedRemoteException` to trigger session invalidation or forbidden handling.
5. **Always forward `X-Correlation-Id`** — include in outbound requests and extract from responses.

---

## Implementation

Each API service uses `App\Http\Responses\ApiResponse` as the single response helper. Exception handlers in `bootstrap/app.php` catch all standard exceptions and render them through this helper to guarantee envelope consistency.
