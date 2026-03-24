---
path: "test/**/*.dart"
---

# Testing Domain

- Mock via contract inheritance (no mockito): `class MockDriver extends SocialDriver { ... }`
- Mock drivers: override `name`, `supportedPlatforms`, `getToken()`, `signOut()`; track calls with flags (e.g., `signOutCalled`)
- Reset singleton state in setUp: `manager.forgetDrivers()` clears cache before each test
- Test structure mirrors `lib/src/`: `test/drivers/`, `test/facades/`, `test/models/`, `test/ui/`, `test/exceptions/`
- Use `group()` for logical grouping by feature/scenario
- Import from `package:magic_social_auth/src/...` (internal paths) in tests, not barrel
- Assertions: `expect()`, `isA<T>()`, `throwsA()`, `isFalse`, `isTrue`, `containsAll()`
- Provider tests: register driver factory via `manager.extend()`, verify resolution with `manager.driver()`
- Exception tests: verify message, code, `toString()` output
- Widget tests for UI components (SocialAuthButtons): verify rendering, tap callbacks, platform-specific behavior
