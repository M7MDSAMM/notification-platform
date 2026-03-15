# Design Patterns

This document explains the key design patterns used in the Notification Platform and why they exist. Written for developers who want to understand the reasoning behind the code structure.

---

## Service Container & Dependency Injection

Every service in this project uses Laravel's **service container** — a registry that knows how to create objects. Instead of creating dependencies directly with `new`, we tell Laravel "when someone needs interface X, give them class Y."

### How it works

In `AppServiceProvider.php`:

```php
$this->app->bind(UserServiceClientInterface::class, UserServiceClient::class);
```

Then in a controller:

```php
public function __construct(
    private readonly UserServiceClientInterface $userClient,
) {}
```

Laravel automatically creates a `UserServiceClient` and passes it in. The controller never knows (or cares) which concrete class it receives.

### Why this matters

1. **Testing**: In tests, we swap the real client for a fake: `$this->app->instance(UserServiceClientInterface::class, $fake)`. The controller code doesn't change.
2. **Flexibility**: If we switch from Guzzle to a different HTTP client, we only change the binding — not every file that uses it.
3. **Clarity**: Reading a constructor tells you exactly what a class depends on.

---

## Controller → Service → Client

The codebase follows a strict layering pattern:

```
Controller  →  Service  →  Client  →  External API / Database
   (thin)      (logic)    (HTTP)
```

### Controllers are thin

Controllers only do three things:
1. Accept and validate the request.
2. Call a service method.
3. Return a response.

```php
// NotificationController::store()
public function store(NotificationCreateRequest $request): JsonResponse
{
    $result = $this->orchestrator->createNotification($request->validated());
    return ApiResponse::created($result, 'Notification created.');
}
```

No business logic lives in controllers. No database queries. No HTTP calls.

### Services contain business logic

Services orchestrate the actual work:

```php
// NotificationOrchestratorService::createNotification()
// 1. Check idempotency
// 2. Validate user via UserServiceClient
// 3. Fetch preferences via UserServiceClient
// 4. Rate limit check
// 5. Render template via TemplateServiceClient
// 6. Create notification in database
// 7. Dispatch to MessagingServiceClient
```

### Clients handle HTTP communication

Clients encapsulate all the details of calling another service:
- Building the URL
- Forwarding the Bearer token
- Forwarding the correlation ID
- Parsing the response envelope
- Throwing typed exceptions on failure
- Logging latency

```php
// UserServiceClient::fetchUser()
public function fetchUser(string $token, string $uuid): array
{
    $response = $this->timedRequest(
        fn () => $this->authenticatedRequest($token)->get("users/{$uuid}"),
        "users/{$uuid}", 'GET'
    );
    return $this->extractData($response, 'Failed to fetch user');
}
```

### Why this separation

- **Controllers** stay small and testable without complex setup.
- **Services** can be tested by mocking only the clients (no HTTP needed).
- **Clients** can be tested against real or fake HTTP servers.
- Each layer has a single, clear responsibility.

---

## Interface-First Design

Every service client and business service has an interface:

```
app/Clients/Contracts/UserServiceClientInterface.php
app/Clients/UserServiceClient.php

app/Services/Contracts/NotificationOrchestratorInterface.php
app/Services/Implementations/NotificationOrchestratorService.php
```

This is not ceremony for its own sake. Each interface enables:
1. Swapping implementations in tests (fakes, mocks).
2. Binding in the service container.
3. Clear contracts that document what a dependency provides.

---

## Standardized API Envelope

Every API response across all services uses the same structure:

```json
{
  "success": true,
  "message": "...",
  "data": {},
  "meta": {},
  "correlation_id": "..."
}
```

This is enforced by a shared `ApiResponse` helper class in each service. Exception handlers in `bootstrap/app.php` catch all exceptions and render them through `ApiResponse` — so even unhandled errors return a consistent envelope.

### Why a shared envelope

- Dashboard clients can parse any service response with the same logic.
- The `success` field is the source of truth — not the HTTP status code.
- The `correlation_id` field enables distributed tracing without extra effort.

---

## Exception Boundaries

Try/catch blocks exist only at **system boundaries** — not scattered throughout the code:

1. **Exception handler** (`bootstrap/app.php`) — catches all unhandled exceptions and renders them as API error envelopes.
2. **Service clients** — catch HTTP errors and throw typed `ExternalServiceException` with context.
3. **Controllers** — occasionally catch specific exceptions to return custom error responses.

Internal code (models, services, helpers) throws exceptions freely and lets them propagate up. This keeps the code clean and avoids defensive programming.

---

## MakesHttpRequests Trait

The Notification Service's three clients (User, Template, Messaging) share HTTP logic via a trait instead of an abstract class:

```php
trait MakesHttpRequests
{
    private function request(): PendingRequest { /* base HTTP client */ }
    private function authenticatedRequest(string $token): PendingRequest { /* + Bearer */ }
    private function timedRequest(Closure $callback, string $endpoint, string $method): Response { /* + logging */ }
    private function extractData(Response $response, string $fallbackMessage): array { /* parse envelope */ }
}
```

This avoids inheritance hierarchies while sharing: token forwarding, correlation ID propagation, latency logging, and envelope parsing.

---

## Git Submodules

Each service is an independent Git repository. The root repository tracks them as submodules:

```
notification-platform/          ← root repo
├── services/
│   ├── admin-dashboard/        ← submodule (own repo)
│   ├── user-service/           ← submodule (own repo)
│   ├── notification-service/   ← submodule (own repo)
│   ├── messaging-service/      ← submodule (own repo)
│   └── template-service/       ← submodule (own repo)
└── docs/                       ← in root repo
```

### Why submodules

- Each service can be deployed, versioned, and tested independently.
- The root repo provides a single clone point and tracks which service versions work together.
- CI/CD can target individual services without rebuilding everything.
- Matches the microservices principle: each service is its own deployable unit.

### The trade-off

Submodules add complexity to the git workflow (pointer updates, branch management). The `docs/git-workflow.md` document covers the exact process.
