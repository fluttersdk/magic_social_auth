# Magic Social Auth Plugin

Social authentication plugin for Magic Framework. Laravel Socialite-style API with extensible drivers.

**Version:** 0.0.1-alpha.1 · **Dart:** >=3.6.0 · **Flutter:** >=3.27.0

## Commands

| Command | Description |
|---------|-------------|
| `flutter test --coverage` | Run all tests with coverage |
| `flutter analyze --no-fatal-infos` | Static analysis |
| `dart format .` | Format all code |

## Architecture

**Pattern**: ServiceProvider + Singleton Manager + Driver strategy + UI components

```
lib/
├── magic_social_auth.dart       # Barrel export (Facade, Core, Contracts, Drivers, Providers, Models, Exceptions, UI)
└── src/
    ├── social_auth_manager.dart  # Singleton manager — driver resolution, handler orchestration, sign out
    ├── contracts/                # SocialDriver (abstract), SocialAuthHandler (abstract)
    ├── drivers/                  # GoogleDriver, MicrosoftDriver, GithubDriver
    ├── facades/                  # SocialAuth (static facade over SocialAuthManager)
    ├── models/                   # SocialToken, SocialPlatform (+ platform-conditional imports)
    ├── providers/                # SocialAuthServiceProvider (register + boot)
    ├── exceptions/               # SocialAuthException, SocialAuthCancelledException, ProviderNotConfiguredException
    └── ui/                       # SocialAuthButtons (config-driven widget), SocialProviderIcons (registry)
```

**Data flow:** App boot → `SocialAuthServiceProvider.boot()` → `SocialAuthButtons` renders enabled providers → user taps → `SocialAuth.driver(name).getToken()` → driver authenticates → `SocialAuthManager.handleAuth(token)` → `SocialAuthHandler.handle(token)`

**Pure Dart** — no android/, ios/, or native platform code. Platform support via `google_sign_in` and `flutter_web_auth_2` packages.

## Post-Change Checklist

After ANY source code change, sync **before committing**:

1. **`CHANGELOG.md`** — Add entry under `[Unreleased]` section
2. **`README.md`** — Update if features, API, or usage changes
3. **`doc/`** — Update relevant documentation files

## Development Flow (TDD)

Every feature, fix, or refactor must go through the red-green-refactor cycle:

1. **Red** — Write a failing test that describes the expected behavior
2. **Green** — Write the minimum code to make the test pass
3. **Refactor** — Clean up while keeping tests green

**Rules:**
- No production code without a failing test first
- Run `flutter test` after every change — all tests must stay green
- Run `dart analyze` after every change — zero warnings, zero errors
- Run `dart format .` before committing — zero formatting issues

**Verification cycle:** Edit → `flutter test` → `dart analyze` → repeat until green

## Testing

- Mock via contract inheritance (no mockito): `class MockDriver extends SocialDriver`
- Reset state in setUp: `manager.forgetDrivers()`
- Tests mirror `lib/src/` structure in `test/`
- Handler mocks implement `SocialAuthHandler` directly

## Key Gotchas

| Mistake | Fix |
|---------|-----|
| Hardcoded config values | Read from `ConfigRepository`: `Config.get('social_auth.providers.$name')` |
| Direct manager instantiation | Use singleton factory: `SocialAuthManager()` returns the shared instance |
| `callback_scheme` defaults to `'uptizm'` | Set `callback_scheme` explicitly in `social_auth.providers.microsoft` config |
| Platform-conditional imports | `SocialPlatform` uses `_io.dart` / `_web.dart` / `_stub.dart` — never import platform files directly |
| Wind UI coupling in `SocialAuthButtons` | Widget uses `WDiv`, `WButton`, `WText`, `WSvg`, `WSpacer` — requires Wind UI to be registered |
| `GoogleDriver` only supports iOS, Android, Web | Desktop platforms will throw at driver resolution — check `SocialAuth.supports(name)` first |
| `serverClientId` ignored on web | `GoogleDriver` strips `serverClientId` when `kIsWeb` — do not rely on it in web config |

## Skills & Extensions

- `fluttersdk:magic-framework` — Magic Framework patterns: facades, service providers, IoC, Eloquent ORM, controllers, routing. Use for ANY code touching Magic APIs.

## CI

- `ci.yml`: push/PR → `flutter pub get` → `flutter analyze --no-fatal-infos` → `dart format --set-exit-if-changed` → `flutter test --coverage` → codecov upload
