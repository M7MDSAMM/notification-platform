# API Contracts

REST API contracts between microservices in the Notification Platform. All endpoints return standardized JSON envelopes (see [api-response-standard.md](api-response-standard.md)).

---

## Conventions

- **Base URL**: `http://localhost:{port}/api/v1`
- **Content-Type**: `application/json`
- **Authentication**: RS256 JWT Bearer token (issued by User Service)
- **Tracing**: `X-Correlation-Id` header on all requests/responses
- **Identifiers**: UUIDs in all route parameters and response payloads

---

## User Service (Port 8001)

### Admin Authentication

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/admin/auth/login` | Public | Authenticate admin, returns JWT |
| `GET` | `/api/v1/admin/me` | Admin | Get authenticated admin profile |

### Admin Management

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/admins` | Super Admin | List admins (paginated) |
| `POST` | `/api/v1/admins` | Super Admin | Create admin |
| `GET` | `/api/v1/admins/{uuid}` | Super Admin | Get admin by UUID |
| `PUT` | `/api/v1/admins/{uuid}` | Super Admin | Update admin |
| `PATCH` | `/api/v1/admins/{uuid}/toggle-active` | Super Admin | Toggle admin active status |

### Recipient Users

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/users` | Admin | List users (paginated, filterable) |
| `POST` | `/api/v1/users` | Admin | Create user |
| `GET` | `/api/v1/users/{uuid}` | Admin | Get user by UUID |
| `PUT` | `/api/v1/users/{uuid}` | Admin | Update user |
| `DELETE` | `/api/v1/users/{uuid}` | Admin | Soft-delete user |

### Preferences & Devices

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/users/{uuid}/preferences` | Admin | Get notification preferences |
| `PUT` | `/api/v1/users/{uuid}/preferences` | Admin | Update notification preferences |
| `GET` | `/api/v1/users/{uuid}/devices` | Admin | List device tokens |
| `POST` | `/api/v1/users/{uuid}/devices` | Admin | Register device token |
| `DELETE` | `/api/v1/users/{uuid}/devices/{deviceUuid}` | Admin | Delete device token |

---

## Template Service (Port 8004)

### Templates

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/templates` | Super Admin | List templates (filterable by key, channel, is_active) |
| `POST` | `/api/v1/templates` | Super Admin | Create template |
| `GET` | `/api/v1/templates/{key}` | Super Admin | Get template by key |
| `PUT` | `/api/v1/templates/{key}` | Super Admin | Update template (auto-increments version) |
| `DELETE` | `/api/v1/templates/{key}` | Super Admin | Soft-delete template |

### Rendering

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/templates/{key}/render` | Admin | Render template with variables |

---

## Notification Service (Port 8002)

### Notifications

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/notifications` | Admin | List notifications (filterable by status, user_uuid, template_key) |
| `POST` | `/api/v1/notifications` | Admin | Create and orchestrate notification |
| `GET` | `/api/v1/notifications/{uuid}` | Admin | Get notification with attempts |
| `POST` | `/api/v1/notifications/{uuid}/retry` | Admin | Retry failed notification |

### Create Notification Request Body

```json
{
  "user_uuid": "string (required, uuid)",
  "template_key": "string (required, max:120)",
  "channels": ["email", "push"],
  "variables": { "name": "Alex" },
  "idempotency_key": "string (optional, max:100)"
}
```

---

## Messaging Service (Port 8003)

### Deliveries

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/deliveries` | Admin | Create delivery batch |
| `GET` | `/api/v1/deliveries/{uuid}` | Admin | Get delivery with attempts |
| `POST` | `/api/v1/deliveries/{uuid}/retry` | Admin | Retry failed delivery |

### Create Deliveries Request Body

```json
{
  "notification_uuid": "string (required, uuid)",
  "user_uuid": "string (required, uuid)",
  "deliveries": [
    {
      "channel": "email|whatsapp|push",
      "recipient": "string (optional)",
      "subject": "string (optional)",
      "content": "string (optional)",
      "payload": {}
    }
  ]
}
```

---

## Health Endpoints (All Services)

| Service | URL |
|---------|-----|
| Admin Dashboard | `GET http://localhost:8000/health` |
| User Service | `GET http://localhost:8001/api/v1/health` |
| Notification Service | `GET http://localhost:8002/api/v1/health` |
| Messaging Service | `GET http://localhost:8003/api/v1/health` |
| Template Service | `GET http://localhost:8004/api/v1/health` |

---

## Inter-Service Communication Map

```
Admin Dashboard (8000)
  ├──► User Service (8001)           [Auth, admin/user CRUD, preferences, devices]
  ├──► Notification Service (8002)   [Notification CRUD, retry]
  ├──► Messaging Service (8003)      [Delivery tracking]
  └──► Template Service (8004)       [Template CRUD, render preview]

Notification Service (8002)
  ├──► User Service (8001)           [Validate user, fetch preferences]
  ├──► Template Service (8004)       [Render template]
  └──► Messaging Service (8003)      [Dispatch deliveries]
```

User Service and Template Service are **leaf services** — they do not call other internal services.
