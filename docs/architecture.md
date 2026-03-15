# Architecture

## Services & Ports

| Service | Type | Port | Database | Primary Responsibilities |
|---------|------|------|----------|-------------------------|
| Admin Dashboard | Laravel web app (Blade + Tailwind) | 8000 | `np_admin_dashboard` | Admin UI, session auth, orchestration via REST |
| User Service | Laravel API (stateless JSON) | 8001 | `np_user_service` | Admin auth (JWT), admin CRUD, recipient users, preferences, devices |
| Notification Service | Laravel API + queue workers | 8002 | `np_notification_service` | Notification orchestration, idempotency, rate limiting, status tracking |
| Messaging Service | Laravel API + queue workers | 8003 | `np_messaging_service` | Channel provider abstraction, delivery dispatch, attempt tracking |
| Template Service | Laravel API | 8004 | `np_template_service` | Template CRUD, versioning, variable-based rendering |

---

## Auth Model

- **Admin authentication** is issued by **User Service** (`POST /api/v1/admin/auth/login`). Returns an RS256-signed JWT with role claims (`admin` or `super_admin`).
- Admin Dashboard stores the JWT server-side in the session and caches the admin profile from `GET /api/v1/admin/me`. The browser only holds a session cookie.
- All API services validate the JWT using the User Service's public key via `JwtAdminAuthMiddleware`.
- Recipient users are managed entities with no authentication flow — they are created and managed by admins.

See [auth.md](auth.md) for the full auth deep-dive.

---

## Data Ownership

- Each service owns its database schema. No cross-service DB access.
- Admins and recipient users live in **User Service**.
- Admin Dashboard stores only session/cache data — no business entities.
- Cross-service data is accessed exclusively via REST APIs.

See [database-ownership.md](database-ownership.md) for the full table inventory.

---

## Inter-Service Communication

All communication is synchronous REST over HTTP/JSON. Every request carries:
- `Authorization: Bearer <JWT>` — forwarded from the original admin request
- `X-Correlation-Id` — for distributed tracing across service boundaries

```
Admin Dashboard (8000)
  ├──► User Service (8001)           [Auth, users, preferences, devices]
  ├──► Notification Service (8002)   [Create/view notifications, retry]
  ├──► Messaging Service (8003)      [View delivery status]
  └──► Template Service (8004)       [Manage templates]

Notification Service (8002)
  ├──► User Service (8001)           [Validate user, fetch preferences]
  ├──► Template Service (8004)       [Render template]
  └──► Messaging Service (8003)      [Dispatch deliveries]
```

**User Service** and **Template Service** are leaf services — they do not call other internal services.

---

## Diagrams

### System Context

```mermaid
graph LR
    Admin[Admin User] -->|HTTPS / Session cookie| AD[Admin Dashboard :8000]
    AD -->|REST + Bearer JWT| US[User Service :8001]
    AD -->|REST + Bearer JWT| NS[Notification Service :8002]
    AD -->|REST + Bearer JWT| TS[Template Service :8004]
    AD -->|REST + Bearer JWT| MS[Messaging Service :8003]
    NS -->|REST + Bearer JWT| US
    NS -->|REST + Bearer JWT| TS
    NS -->|REST + Bearer JWT| MS
    MS --> Ext[External Providers\nEmail / WhatsApp / Push]
```

### Sequence: Admin Login

```mermaid
sequenceDiagram
    actor Admin
    participant AD as Admin Dashboard (:8000)
    participant US as User Service (:8001)
    Admin->>AD: GET /login
    AD-->>Admin: Render login form
    Admin->>AD: POST /login (email, password)
    AD->>US: POST /api/v1/admin/auth/login
    US-->>AD: 200 {access_token, expires_in}
    AD->>US: GET /api/v1/admin/me (Bearer token)
    US-->>AD: 200 {admin profile}
    AD-->>Admin: Redirect / (session stores JWT + profile)
```

### Sequence: Create Notification (Orchestration)

```mermaid
sequenceDiagram
    actor Admin
    participant NS as Notification Service (:8002)
    participant US as User Service (:8001)
    participant TS as Template Service (:8004)
    participant MS as Messaging Service (:8003)

    Admin->>NS: POST /api/v1/notifications
    NS->>NS: Check idempotency key
    NS->>US: GET /users/{uuid} (validate active)
    US-->>NS: 200 User data
    NS->>US: GET /users/{uuid}/preferences
    US-->>NS: 200 Channel preferences
    NS->>NS: Rate limit check (5/min/user)
    NS->>TS: POST /templates/{key}/render
    TS-->>NS: 200 Rendered content
    NS->>NS: Create notification + attempts
    NS->>MS: POST /deliveries (batch)
    MS-->>NS: 201 Delivery references
    NS->>NS: Update status → sent
    NS-->>Admin: 201 Notification created
```

### Sequence: Message Delivery

```mermaid
sequenceDiagram
    participant NS as Notification Service
    participant MS as Messaging Service (:8003)
    participant Q as Queue Worker
    participant P as Provider (Email/Push/WhatsApp)

    NS->>MS: POST /api/v1/deliveries
    MS->>MS: Create Delivery records
    MS->>Q: Dispatch DispatchDeliveryJob (per channel)
    Q->>P: Send message
    P-->>Q: Success / Failure
    Q->>MS: Create DeliveryAttempt, update Delivery status
    MS-->>NS: 201 Delivery references
```

### Component Diagram

```mermaid
graph TD
    subgraph Admin Dashboard :8000
        UI[Blade Views / Controllers]
        Session[Session Auth<br/>stores admin JWT]
        DashClients[Service Clients<br/>User / Notification / Template / Messaging]
    end

    subgraph User Service :8001
        USCtrl[Controllers]
        USSvc[Services]
        USDB[(MySQL<br/>np_user_service)]
        USCtrl --> USSvc --> USDB
    end

    subgraph Notification Service :8002
        NSCtrl[NotificationController]
        Orch[OrchestratorService]
        NSClients[Clients<br/>User / Template / Messaging]
        NSDB[(MySQL<br/>np_notification_service)]
        NSCtrl --> Orch --> NSClients
        Orch --> NSDB
    end

    subgraph Template Service :8004
        TSCtrl[Controllers]
        TSSvc[RenderService]
        TSDB[(MySQL<br/>np_template_service)]
        TSCtrl --> TSSvc --> TSDB
    end

    subgraph Messaging Service :8003
        MSCtrl[DeliveryController]
        MSSvc[DeliveryService]
        MSProv[Providers<br/>Email / WhatsApp / Push]
        MSDB[(MySQL<br/>np_messaging_service)]
        MSCtrl --> MSSvc --> MSProv
        MSSvc --> MSDB
    end

    DashClients -->|REST| USCtrl
    DashClients -->|REST| NSCtrl
    DashClients -->|REST| TSCtrl
    DashClients -->|REST| MSCtrl
    NSClients -->|REST| USCtrl
    NSClients -->|REST| TSCtrl
    NSClients -->|REST| MSCtrl
```
