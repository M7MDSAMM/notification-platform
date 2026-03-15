# Services Overview

A quick reference for each service in the Notification Platform: what it does, what it owns, and its key endpoints.

---

## User Service (Port 8001)

**Purpose:** Single source of truth for identity. Issues JWTs, manages admins and recipient users.

**Inputs:** Admin credentials, user data, preferences, device tokens.
**Outputs:** JWT tokens, admin profiles, user records, preference settings.

### Owned Tables (`np_user_service`)

| Table | Description |
|-------|-------------|
| `admins` | Admin accounts with roles (super_admin, admin) |
| `users` | Recipient users (name, email, phone, is_active) |
| `user_preferences` | Per-user channel toggles and quiet hours |
| `user_devices` | Push notification device tokens |

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/admin/auth/login` | Admin login → JWT |
| `GET` | `/api/v1/admin/me` | Authenticated admin profile |
| `GET/POST/PUT` | `/api/v1/admins` | Admin CRUD (super_admin only) |
| `GET/POST/PUT/DELETE` | `/api/v1/users` | Recipient user CRUD |
| `GET/PUT` | `/api/v1/users/{uuid}/preferences` | User notification preferences |
| `GET/POST/DELETE` | `/api/v1/users/{uuid}/devices` | Device token management |

### Important Classes

- `Rs256JwtTokenService` — issues and validates RS256 JWTs
- `AdminAuthController` — handles login
- `AdminController` — admin CRUD
- `UserController` — recipient user CRUD
- `UserPreferencesController` — preference management
- `UserDeviceController` — device token management

---

## Template Service (Port 8004)

**Purpose:** Manage notification templates and render them with variable substitution.

**Inputs:** Template definitions, rendering requests with variables.
**Outputs:** Template records, rendered content (subject + body).

### Owned Tables (`np_template_service`)

| Table | Description |
|-------|-------------|
| `templates` | Template definitions (key, name, channel, subject, body, variables_schema, version) |

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET/POST` | `/api/v1/templates` | List / create templates (super_admin) |
| `GET/PUT/DELETE` | `/api/v1/templates/{key}` | Get / update / delete template |
| `POST` | `/api/v1/templates/{key}/render` | Render template with variables |

### Important Classes

- `TemplateController` — CRUD operations
- `TemplateRenderController` — rendering endpoint
- `TemplateRenderService` — variable substitution logic

---

## Notification Service (Port 8002)

**Purpose:** Orchestrate notification creation by coordinating user validation, template rendering, and message dispatch across services.

**Inputs:** Notification requests (user_uuid, template_key, channels, variables).
**Outputs:** Notification records with delivery status and attempt tracking.

### Owned Tables (`np_notification_service`)

| Table | Description |
|-------|-------------|
| `notifications` | Core notification records with status tracking |
| `idempotency_keys` | Deduplication records for idempotent creation |
| `notification_attempts` | Per-channel attempt records with provider details |

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/notifications` | List notifications (filterable) |
| `POST` | `/api/v1/notifications` | Create notification (triggers orchestration) |
| `GET` | `/api/v1/notifications/{uuid}` | Get notification with attempts |
| `POST` | `/api/v1/notifications/{uuid}/retry` | Retry failed notification |

### Important Classes

- `NotificationController` — API endpoints
- `NotificationOrchestratorService` — full orchestration pipeline
- `UserServiceClient` — calls User Service for validation/preferences
- `TemplateServiceClient` — calls Template Service for rendering
- `MessagingServiceClient` — calls Messaging Service for dispatch
- `MakesHttpRequests` — shared HTTP trait for all clients

---

## Messaging Service (Port 8003)

**Purpose:** Handle actual message delivery through channel-specific providers.

**Inputs:** Delivery requests with channel, recipient, and content.
**Outputs:** Delivery records with attempt tracking and provider message IDs.

### Owned Tables (`np_messaging_service`)

| Table | Description |
|-------|-------------|
| `deliveries` | Delivery records (channel, recipient, status, attempts) |
| `delivery_attempts` | Individual attempt records with provider response |

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/deliveries` | Create delivery batch |
| `GET` | `/api/v1/deliveries/{uuid}` | Get delivery with attempts |
| `POST` | `/api/v1/deliveries/{uuid}/retry` | Retry failed delivery |

### Important Classes

- `DeliveryController` — API endpoints
- `DeliveryService` — delivery creation and retry logic
- `EmailProvider` — email delivery via Laravel Mail
- `WhatsappProvider` — WhatsApp delivery (stub)
- `PushProvider` — push notification delivery (stub)
- `DispatchDeliveryJob` — async queue job for delivery execution

---

## Admin Dashboard (Port 8000)

**Purpose:** Web UI for platform administration. Orchestrates all backend services through their REST APIs.

**Inputs:** Admin interactions via browser.
**Outputs:** Server-rendered HTML pages, proxied API calls to backend services.

### Owned Tables (`np_admin_dashboard`)

This service stores only session and cache data. All business data is owned by backend services.

### Key Routes

| Route | Description |
|-------|-------------|
| `GET/POST /login` | Admin authentication |
| `GET /` | Dashboard home |
| `GET /admins` | Admin management (super_admin) |
| `GET /users` | User management |
| `GET /notifications` | Notification management |
| `GET /templates` | Template management (super_admin) |

### Important Classes

- `LoginController` — admin authentication via User Service
- `AdminController` — admin management UI
- `UserController` — user management UI
- `NotificationController` — notification management UI
- `TemplateController` — template management UI
- `UserServiceClient` — HTTP client for User Service
- `NotificationServiceClient` — HTTP client for Notification Service
- `MessagingServiceClient` — HTTP client for Messaging Service
- `TemplateManagementService` — HTTP client for Template Service
