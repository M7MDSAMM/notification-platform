# Notification Platform

Enterprise-grade microservices platform for managing multi-channel notifications — SMS, Email, Push, and In-App — with centralized administration, template management, and delivery tracking.

## System Overview

The Notification Platform is built on a **microservices architecture** where each domain concern is isolated into its own independent Laravel application. Services communicate via REST APIs and share no database or runtime state, enabling independent deployment, scaling, and development.

### Architecture Principles

- **Service Isolation**: Each microservice is a standalone Laravel project with its own database, configuration, and dependencies.
- **API-First**: All inter-service communication happens over HTTP/JSON APIs. No shared code or database coupling.
- **Database-per-Service**: Each service owns its data via a dedicated MySQL database, ensuring loose coupling and independent schema evolution.
- **Independent Deployability**: Any service can be updated, restarted, or scaled without affecting others.

## Microservices

| Service | Port | Database | Responsibility |
|---|---|---|---|
| **Admin Dashboard** | 8000 | `np_admin_dashboard` | Central management UI, system configuration, reporting |
| **User Service** | 8001 | `np_user_service` | User registration, authentication, roles, permissions |
| **Notification Service** | 8002 | `np_notification_service` | Notification dispatch, routing, delivery tracking, scheduling |
| **Messaging Service** | 8003 | `np_messaging_service` | Channel integrations (SMS, Email, Push), provider abstraction |
| **Template Service** | 8004 | `np_template_service` | Notification templates, variable substitution, versioning |

## Folder Structure

```
notification-platform/
│
├── services/
│   ├── admin-dashboard/          Laravel 12 — Port 8000
│   ├── user-service/             Laravel 12 — Port 8001
│   ├── notification-service/     Laravel 12 — Port 8002
│   ├── messaging-service/        Laravel 12 — Port 8003
│   └── template-service/         Laravel 12 — Port 8004
│
├── docs/
│   ├── architecture.md           System architecture documentation
│   ├── api-contracts.md          API endpoint contracts between services
│   ├── database-design.md        Database schema design per service
│   └── diagrams/                 Architecture and flow diagrams
│
├── postman/
│   └── Notification-Platform.postman_collection.json
│
├── scripts/
│   ├── start-all.sh              Start all services
│   └── stop-all.sh               Stop all services
│
└── README.md
```

## Prerequisites

- **PHP** >= 8.2
- **Composer** >= 2.x
- **MySQL** >= 8.0 (via XAMPP or standalone)
- **Node.js** >= 18.x (for frontend assets, when needed)

## Quick Start

### 1. Create MySQL Databases

Connect to MySQL and create one database per service:

```sql
CREATE DATABASE np_admin_dashboard CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE np_user_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE np_notification_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE np_messaging_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE np_template_service CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 2. Run Migrations

```bash
cd services/admin-dashboard && php artisan migrate && cd ../..
cd services/user-service && php artisan migrate && cd ../..
cd services/notification-service && php artisan migrate && cd ../..
cd services/messaging-service && php artisan migrate && cd ../..
cd services/template-service && php artisan migrate && cd ../..
```

### 3. Start All Services

```bash
./scripts/start-all.sh
```

### 4. Stop All Services

```bash
./scripts/stop-all.sh
```

### 5. Access Services

| Service | URL |
|---|---|
| Admin Dashboard | http://127.0.0.1:8000 |
| User Service | http://127.0.0.1:8001 |
| Notification Service | http://127.0.0.1:8002 |
| Messaging Service | http://127.0.0.1:8003 |
| Template Service | http://127.0.0.1:8004 |

## Database Architecture

Each microservice operates with its own dedicated MySQL database, following the **database-per-service** pattern:

```
MySQL Server (127.0.0.1:3306)
├── np_admin_dashboard        → Admin Dashboard service
├── np_user_service           → User Service
├── np_notification_service   → Notification Service
├── np_messaging_service      → Messaging Service
└── np_template_service       → Template Service
```

**Why database-per-service?**

- **Loose coupling**: Services cannot directly query another service's data. They must use APIs.
- **Independent evolution**: Each service can modify its schema without coordinating with others.
- **Technology flexibility**: A service could switch to a different database engine if needed.
- **Fault isolation**: A database issue in one service does not cascade to others.

## Environment Configuration

Each service has its own `.env` file with:
- Unique `APP_NAME` and `APP_PORT`
- Dedicated `DB_DATABASE` name
- Unique `CACHE_PREFIX` to avoid key collisions
- Independent `APP_KEY` for encryption isolation

## Future Roadmap

### Log Service (Planned)

A dedicated **Log Service** will be introduced to provide:

- Centralized log aggregation across all microservices
- Structured logging with correlation IDs for request tracing
- Log levels: emergency, alert, critical, error, warning, notice, info, debug
- Dashboard integration for real-time log monitoring
- Log retention policies and archival
- Audit trail for security-sensitive operations

Target port: **8005**
Target database: `np_log_service`

## Development Guidelines

- Each service is developed and tested independently.
- Use API contracts (see `docs/api-contracts.md`) when building inter-service communication.
- Run `php artisan test` within each service directory for service-level testing.
- Never share Eloquent models or database connections between services.

## License

Proprietary. All rights reserved.
