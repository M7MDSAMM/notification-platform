# API Contracts

This document defines the REST API contracts between microservices in the Notification Platform. All endpoints follow JSON:API conventions with consistent error handling.

## Conventions

- **Base URL**: `http://127.0.0.1:{port}/api`
- **Content-Type**: `application/json`
- **Authentication**: Bearer token (to be implemented)
- **Versioning**: URI-based (`/api/v1/...`) when multiple versions are needed

### Standard Response Format

**Success:**
```json
{
    "success": true,
    "data": { },
    "message": "Operation completed successfully"
}
```

**Error:**
```json
{
    "success": false,
    "message": "Validation failed",
    "errors": {
        "field": ["Error message"]
    }
}
```

### Standard HTTP Status Codes

| Code | Usage |
|---|---|
| 200 | Successful GET/PUT/PATCH |
| 201 | Successful POST (resource created) |
| 204 | Successful DELETE (no content) |
| 400 | Bad request / validation error |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Resource not found |
| 422 | Unprocessable entity |
| 429 | Rate limit exceeded |
| 500 | Internal server error |

---

## User Service (Port 8001)

### Users

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/users` | List all users (paginated) |
| POST | `/api/users` | Create a new user |
| GET | `/api/users/{id}` | Get user by ID |
| PUT | `/api/users/{id}` | Update user |
| DELETE | `/api/users/{id}` | Delete user |
| GET | `/api/users/{id}/preferences` | Get user notification preferences |
| PUT | `/api/users/{id}/preferences` | Update user notification preferences |

### Authentication

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/auth/login` | Authenticate and receive token |
| POST | `/api/auth/logout` | Revoke current token |
| GET | `/api/auth/me` | Get authenticated user profile |

---

## Notification Service (Port 8002)

### Notifications

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/notifications` | List notifications (paginated, filterable) |
| POST | `/api/notifications` | Create and dispatch a notification |
| GET | `/api/notifications/{id}` | Get notification details with delivery status |
| DELETE | `/api/notifications/{id}` | Cancel a pending notification |
| GET | `/api/notifications/{id}/status` | Get delivery status breakdown by channel |

### Scheduling

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/notifications/schedule` | Schedule a notification for future delivery |
| GET | `/api/notifications/scheduled` | List scheduled notifications |
| DELETE | `/api/notifications/scheduled/{id}` | Cancel a scheduled notification |

---

## Messaging Service (Port 8003)

### Messages

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/messages/send` | Send a message via specified channel |
| GET | `/api/messages/{id}/status` | Get message delivery status |
| GET | `/api/messages/channels` | List available channels and their status |

### Webhooks (Inbound)

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/webhooks/delivery-status` | Receive delivery status from providers |
| POST | `/api/webhooks/bounce` | Receive bounce notifications |

---

## Template Service (Port 8004)

### Templates

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/templates` | List all templates (paginated) |
| POST | `/api/templates` | Create a new template |
| GET | `/api/templates/{id}` | Get template by ID |
| PUT | `/api/templates/{id}` | Update template |
| DELETE | `/api/templates/{id}` | Delete template |
| POST | `/api/templates/{id}/render` | Render template with variables |
| GET | `/api/templates/{id}/versions` | List template version history |

---

## Inter-Service Communication Map

```
Admin Dashboard (8000)
  ├── → User Service (8001)          [User CRUD, Auth]
  ├── → Notification Service (8002)  [Notification management]
  ├── → Messaging Service (8003)     [Channel monitoring]
  └── → Template Service (8004)      [Template management]

Notification Service (8002)
  ├── → User Service (8001)          [Resolve recipients]
  ├── → Template Service (8004)      [Render templates]
  └── → Messaging Service (8003)     [Dispatch messages]

Messaging Service (8003)
  └── → Notification Service (8002)  [Report delivery status]
```
