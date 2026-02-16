# System Architecture

## Overview

The Notification Platform follows a **microservices architecture** pattern where the system is decomposed into small, independently deployable services organized around business capabilities.

## Architecture Diagram

```
                    ┌──────────────────────┐
                    │   Admin Dashboard    │
                    │     (Port 8000)      │
                    └──────────┬───────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
   ┌──────────────────┐ ┌───────────────┐ ┌──────────────────┐
   │  User Service    │ │  Notification │ │ Template Service │
   │   (Port 8001)   │ │   Service     │ │   (Port 8004)    │
   └──────────────────┘ │ (Port 8002)   │ └──────────────────┘
                        └───────┬───────┘
                                │
                                ▼
                     ┌──────────────────┐
                     │ Messaging Service│
                     │   (Port 8003)    │
                     └──────────────────┘
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
               ┌────────┐ ┌────────┐ ┌──────────┐
               │  SMS   │ │ Email  │ │   Push   │
               │Provider│ │Provider│ │ Provider │
               └────────┘ └────────┘ └──────────┘
```

## Service Responsibilities

### Admin Dashboard (Port 8000)
- Central management interface
- System-wide configuration and settings
- Reporting and analytics dashboard
- Service health monitoring
- Role-based access to platform features

### User Service (Port 8001)
- User registration and profile management
- Authentication (API tokens, sessions)
- Role and permission management
- User preferences (notification channels, quiet hours)
- API key management for external integrations

### Notification Service (Port 8002)
- Notification creation and dispatch orchestration
- Delivery scheduling (immediate, delayed, recurring)
- Delivery status tracking and retry logic
- Notification history and audit log
- Priority and rate limiting

### Messaging Service (Port 8003)
- Channel provider abstraction (SMS, Email, Push, In-App)
- Provider failover and load balancing
- Message formatting per channel
- Delivery confirmation and bounce handling
- Provider credential management

### Template Service (Port 8004)
- Template CRUD with version control
- Variable substitution engine
- Multi-language template support
- Template preview and validation
- Template categories and tagging

## Communication Patterns

### Synchronous (REST API)
- Admin Dashboard → User Service (user management)
- Admin Dashboard → Template Service (template management)
- Notification Service → Template Service (template rendering)
- Notification Service → User Service (recipient resolution)
- Notification Service → Messaging Service (message dispatch)

### Request Flow Example

```
1. Admin creates notification via Dashboard
2. Dashboard → Notification Service: POST /api/notifications
3. Notification Service → User Service: GET /api/users/{id}/preferences
4. Notification Service → Template Service: POST /api/templates/{id}/render
5. Notification Service → Messaging Service: POST /api/messages/send
6. Messaging Service → External Provider (SMS/Email/Push)
7. Messaging Service → Notification Service: Webhook delivery status
```

## Data Isolation

Each service maintains its own:
- MySQL database (prefixed with `np_`)
- Laravel migrations and seeders
- Eloquent models
- Cache namespace (via `CACHE_PREFIX`)
- Session storage
- Queue workers

## Security Considerations

- Inter-service authentication via API tokens (to be implemented)
- CORS configuration per service
- Rate limiting on all public API endpoints
- Input validation at service boundaries
- Encrypted sensitive configuration via `.env`
