# Database Design

## Overview

The Notification Platform follows the **database-per-service** pattern. Each microservice has its own dedicated MySQL database, ensuring complete data isolation and independent schema evolution.

## Database Inventory

| Database | Service | Port |
|---|---|---|
| `np_admin_dashboard` | Admin Dashboard | 8000 |
| `np_user_service` | User Service | 8001 |
| `np_notification_service` | Notification Service | 8002 |
| `np_messaging_service` | Messaging Service | 8003 |
| `np_template_service` | Template Service | 8004 |

## Database Creation Script

```sql
-- Run this in MySQL to create all databases
CREATE DATABASE IF NOT EXISTS np_admin_dashboard
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS np_user_service
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS np_notification_service
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS np_messaging_service
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS np_template_service
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

---

## Schema Design (Per Service)

### np_admin_dashboard

```
settings
├── id (BIGINT, PK)
├── key (VARCHAR 255, UNIQUE)
├── value (TEXT)
├── group (VARCHAR 100, INDEX)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

audit_logs
├── id (BIGINT, PK)
├── admin_user_id (BIGINT, INDEX)
├── action (VARCHAR 100)
├── resource_type (VARCHAR 100)
├── resource_id (BIGINT)
├── old_values (JSON, NULLABLE)
├── new_values (JSON, NULLABLE)
├── ip_address (VARCHAR 45)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

### np_user_service

```
users
├── id (BIGINT, PK)
├── uuid (CHAR 36, UNIQUE)
├── name (VARCHAR 255)
├── email (VARCHAR 255, UNIQUE)
├── phone (VARCHAR 20, NULLABLE, INDEX)
├── password (VARCHAR 255)
├── email_verified_at (TIMESTAMP, NULLABLE)
├── is_active (BOOLEAN, DEFAULT true)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

user_preferences
├── id (BIGINT, PK)
├── user_id (BIGINT, FK → users.id)
├── channel (ENUM: email, sms, push, in_app)
├── enabled (BOOLEAN, DEFAULT true)
├── quiet_hours_start (TIME, NULLABLE)
├── quiet_hours_end (TIME, NULLABLE)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

roles
├── id (BIGINT, PK)
├── name (VARCHAR 100, UNIQUE)
├── guard_name (VARCHAR 100)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

permissions
├── id (BIGINT, PK)
├── name (VARCHAR 100, UNIQUE)
├── guard_name (VARCHAR 100)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

### np_notification_service

```
notifications
├── id (BIGINT, PK)
├── uuid (CHAR 36, UNIQUE)
├── user_id (BIGINT, INDEX)
├── template_id (BIGINT, NULLABLE, INDEX)
├── type (VARCHAR 100, INDEX)
├── channel (ENUM: email, sms, push, in_app)
├── subject (VARCHAR 255, NULLABLE)
├── body (TEXT)
├── priority (ENUM: low, normal, high, critical, DEFAULT normal)
├── status (ENUM: pending, queued, sent, delivered, failed, INDEX)
├── scheduled_at (TIMESTAMP, NULLABLE, INDEX)
├── sent_at (TIMESTAMP, NULLABLE)
├── delivered_at (TIMESTAMP, NULLABLE)
├── failed_at (TIMESTAMP, NULLABLE)
├── failure_reason (TEXT, NULLABLE)
├── metadata (JSON, NULLABLE)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

notification_logs
├── id (BIGINT, PK)
├── notification_id (BIGINT, FK → notifications.id)
├── event (VARCHAR 100)
├── payload (JSON, NULLABLE)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

### np_messaging_service

```
messages
├── id (BIGINT, PK)
├── uuid (CHAR 36, UNIQUE)
├── notification_id (BIGINT, INDEX)
├── channel (ENUM: email, sms, push, in_app)
├── provider (VARCHAR 100, INDEX)
├── recipient (VARCHAR 255)
├── subject (VARCHAR 255, NULLABLE)
├── body (TEXT)
├── status (ENUM: pending, sent, delivered, bounced, failed, INDEX)
├── provider_message_id (VARCHAR 255, NULLABLE, INDEX)
├── attempts (INT, DEFAULT 0)
├── last_attempt_at (TIMESTAMP, NULLABLE)
├── delivered_at (TIMESTAMP, NULLABLE)
├── metadata (JSON, NULLABLE)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

channel_providers
├── id (BIGINT, PK)
├── channel (ENUM: email, sms, push)
├── name (VARCHAR 100)
├── driver (VARCHAR 100)
├── is_active (BOOLEAN, DEFAULT true)
├── is_default (BOOLEAN, DEFAULT false)
├── priority (INT, DEFAULT 0)
├── configuration (JSON)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

### np_template_service

```
templates
├── id (BIGINT, PK)
├── uuid (CHAR 36, UNIQUE)
├── name (VARCHAR 255)
├── slug (VARCHAR 255, UNIQUE)
├── channel (ENUM: email, sms, push, in_app)
├── subject (VARCHAR 255, NULLABLE)
├── body (TEXT)
├── variables (JSON, NULLABLE)
├── category (VARCHAR 100, NULLABLE, INDEX)
├── is_active (BOOLEAN, DEFAULT true)
├── version (INT, DEFAULT 1)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)

template_versions
├── id (BIGINT, PK)
├── template_id (BIGINT, FK → templates.id)
├── version (INT)
├── subject (VARCHAR 255, NULLABLE)
├── body (TEXT)
├── variables (JSON, NULLABLE)
├── change_notes (TEXT, NULLABLE)
├── created_by (BIGINT, NULLABLE)
├── created_at (TIMESTAMP)
└── updated_at (TIMESTAMP)
```

---

## Design Principles

1. **UUIDs for external references**: Services reference entities in other services by UUID, never by auto-increment ID.
2. **JSON columns for flexibility**: Metadata and configuration use JSON columns for schema-free extensibility.
3. **Soft deletes considered**: Business-critical tables should use `deleted_at` columns when data retention is required.
4. **Indexing strategy**: Columns used in WHERE, JOIN, and ORDER BY clauses are indexed.
5. **Timestamp consistency**: All tables use `created_at` and `updated_at` with UTC timezone.
