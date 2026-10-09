# Magic Social Auth Plugin

Social authentication plugin for Magic Framework: the client of magic-starter-laravel's social login (native Google and Apple sheets, a backend-hosted browser flow with PKCE for the rest). Laravel Socialite-style API with extensible drivers.

**Version:** 0.0.9 · **Dart:** ^3.12.0 · **Flutter:** >=3.44.0

## Commands

| Command | Description |
|---------|-------------|
| `flutter test --coverage` | Run all tests with coverage |
| `flutter analyze --no-fatal-infos` | Static analysis |
| `dart format .` | Format all code |

## Architecture

**Pattern**: ServiceProvider + Singleton Manager + Driver strategy + Flow client + UI components

```
lib/
├── magic_social_auth.dart       # Barrel export (Facade, Core, Contracts, Drivers, Flow, Providers, Models, Exceptions, UI, CLI)
├── cli.dart                     # Flutter-free barrel: the artisan provider only
└── src/
    ├── social_auth_manager.dart  # Singleton manager: driver resolution per platform, extend(), sign out
    ├── contracts/                # SocialDriver (abstract): signIn, beginConnect, connect, confirm, signOut
    ├── drivers/                  # GoogleDriver (native), AppleDriver (native iOS), RedirectDriver (backend browser flow)
    ├── flow/                     # SocialFlow (wire protocol), Pkce, Nonce, WebFlowSlot (one browser flow at a time)
    ├── facades/                  # SocialAuth (static facade over SocialAuthManager)
    ├── models/                   # SocialAuthResult, SocialPlatform (+ platform-conditional imports)
    ├── providers/                # SocialAuthServiceProvider (register + boot)
    ├── exceptions/               # SocialAuthException (code, statusCode), SocialAuthCancelledException, UnsupportedPlatformException, ProviderNotConfiguredException
    ├── ui/                       # SocialAuthButtons (config-driven widget), SocialProviderIcons (registry)
    └── cli/                      # social:install, social:doctor, the artisan provider
assets/stubs/install/             # social_auth_config, auth.html, social_auth_starter_service_provider (the magic_starter bridge)
install.yaml                      # Manifest: registers SocialAuthServiceProvider; the flag-driven ops are staged by SocialInstallCommand
```

**Data flow (browser flow):** `SocialAuth.driver(name).signIn()` → manager resolves the driver for the platform → `SocialFlow` mints a `Pkce` pair, claims the `WebFlowSlot`, opens `<network.drivers.api.base_url>/auth/social/{provider}/redirect` with `flutter_web_auth_2` → backend callback returns a one-time code to `social_auth.callback.<platform>` → `POST auth/social/exchange {code, code_verifier}` → `SocialAuthResult`. **Native flow:** the driver opens the SDK sheet and posts the ID token to `auth/social/{provider}/token`. The package never logs the app in: the caller (or the magic_starter bridge) runs `Auth.login`, handles the 2FA challenge and `deletionCancelled`.

**Pure Dart** for the runtime: no android/, ios/ or native code. Platform support via `google_sign_in`, `sign_in_with_apple` and `flutter_web_auth_2`. The native project edits belong to `social:install` and are checked by `social:doctor`.

**Backend contract:** magic-starter-laravel `doc/basics/social-login.md` and `account-deletion.md`. `social_auth.callback.ios` and `.android` must equal the backend's `MAGIC_STARTER_SOCIAL_IOS_REDIRECT` and `MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT`. Change one side, keep the other in sync.

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

- Fake platform SDKs through the overridable seams on the driver or flow (`initializeSdk`, `nativeSignIn`, `requestCredential`, `authenticate`), never a MethodChannel mock: `class _FakeGoogleDriver extends GoogleDriver`
- Reset state in setUp: `MagicApp.reset()`, `Config.flush()`/`Config.set`, `SocialAuthManager().forgetDrivers()`, `GoogleDriver.resetInitialization()`
- Tests mirror `lib/src/` structure in `test/`
- Widgets are wrapped `MaterialApp > WindTheme(WindThemeData()) > Scaffold`
- Never hit a real provider host or a real platform channel; `test/flow/social_flow_loopback_test.dart` runs the flow against a local server

## Key Gotchas

| Mistake | Fix |
|---------|-----|
| Hardcoded config values | Read from `ConfigRepository`: `Config.get('social_auth.providers.$name')` |
| Direct manager instantiation | Use singleton factory: `SocialAuthManager()` returns the shared instance |
| `await` before `FlutterWebAuth2.authenticate` on the web sign-in path | A popup opened after an `await` is blocked. `SocialFlow.authorize` opens the browser in the synchronous run of the call; `connect` and `confirm` open from an explicit tap after any async gap (`beginConnect` returns the opener) |
| Reusing a PKCE pair, link ticket or proof across retries | Every flow mints a new `Pkce`, a new ticket and a new proof; nothing is cached |
| A nonce for Google, or the raw nonce for Apple | Google takes none (the backend prohibits it). Apple gets the lowercase sha256 hex, the backend gets the raw value |
| `preferEphemeral` on Android | Never: it drops the Auth Tab for a Custom Tab that needs a callback activity. Only iOS confirm is ephemeral |
| An https callback on iOS | Needs iOS 17.4. iOS uses a custom scheme; Android uses an https App Link on a dedicated host |
| Android callback host shared with the app's other App Link filters | Android may open the other activity. `social:doctor` flags the overlap |
| Platform-conditional imports | `SocialPlatform` uses `_io.dart` / `_web.dart` / `_stub.dart`, never import platform files directly |
| Wind UI coupling in `SocialAuthButtons` | Widget uses `WDiv`, `WButton`, `WText`, `WSvg`, `WSpacer`: requires Wind UI to be registered |
| `SocialAuth.signOut()` after a restored session | It only reaches cached drivers; sign Google out by name on every signed-out transition (the bridge does) |
| Guests and step-up | A guest (`is_guest`, no password) sends no proof; the proof map is built per call |
| Reading a backend refusal by message | Switch on `SocialAuthException.code` |

## Skills & Extensions

- `fluttersdk:magic-framework` — Magic Framework patterns: facades, service providers, IoC, Eloquent ORM, controllers, routing. Use for ANY code touching Magic APIs.

## CI

- `ci.yml`: push/PR → `flutter pub get` → `flutter analyze --no-fatal-infos` → `dart format --set-exit-if-changed` → `flutter test --coverage` → codecov upload
