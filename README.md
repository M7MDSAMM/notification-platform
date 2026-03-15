# Notification Platform

Enterprise-grade microservices platform for managing multi-channel notifications (SMS, Email, Push, In-App) with centralized administration, user management, template management, and delivery tracking.

---

## Architecture Overview

The platform is decomposed into **5 independent Laravel services**, each running as its own process on a dedicated port with a dedicated MySQL database. Services communicate exclusively via REST APIs (Guzzle HTTP client). There is no shared state, no shared database, and no shared code between services.

### Core Principles

- **Service isolation** — Each microservice is a standalone Laravel 12 project with its own database, config, dependencies, and deployment lifecycle.
- **API-first** — All inter-service communication is synchronous REST over HTTP/JSON. No direct DB access across service boundaries.
- **Database-per-service** — Each service owns a dedicated MySQL schema. Cross-service data is fetched via API calls, never via JOINs.
- **UUID public identifiers** — All API routes and responses use UUIDs. Internal database tables use `BIGINT` auto-increment primary keys. Numeric IDs never appear in URLs or API payloads.
- **Soft deletes** — Main entities (users, notifications, messages, templates) use `deleted_at` columns for auditability.

---

## Roles and Access Model

There are **two distinct identity types** in the system. They are separate concepts with separate auth flows.

### A) Admins (Dashboard Users)

| Attribute | Detail |
|---|---|
| **Auth location** | Admin Dashboard service (`np_admin_dashboard` DB) |
| **Capabilities** | Full management access via the dashboard |
| **Roles/Permissions** | Yes — role-based access control (e.g., super-admin, operator, viewer) |
| **Token type** | Session-based (web) or Sanctum token for dashboard API calls |

Admins can:
- Log in to the Admin Dashboard
- View / search / manage users (via User Service API)
- Create, schedule, and send notifications (via Notification Service API)
- Manage notification templates (via Template Service API)
- View delivery statuses and analytics (via Notification + Messaging Service APIs)
- Manage other admins, roles, and permissions

### B) Users (Notification Recipients)

| Attribute | Detail |
|---|---|
| **Auth location** | User Service (`np_user_service` DB) |
| **Capabilities** | Self-service only |
| **Roles/Permissions** | **None** — users have no roles or permissions |
| **Token type** | Sanctum API token |

Users can:
- Register a new account
- Log in and receive an API token
- View and update their own profile
- Manage their notification preferences (channels, quiet hours)
- Register device tokens (for push notifications)

Users **cannot** access any admin functionality, manage other users, or interact with notification/template/messaging services directly.

---

## Service Responsibilities

### Admin Dashboard — Port 8000

> **Type:** Laravel web application + internal API consumer
> **Database:** `np_admin_dashboard`

- Admin authentication (login, logout, session management)
- Admin CRUD with role/permission assignment
- Dashboard views: users list, notification history, delivery stats, templates
- All data is fetched from backend services via REST — this service stores only admin accounts and platform settings
- Makes outbound HTTP calls to: User Service, Notification Service, Messaging Service, Template Service

### User Service — Port 8001

> **Type:** Laravel API (stateless, JSON)
> **Database:** `np_user_service`

- User registration and login (Sanctum token auth)
- User profile CRUD (name, email, phone)
- Notification preferences per user (email on/off, SMS on/off, push on/off, quiet hours)
- Device token management (FCM tokens, APNs tokens)
- Exposes internal API endpoints consumed by Admin Dashboard and Notification Service
- **Does not** implement roles or permissions — users are flat entities

### Notification Service — Port 8002

> **Type:** Laravel API (stateless, JSON) + queue workers
> **Database:** `np_notification_service`

- Notification creation and dispatch orchestration
- Resolves recipients by calling User Service
- Renders templates by calling Template Service
- Dispatches messages by calling Messaging Service
- Scheduling (immediate, delayed, recurring)
- Delivery status tracking, retry logic
- Notification history and audit log

### Messaging Service — Port 8003

> **Type:** Laravel API (stateless, JSON) + queue workers
> **Database:** `np_messaging_service`

- Channel provider abstraction layer (SMS, Email, Push, In-App)
- Accepts dispatch requests from Notification Service
- Routes messages to the correct provider (Mailgun, Twilio, FCM, etc.)
- Provider failover and retry
- Delivery confirmation, bounce handling
- Reports delivery status back to Notification Service

### Template Service — Port 8004

> **Type:** Laravel API (stateless, JSON)
> **Database:** `np_template_service`

- Template CRUD with version history
- Variable substitution engine (`{{name}}`, `{{code}}`, etc.)
- Template rendering endpoint (accepts variables, returns compiled output)
- Multi-channel templates (email subject+body, SMS body, push title+body)
- Template categories and tagging

---

## Inter-Service Communication Map

```
Admin Dashboard (8000)
  |---> User Service (8001)           [List/view users, preferences]
  |---> Notification Service (8002)   [Create notifications, view statuses]
  |---> Messaging Service (8003)      [View delivery stats, channel status]
  |---> Template Service (8004)       [Manage templates]

Notification Service (8002)
  |---> User Service (8001)           [Resolve recipients + preferences]
  |---> Template Service (8004)       [Render notification content]
  |---> Messaging Service (8003)      [Dispatch messages per channel]

Messaging Service (8003)
  |---> Notification Service (8002)   [Report delivery status via callback]
  |---> External Providers            [Mailgun, Twilio, FCM, APNs, etc.]
```

User Service and Template Service are **leaf services** — they do not make outbound calls to other internal services.

---

## Folder Structure

```
notification-platform/               <-- Main repo
|
|-- services/
|   |-- admin-dashboard/             Laravel 12 — Port 8000 (git submodule)
|   |-- user-service/                Laravel 12 — Port 8001 (git submodule)
|   |-- notification-service/        Laravel 12 — Port 8002 (git submodule)
|   |-- messaging-service/           Laravel 12 — Port 8003 (git submodule)
|   +-- template-service/            Laravel 12 — Port 8004 (git submodule)
|
|-- docs/
|   |-- architecture.md
|   |-- api-contracts.md
|   |-- database-design.md
|   +-- diagrams/
|
|-- postman/
|   +-- Notification-Platform.postman_collection.json
|
|-- scripts/
|   |-- start-all.sh
|   +-- stop-all.sh
|
+-- README.md
```

---

## Database Architecture

Each service owns a dedicated MySQL database on the same server. Services never share tables or run cross-database queries.

```
MySQL Server (127.0.0.1:3306)
|-- np_admin_dashboard        Admins, roles, permissions, settings
|-- np_user_service           Users (recipients), preferences, device tokens
|-- np_notification_service   Notifications, schedules, delivery logs
|-- np_messaging_service      Messages, channel providers, delivery records
+-- np_template_service       Templates, versions, categories
```

### Creation Script

```sql
CREATE DATABASE IF NOT EXISTS np_admin_dashboard    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS np_user_service       CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS np_notification_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS np_messaging_service  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS np_template_service   CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

## Service Ports

| Service | Port | Description |
| --- | --- | --- |
| Admin Dashboard | 8000 | Admin UI and orchestration layer |
| User Service | 8001 | Admin auth + recipient users API |
| Notification Service | 8002 | Notification orchestration & scheduling |
| Messaging Service | 8003 | Channel dispatch & provider abstraction |
| Template Service | 8004 | Template CRUD and rendering |

## Additional Documentation
- [Architecture](docs/architecture.md)
- [API Response Standard](docs/api-response-standard.md)
- [Observability & Logging](docs/observability.md)

---

## Local Setup

### Prerequisites

| Dependency | Version |
|---|---|
| PHP | >= 8.2 |
| Composer | >= 2.x |
| MySQL | >= 8.0 |
| Node.js | >= 18.x (admin-dashboard frontend only) |

### 1. Clone with Submodules

```bash
git clone --recurse-submodules <main-repo-url>
cd notification-platform
```

If already cloned without submodules:

```bash
git submodule update --init --recursive
```

### 2. Install Dependencies (per service)

```bash
for service in admin-dashboard user-service notification-service messaging-service template-service; do
    (cd services/$service && composer install && cp .env.example .env && php artisan key:generate)
done
```

### 3. Create Databases

Connect to MySQL and run:

```sql
CREATE DATABASE IF NOT EXISTS np_admin_dashboard    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS np_user_service       CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS np_notification_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS np_messaging_service  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS np_template_service   CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 4. Configure Environment

Edit each service's `.env` file if your MySQL credentials differ from defaults (`root` / no password).

### 5. Run Migrations

```bash
for service in admin-dashboard user-service notification-service messaging-service template-service; do
    (cd services/$service && php artisan migrate)
done
```

### 6. Start Services

**Option A — All at once:**

```bash
./scripts/start-all.sh
```

**Option B — Individually:**

```bash
cd services/admin-dashboard    && php artisan serve --port=8000 &
cd services/user-service       && php artisan serve --port=8001 &
cd services/notification-service && php artisan serve --port=8002 &
cd services/messaging-service  && php artisan serve --port=8003 &
cd services/template-service   && php artisan serve --port=8004 &
```

### 7. Start Queue Workers (required for async processing)

```bash
cd services/notification-service && php artisan queue:work --queue=default --tries=3 &
cd services/messaging-service    && php artisan queue:work --queue=default --tries=3 &
```

### 8. Verify Health

```bash
curl http://localhost:8000/health
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
curl http://localhost:8004/health
```

Each returns an enriched JSON envelope:

```json
{
    "success": true,
    "data": {
        "service": "user-service",
        "status": "healthy",
        "timestamp": "2026-03-15T12:00:00+00:00",
        "version": "1.0.0",
        "environment": "local"
    },
    "correlation_id": ""
}
```

### 9. Stop Services

```bash
./scripts/stop-all.sh
```

---

## Service Port Map

| Service | Port | Base URL | Health |
|---|---|---|---|
| Admin Dashboard | 8000 | `http://localhost:8000` | `GET /health` |
| User Service | 8001 | `http://localhost:8001/api/v1` | `GET /health` |
| Notification Service | 8002 | `http://localhost:8002/api/v1` | `GET /health` |
| Messaging Service | 8003 | `http://localhost:8003/api/v1` | `GET /health` |
| Template Service | 8004 | `http://localhost:8004/api/v1` | `GET /health` |

---

## Environment Variables Reference

### All Services (common)

| Variable | Description | Example |
|---|---|---|
| `APP_NAME` | Service display name | `"User Service"` |
| `APP_ENV` | Environment | `local` |
| `APP_KEY` | Encryption key (auto-generated) | `base64:...` |
| `APP_DEBUG` | Debug mode | `true` |
| `APP_URL` | Service base URL with port | `http://localhost:8001` |
| `DB_CONNECTION` | Database driver | `mysql` |
| `DB_HOST` | MySQL host | `127.0.0.1` |
| `DB_PORT` | MySQL port | `3306` |
| `DB_DATABASE` | Service-specific database name | `np_user_service` |
| `DB_USERNAME` | MySQL user | `root` |
| `DB_PASSWORD` | MySQL password | _(empty for local)_ |
| `QUEUE_CONNECTION` | Queue driver | `database` |
| `CACHE_PREFIX` | Unique cache key prefix | `user_service_` |

### Admin Dashboard (additional)

| Variable | Description | Default |
|---|---|---|
| `USER_SERVICE_URL` | User Service API base | `http://localhost:8001/api/v1` |
| `NOTIFICATION_SERVICE_URL` | Notification Service API base | `http://localhost:8002/api/v1` |
| `MESSAGING_SERVICE_URL` | Messaging Service API base | `http://localhost:8003/api/v1` |
| `TEMPLATE_SERVICE_URL` | Template Service API base | `http://localhost:8004/api/v1` |

### Notification Service (additional)

| Variable | Description | Default |
|---|---|---|
| `USER_SERVICE_URL` | User Service API base | `http://localhost:8001/api/v1` |
| `MESSAGING_SERVICE_URL` | Messaging Service API base | `http://localhost:8003/api/v1` |
| `TEMPLATE_SERVICE_URL` | Template Service API base | `http://localhost:8004/api/v1` |

### Messaging Service (additional)

| Variable | Description | Default |
|---|---|---|
| `NOTIFICATION_SERVICE_URL` | Notification Service API base | `http://localhost:8002/api/v1` |
| `SMS_PROVIDER` | SMS provider name | _(not set)_ |
| `SMS_API_KEY` | SMS provider API key | _(not set)_ |
| `PUSH_PROVIDER` | Push provider name | _(not set)_ |
| `FCM_SERVER_KEY` | Firebase Cloud Messaging key | _(not set)_ |

### User Service / Template Service

No additional inter-service environment variables required (leaf services).

---

## Development Guidelines

- Each service is developed, tested, and versioned independently.
- Never share Eloquent models, migrations, or database connections across services.
- Use `config('services.user_service.base_url')` to reference other service URLs — never hardcode.
- All API routes are versioned under `/api/v1/`.
- Use UUIDs in all API route parameters and response payloads. Never expose numeric IDs.
- Main entities must use soft deletes (`SoftDeletes` trait).
- Run `php artisan test` inside each service directory for isolated testing.
- See `docs/api-contracts.md` for inter-service endpoint specifications.

---

## Future Roadmap

### Log Service (Planned — Port 8005)

- Centralized log aggregation across all services
- Structured logging with correlation IDs for distributed tracing
- Real-time log monitoring in Admin Dashboard
- Audit trail for security-sensitive operations
- Database: `np_log_service`

---

## License

Proprietary. All rights reserved.
