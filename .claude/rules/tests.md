---
paths:
  - "test/**/*.dart"
---

# Testing Domain

- Mock via contract inheritance (no mockito): `class MockDriver extends SocialDriver { ... }`
- Mock drivers: override `name`, `supportedPlatforms`, `signIn()`, `beginConnect()`, `confirm()`, `signOut()`; track calls with flags (e.g., `signOutCalled`)
- Platform SDKs and the browser are faked through `@visibleForTesting` seams (`SocialFlow.authenticate`, `GoogleDriver.nativeSignIn`/`initializeSdk`, `AppleDriver.requestCredential`), never MethodChannel mocks; real HTTP shapes are asserted against a loopback `HttpServer` without `TestWidgetsFlutterBinding.ensureInitialized()`
- Reset singleton state in setUp: `manager.forgetDrivers()` clears cache before each test
- Test structure mirrors `lib/src/`: `test/drivers/`, `test/flow/`, `test/facades/`, `test/models/`, `test/ui/`, `test/exceptions/`, `test/cli/`
- Use `group()` for logical grouping by feature/scenario
- Import from `package:magic_social_auth/src/...` (internal paths) in tests, not barrel
- Assertions: `expect()`, `isA<T>()`, `throwsA()`, `isFalse`, `isTrue`, `containsAll()`
- Provider tests: register driver factory via `manager.extend()`, verify resolution with `manager.driver()`
- Exception tests: verify message, code, `toString()` output
- Widget tests for UI components (SocialAuthButtons): verify rendering, tap callbacks, platform-specific behavior
