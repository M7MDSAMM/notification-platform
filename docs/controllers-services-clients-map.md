# Controllers, Services & Clients Map

A reference showing how the key classes in each service relate to each other — who calls whom.

---

## User Service

```
Controllers
├── AdminAuthController        → JwtTokenServiceInterface (issues JWT)
├── AdminController            → AdminServiceInterface (CRUD)
├── UserController             → UserServiceInterface (CRUD)
├── UserPreferencesController  → UserPreferencesServiceInterface
└── UserDeviceController       → UserDeviceServiceInterface

Services
├── Rs256JwtTokenService       → config/jwt.php, openssl
├── AdminService               → Admin model
├── UserService                → User model
├── UserPreferencesService     → UserPreference model
└── UserDeviceService          → UserDevice model

Middleware
├── CorrelationIdMiddleware    → generates/forwards X-Correlation-Id
├── RequestTimingMiddleware    → logs request latency
├── JwtAdminAuthMiddleware     → validates Bearer JWT
└── RequireSuperAdminMiddleware → checks role === super_admin

Requests (Form Requests)
├── AdminLoginRequest
├── StoreAdminRequest
├── UpdateAdminRequest
├── StoreUserRequest
├── UpdateUserRequest
├── UpdatePreferencesRequest
└── RegisterDeviceRequest
```

---

## Template Service

```
Controllers
├── TemplateController         → Template model (direct Eloquent)
└── TemplateRenderController   → TemplateRenderServiceInterface

Services
└── TemplateRenderService      → Template model, variable substitution

Middleware
├── CorrelationIdMiddleware
├── RequestTimingMiddleware
├── JwtAdminAuthMiddleware
└── RequireSuperAdminMiddleware

Requests
├── StoreTemplateRequest
├── UpdateTemplateRequest
└── RenderTemplateRequest
```

---

## Notification Service

```
Controllers
└── NotificationController     → NotificationOrchestratorInterface (store)
                               → NotificationServiceInterface (index, show, retry)

Services
├── NotificationOrchestratorService
│   ├── → UserServiceClientInterface      (validate user, fetch preferences)
│   ├── → TemplateServiceClientInterface  (render template)
│   ├── → MessagingServiceClientInterface (dispatch deliveries)
│   ├── → Notification model              (create, update status)
│   ├── → IdempotencyKey model            (check/store)
│   └── → NotificationAttempt model       (create per channel)
└── NotificationService                   (index, show, retry)

Clients (all use MakesHttpRequests trait)
├── UserServiceClient          → User Service API (:8001)
├── TemplateServiceClient      → Template Service API (:8004)
└── MessagingServiceClient     → Messaging Service API (:8003)

Middleware
├── CorrelationIdMiddleware
├── RequestTimingMiddleware
└── JwtAdminAuthMiddleware

Requests
└── NotificationCreateRequest

Exceptions
└── ExternalServiceException   → wraps downstream service errors
```

---

## Messaging Service

```
Controllers
└── DeliveryController         → DeliveryServiceInterface

Services
├── DeliveryService            → Delivery model, DispatchDeliveryJob
├── EmailProvider              → Laravel Mail (Mail::raw)
├── WhatsappProvider           → stub (simulated)
└── PushProvider               → stub (simulated)

Jobs
└── DispatchDeliveryJob        → selects provider by channel, creates DeliveryAttempt

Middleware
├── CorrelationIdMiddleware
├── RequestTimingMiddleware
└── JwtAdminAuthMiddleware

Requests
└── DeliveryCreateRequest
```

---

## Admin Dashboard

```
Controllers
├── LoginController            → UserServiceClient (auth)
├── AdminController            → UserServiceClient (admin CRUD)
├── UserController             → UserServiceClient (user CRUD, prefs, devices)
├── NotificationController     → NotificationServiceClientInterface
└── TemplateController         → TemplateManagementServiceInterface

Service Clients
├── UserServiceClient                  → User Service API (:8001)
├── NotificationServiceClient          → Notification Service API (:8002)
├── MessagingServiceClient             → Messaging Service API (:8003)
└── TemplateManagementService          → Template Service API (:8004)

Middleware
├── CorrelationIdMiddleware
├── RequestTimingMiddleware
├── RequireAdminSessionMiddleware       → checks session has valid JWT
├── RequireSuperAdminMiddleware         → checks session role
└── HandleUnauthorizedRemoteMiddleware  → handles 401/403 from User Service

Exceptions
├── ExternalServiceException     → wraps downstream errors
└── UnauthorizedRemoteException  → 401/403 from backend services
```

---

## Call Flow Summary

```
Browser
  └── Admin Dashboard Controllers
        ├── UserServiceClient ──────────► User Service Controllers
        │                                   └── Services → Models → DB
        ├── NotificationServiceClient ──► Notification Controller
        │                                   └── OrchestratorService
        │                                       ├── UserServiceClient ──► User Service
        │                                       ├── TemplateServiceClient ► Template Service
        │                                       └── MessagingServiceClient ► Messaging Service
        │                                                                     └── DeliveryService
        │                                                                         └── Providers
        ├── TemplateManagementService ──► Template Service Controllers
        │                                   └── Models → DB
        └── MessagingServiceClient ─────► Messaging Service Controllers
                                            └── DeliveryService → Models → DB
```
