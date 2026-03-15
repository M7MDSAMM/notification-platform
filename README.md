# Notification Platform

A microservices-based platform for managing multi-channel notifications (email, WhatsApp, push) with centralized administration, template management, and delivery tracking. Built with Laravel 12 and PHP 8.2.

---

## Key Features

- **Multi-channel delivery** — email, WhatsApp, push notifications through pluggable providers
- **Template engine** — versioned templates with variable substitution and per-channel rendering
- **Notification orchestration** — validates users, checks preferences, renders templates, dispatches deliveries in a single pipeline
- **Idempotency protection** — duplicate notification requests are detected and deduplicated
- **Rate limiting** — per-user throttling to prevent notification spam
- **Admin dashboard** — server-rendered UI for managing users, templates, notifications, and deliveries
- **RS256 JWT auth** — centralized admin authentication with role-based access control
- **Distributed tracing** — `X-Correlation-Id` propagated across all service boundaries
- **Structured logging** — JSON logs with request timing, latency, and actor context

---

## Architecture

Five independent Laravel services, each with its own database, communicating exclusively via REST APIs:

| Service | Port | Type | Purpose |
|---------|------|------|---------|
| [Admin Dashboard](services/admin-dashboard/) | 8000 | Web app (Blade + Tailwind) | Operational console for admins |
| [User Service](services/user-service/) | 8001 | JSON API | Identity provider, admin auth, user/preference/device management |
| [Notification Service](services/notification-service/) | 8002 | JSON API | Orchestrates notification creation and delivery |
| [Messaging Service](services/messaging-service/) | 8003 | JSON API + queue | Channel-specific message delivery and attempt tracking |
| [Template Service](services/template-service/) | 8004 | JSON API | Template CRUD, versioning, and rendering |

```
Admin Dashboard (:8000)
  ├──► User Service (:8001)
  ├──► Notification Service (:8002)
  ├──► Messaging Service (:8003)
  └──► Template Service (:8004)

Notification Service (:8002)
  ├──► User Service (:8001)         validate user + preferences
  ├──► Template Service (:8004)     render content
  └──► Messaging Service (:8003)    dispatch deliveries
```

---

## Quick Start

### Prerequisites

- PHP >= 8.2, Composer >= 2.x, MySQL >= 8.0
- Node.js >= 18.x (admin-dashboard frontend only)

### Setup

```bash
# Clone with submodules
git clone --recurse-submodules <repo-url>
cd notification-platform

# Create databases
mysql -u root -e "
  CREATE DATABASE IF NOT EXISTS np_user_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE DATABASE IF NOT EXISTS np_template_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE DATABASE IF NOT EXISTS np_notification_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE DATABASE IF NOT EXISTS np_messaging_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE DATABASE IF NOT EXISTS np_admin_dashboard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
"

# Install dependencies and configure each service
for svc in user-service template-service notification-service messaging-service admin-dashboard; do
  (cd services/$svc && composer install && cp .env.example .env && php artisan key:generate)
done

# Generate JWT keys (User Service)
cd services/user-service && php artisan jwt:generate-keys && cd ../..

# Run migrations
for svc in user-service template-service notification-service messaging-service admin-dashboard; do
  (cd services/$svc && php artisan migrate)
done

# Build dashboard frontend
cd services/admin-dashboard && npm install && npm run build && cd ../..
```

### Start Services

```bash
./scripts/start-all.sh

# Or individually:
cd services/user-service && php artisan serve --port=8001 &
cd services/template-service && php artisan serve --port=8004 &
cd services/notification-service && php artisan serve --port=8002 &
cd services/messaging-service && php artisan serve --port=8003 &
cd services/admin-dashboard && php artisan serve --port=8000 &
```

### Verify

```bash
curl http://localhost:8001/api/v1/health
curl http://localhost:8002/api/v1/health
curl http://localhost:8003/api/v1/health
curl http://localhost:8004/api/v1/health
curl http://localhost:8000/health
```

### Stop Services

```bash
./scripts/stop-all.sh
```

---

## Testing

Each service has its own test suite running against MySQL (except admin-dashboard which uses SQLite in-memory).

```bash
# Run all tests
for svc in user-service template-service notification-service messaging-service admin-dashboard; do
  echo "=== $svc ===" && (cd services/$svc && php artisan test)
done
```

| Service | Tests | Assertions |
|---------|-------|------------|
| user-service | 56 | 465 |
| template-service | 22 | 179 |
| notification-service | 17 | 117 |
| messaging-service | 13 | 94 |
| admin-dashboard | 42 | 135 |
| **Total** | **150** | **990** |

See [docs/testing.md](docs/testing.md) for test structure, helpers, and conventions.

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | Services, communication map, Mermaid diagrams |
| [Auth](docs/auth.md) | JWT auth flow, session management, key management |
| [API Response Standard](docs/api-response-standard.md) | Success/error envelopes, error codes, parsing rules |
| [API Contracts](docs/api-contracts.md) | All REST endpoints across services |
| [Request Flows](docs/request-flows.md) | Step-by-step flows: login, create notification, delivery |
| [Design Patterns](docs/design-patterns.md) | DI, Controller→Service→Client, interfaces, submodules |
| [Database Ownership](docs/database-ownership.md) | Per-service table inventory and cross-service references |
| [Testing](docs/testing.md) | Test helpers, structure, database config, writing tests |
| [Observability](docs/observability.md) | Correlation IDs, structured logging, request timing |
| [Git Workflow](docs/git-workflow.md) | Submodule workflow, branching, commit conventions |
| [Services Overview](docs/services-overview.md) | Per-service summary: purpose, tables, endpoints, classes |
| [Controllers/Services/Clients Map](docs/controllers-services-clients-map.md) | Class relationship map across all services |

---

## Git Submodule Workflow

Each service is an independent git repository tracked as a submodule:

```bash
# After making changes in a service repo
cd services/notification-service
git add -A && git commit -m "feat(notification): add feature"
git push

# Update root repo pointer
cd ~/lampp/htdocs/notification-platform
git add services/notification-service
git commit -m "chore(submodules): bump notification-service"
git push
```

See [docs/git-workflow.md](docs/git-workflow.md) for the full workflow.

---

## Project Structure

```
notification-platform/
├── services/
│   ├── admin-dashboard/          Laravel 12 — Port 8000 (submodule)
│   ├── user-service/             Laravel 12 — Port 8001 (submodule)
│   ├── notification-service/     Laravel 12 — Port 8002 (submodule)
│   ├── messaging-service/        Laravel 12 — Port 8003 (submodule)
│   └── template-service/         Laravel 12 — Port 8004 (submodule)
├── docs/                         System documentation
├── scripts/                      Start/stop scripts
├── postman/                      Postman collection
└── README.md
```

---

## License

Proprietary. All rights reserved.
