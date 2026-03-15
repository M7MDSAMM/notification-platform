# Testing Guide

## Overview

Every service in the Notification Platform has feature tests that verify API contracts, authentication, authorization, validation, and business logic. Tests run against a real MySQL database (not SQLite) to match production behavior.

## Running Tests

```bash
# Run tests for a single service
cd services/user-service && php artisan test

# Run all services
for svc in user-service template-service notification-service messaging-service admin-dashboard; do
  echo "=== $svc ===" && cd services/$svc && php artisan test && cd ../..
done
```

## Test Structure

Each service follows this directory layout:

```
tests/
├── Feature/           # HTTP-level tests (routes, controllers, middleware)
├── Unit/              # Isolated unit tests (models, services, utilities)
├── Support/           # Shared test helpers (traits, fakes)
└── TestCase.php       # Base test case
```

## Shared Test Helpers

### `tests/Support/JwtHelper.php` (API services)

Provides JWT key generation and token creation for authenticating test requests:

- `setUpJwt()` — generates an RSA key pair and configures JWT settings
- `makeToken(string $role)` — creates a valid JWT with the given admin role
- `authHeaders(string $role)` — returns `Authorization: Bearer <token>` headers

### `tests/Support/AssertsApiEnvelope.php` (all services)

Provides standardized envelope assertion helpers:

- `assertApiSuccess($response, $status)` — asserts `success: true` and correct envelope structure
- `assertApiError($response, $status, $errorCode)` — asserts `success: false` and error envelope

### `tests/Support/SessionHelper.php` (admin-dashboard)

Provides session-based authentication helpers:

- `actingAsAdmin(string $role)` — sets up a session with a valid admin profile
- `actingAsSuperAdmin()` — shorthand for `actingAsAdmin('super_admin')`

### Fake Service Clients (admin-dashboard)

Located in `tests/Support/`:

- `FakeNotificationServiceClient` — stubs notification service API calls
- `FakeMessagingServiceClient` — stubs messaging service API calls
- `FakeTemplateManagementService` — stubs template management service calls

## Test Database

All API services use MySQL with the test database configured in `phpunit.xml`:

```xml
<env name="DB_DATABASE" value="np_<service>_test"/>
<env name="DB_SOCKET" value="/opt/lampp/var/mysql/mysql.sock"/>
```

The admin-dashboard uses SQLite in-memory for faster execution since it doesn't hit its own database directly.

## Writing New Tests

### API Service Tests

```php
class MyTest extends TestCase
{
    use RefreshDatabase, JwtHelper, AssertsApiEnvelope;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpJwt();
    }

    public function test_example(): void
    {
        $response = $this->withToken($this->makeToken())
            ->getJson('/api/v1/resource');

        $this->assertApiSuccess($response);
    }
}
```

### Dashboard Tests

```php
class MyUiTest extends TestCase
{
    use SessionHelper;

    public function test_example(): void
    {
        $this->actingAsAdmin();

        // Mock service dependencies
        $fake = new FakeNotificationServiceClient();
        $this->app->instance(NotificationServiceClientInterface::class, $fake);

        $this->get('/notifications')->assertOk();
    }
}
```

### Mocking External Services

For notification-service and admin-dashboard, external service calls are mocked via Laravel's container:

```php
$mock = $this->mock(UserServiceClientInterface::class);
$mock->shouldReceive('fetchUser')->andReturn([...]);
```

For admin-dashboard, use the Fake implementations in `tests/Support/` for consistent behavior.

## Test Counts

| Service              | Tests | Assertions |
|---------------------|-------|------------|
| user-service        | 56    | 465        |
| template-service    | 22    | 179        |
| notification-service| 17    | 117        |
| messaging-service   | 13    | 94         |
| admin-dashboard     | 42    | 135        |
| **Total**           | **150** | **990**  |
