# Database Ownership

Each service in the Notification Platform owns its own dedicated MySQL database. There is no shared database, no cross-service JOINs, and no direct access to another service's tables. When one service needs data from another, it calls that service's REST API.

---

## Why Database-Per-Service

- **Independence**: Each service can evolve its schema without coordinating with others.
- **Isolation**: A migration failure in one service doesn't affect others.
- **Clarity**: Looking at a service's database tells you exactly what it owns.
- **Security**: Services can't accidentally (or intentionally) read/write another service's data.

---

## Database Inventory

| Database | Service | Port |
|----------|---------|------|
| `np_user_service` | User Service | 8001 |
| `np_template_service` | Template Service | 8004 |
| `np_notification_service` | Notification Service | 8002 |
| `np_messaging_service` | Messaging Service | 8003 |
| `np_admin_dashboard` | Admin Dashboard | 8000 |

### Creation Script

```sql
CREATE DATABASE IF NOT EXISTS np_user_service
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS np_template_service
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS np_notification_service
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS np_messaging_service
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS np_admin_dashboard
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

---

## Table Inventory by Service

### User Service (`np_user_service`)

| Table | Type | Description |
|-------|------|-------------|
| `admins` | Domain | Admin accounts: name, email, password (hashed), role (super_admin / admin), is_active, uuid |
| `users` | Domain | Recipient users: name, email, phone, is_active, uuid, soft deletes |
| `user_preferences` | Domain | Per-user notification channel toggles (email, sms, push) and quiet hours |
| `user_devices` | Domain | Push notification device tokens with platform info |
| `cache` | Infra | Laravel cache store |
| `sessions` | Infra | Laravel sessions |

### Template Service (`np_template_service`)

| Table | Type | Description |
|-------|------|-------------|
| `templates` | Domain | Template definitions: key (unique, alpha_dash), name, channel (email/whatsapp/push), subject, body, variables_schema (JSON), version, is_active, soft deletes |
| `jobs` | Infra | Laravel queue jobs |

### Notification Service (`np_notification_service`)

| Table | Type | Description |
|-------|------|-------------|
| `notifications` | Domain | Notification records: user_uuid, template_key, channels (JSON), variables (JSON), status (queued/sent/failed), idempotency_key, delivery_references (JSON), soft deletes |
| `idempotency_keys` | Domain | Deduplication: user_uuid + idempotency_key (unique composite), request_hash, notification_uuid |
| `notification_attempts` | Domain | Per-channel attempt tracking: notification_uuid, channel, status, provider, provider_message_id, error_message |
| `cache` | Infra | Laravel cache (used for rate limiting) |
| `jobs` | Infra | Laravel queue jobs |

### Messaging Service (`np_messaging_service`)

| Table | Type | Description |
|-------|------|-------------|
| `deliveries` | Domain | Delivery records: notification_uuid, user_uuid, channel (email/whatsapp/push), recipient, subject, content, payload (JSON), status (pending/processing/sent/failed), attempts_count, max_attempts, soft deletes |
| `delivery_attempts` | Domain | Attempt records: delivery_uuid, attempt_number, provider, status, error_message, provider_message_id |
| `cache` | Infra | Laravel cache |
| `jobs` | Infra | Laravel queue jobs |

### Admin Dashboard (`np_admin_dashboard`)

| Table | Type | Description |
|-------|------|-------------|
| `sessions` | Infra | Laravel sessions (stores admin JWT + profile) |
| `cache` | Infra | Laravel cache |

The Admin Dashboard has **no domain tables**. All business data is owned by backend services and accessed via REST APIs.

---

## Cross-Service References

Services reference entities in other services by **UUID only**. Examples:

| This Service | Stores | References |
|--------------|--------|------------|
| Notification Service | `notifications.user_uuid` | User in User Service |
| Notification Service | `notifications.template_key` | Template in Template Service |
| Messaging Service | `deliveries.notification_uuid` | Notification in Notification Service |
| Messaging Service | `deliveries.user_uuid` | User in User Service |

These are **logical references**, not foreign keys. There are no database-level constraints across service boundaries.

---

## Design Principles

1. **UUIDs for external references**: Cross-service references use UUIDs, never auto-increment IDs.
2. **Auto-increment for internal use**: Each table has a `BIGINT` primary key for efficient indexing, but it's hidden from API responses.
3. **JSON columns for flexibility**: Fields like `channels`, `variables`, `payload`, and `variables_schema` use JSON for schema-free extensibility.
4. **Soft deletes**: Business-critical entities (users, notifications, templates, deliveries) use `deleted_at` for audit trail.
5. **Domain vs infra tables**: Each service has infrastructure tables (cache, jobs, sessions) managed by Laravel, separate from domain tables that hold business data.
