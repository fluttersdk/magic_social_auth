# Architecture Overview

`magic_social_auth` is the client half of `magic-starter-laravel`'s social login. It follows the structure of the Magic Framework itself: a service provider registers a singleton manager into the IoC container, a static facade provides ergonomic access, and the manager dispatches to interchangeable driver objects. A flow client carries the wire protocol, so drivers stay small.

## Table of Contents

- [Core Patterns](#core-patterns)
- [Component Diagram](#component-diagram)
- [Data Flow](#data-flow)
- [IoC Integration](#ioc-integration)
- [Extensibility Points](#extensibility-points)
- [UI Layer](#ui-layer)
- [The magic_starter Bridge](#the-magic_starter-bridge)

---

## <a name="core-patterns"></a>Core Patterns

| Pattern | Role |
|---|---|
| **ServiceProvider** | Registers the `SocialAuthManager` singleton; wired into `Magic.init`. |
| **Singleton Manager** | `SocialAuthManager` resolves and caches drivers, picks the driver that runs on the current platform. |
| **Driver (Strategy)** | `SocialDriver` subclasses (`GoogleDriver`, `AppleDriver`, `RedirectDriver`): one provider's way into the backend. |
| **Flow client** | `SocialFlow` speaks the backend's protocol: browser redirect, exchange, link ticket, native token. Drivers compose it. |
| **Facade** | `SocialAuth` is the static entry point, delegating to `Magic.make<SocialAuthManager>('social_auth')`. |

---

## <a name="component-diagram"></a>Component Diagram

```
App
 ├─ SocialAuthButtons ── reads config, filters by platform + enabled flag
 └─ SocialAuth (facade) ── driver(name) · supports(name) · signOut()
          │
SocialAuthManager (singleton)
  ├─ driver(name): enabled check → custom factory or built-in → cache
  ├─ extend(name, factory) · registerProviderDefaults(...)
  └─ signOut(): each cached driver.signOut(), then clear the cache
          │
SocialDriver (abstract) ── signIn · beginConnect · connect · confirm · signOut
  ├─ GoogleDriver     native SDK on iOS/Android ──┐
  ├─ AppleDriver      native sheet on iOS ────────┤ SocialFlow.token()
  └─ RedirectDriver   GitHub, Microsoft; Apple    │
                      on Android/web; Google      │
                      on web ──────────────────────┤ SocialFlow.signIn / authorize
                                                  ▼
SocialFlow ── Pkce · Nonce · WebFlowSlot
  ├─ redirectUrl(): <network.drivers.api.base_url>/auth/social/{provider}/redirect
  ├─ browse(): flutter_web_auth_2 (iOS session, Android Auth Tab, web popup)
  ├─ exchange(): POST auth/social/exchange {code, code_verifier}
  ├─ linkTicket(): POST user/social-accounts/link-ticket
  └─ token(): POST auth/social/{provider}/token
          │
magic Http facade ── auth interceptor attaches the bearer
```

Which driver runs is decided in `SocialAuthManager`: Google is native off the web, Apple is native on iOS, everything else is a `RedirectDriver`.

---

## <a name="data-flow"></a>Data Flow

Signing in with GitHub on Android, from tap to session:

```
1. The user taps "Sign in with GitHub"
   SocialAuthButtons.onPressed('github')

2. The app calls: final result = await SocialAuth.driver('github').signIn()

3. SocialAuthManager.driver('github')
   - cache miss -> Config.get('social_auth.providers.github') -> enabled? -> RedirectDriver

4. RedirectDriver.signIn() -> SocialFlow.signIn('github')
   - Pkce.generate()                       new pair for this flow only
   - WebFlowSlot.claim()                   this flow owns the browser
   - FlutterWebAuth2.authenticate(...)     Auth Tab on <network base>/auth/social/github/redirect
                                           ?platform=android&challenge=<challenge>

5. Backend -> GitHub -> backend callback -> 302 to social_auth.callback.android
   with ?code=<one-time code>

6. SocialFlow.exchange(code, verifier)
   - POST auth/social/exchange {code, code_verifier}
   - SocialAuthResult.fromJson(answer)

7. The caller decides what the result means:
   - isTwoFactor -> challenge flow
   - otherwise Auth.login({'token': result.token}, createUser(result.user))
```

The native token flow skips steps 4 to 6: the driver opens the SDK sheet and posts its ID token to `auth/social/{provider}/token`.

---

## <a name="ioc-integration"></a>IoC Integration

`SocialAuthServiceProvider` registers the manager as a singleton:

```dart
class SocialAuthServiceProvider extends ServiceProvider {
  @override
  void register() {
    app.singleton('social_auth', () => SocialAuthManager());
  }
}
```

The `SocialAuth` facade resolves it on every call: `Magic.make<SocialAuthManager>('social_auth')`. Config is read lazily when a driver is first resolved, so config can change between `Magic.init` and the first `SocialAuth.driver(...)`, which is useful in tests.

---

## <a name="extensibility-points"></a>Extensibility Points

### Custom drivers: `extend()`

```dart
SocialAuth.manager.extend('gitlab', (config) => RedirectDriver('gitlab', config));
```

Registers a factory for the name and clears a cached instance. Config is read from `social_auth.providers.gitlab`. The `enabled` flag is checked before the factory runs.

### Platform seams

Each driver and `SocialFlow` expose the platform call as a `@visibleForTesting` member (`initializeSdk`, `nativeSignIn`, `requestCredential`, `authenticate`), and `SocialAuthManager.platformOverride` forces the platform. Tests stand in for the platform there instead of mocking a method channel.

There is no handler seam any more. The package never creates a session: the caller owns `Auth.login`, which is what lets 2FA and a cancelled deletion complete properly.

---

## <a name="ui-layer"></a>UI Layer

`SocialAuthButtons` is a config-driven stateless widget. It never calls a driver; it calls the `onPressed(provider)` callback synchronously from the tap (a web popup needs that), so the parent decides what a press does.

Resolution order for button metadata:

```
config['label'] / config['icon_svg'] / config['order']
        ↓ fallback
SocialProviderIcons.forProvider(name)   ← registered via registerProviderDefaults()
        ↓ fallback
Capitalised provider name, insertion-order index
```

Providers with `enabled: false`, and providers where `SocialAuth.supports(name)` is `false`, are omitted. On iOS Apple is always first.

---

## <a name="the-magic_starter-bridge"></a>The magic_starter Bridge

This package does not depend on `magic_starter`, and `magic_starter` does not depend on it. `magic_starter` declares a `MagicStarterSocialAuth` contract (`providers`, `label`, `icon`, `signIn`, `beginConnect`, `confirm`, `signOut`) and renders the buttons, the connected accounts page and the step-up dialog itself. `social:install` publishes `lib/app/providers/social_auth_starter_service_provider.dart` into the app, the one place that sees both packages. It implements the contract over `SocialAuth`, registers it with `MagicStarter.useSocialAuth`, translates every failure into the starter's own exception type (a cancel is marked, a refusal carries its `code`), and signs Google out when `Auth.stateNotifier` goes to signed-out.

---

**Related**

- [Installation](../getting-started/installation.md)
- [Configuration](../getting-started/configuration.md)
- [Drivers](../basics/drivers.md)
- [Flows](../basics/flows.md)
