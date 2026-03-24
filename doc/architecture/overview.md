# Architecture Overview

`magic_social_auth` follows the same structural patterns as the Magic Framework itself: a service provider registers a singleton manager into the IoC container, a static facade provides ergonomic access, and the manager dispatches work to interchangeable strategy objects (drivers and handlers).

## Table of Contents

- [Core Patterns](#core-patterns)
- [Component Diagram](#component-diagram)
- [Data Flow](#data-flow)
- [IoC Integration](#ioc-integration)
- [Extensibility Points](#extensibility-points)
- [UI Layer](#ui-layer)

---

## <a name="core-patterns"></a>Core Patterns

| Pattern | Role |
|---|---|
| **ServiceProvider** | Registers `SocialAuthManager` singleton; wired into `Magic.init`. |
| **Singleton Manager** | `SocialAuthManager` — resolves and caches drivers, holds the active handler. |
| **Driver (Strategy)** | `SocialDriver` subclasses — provider-specific token acquisition. |
| **Handler (Chain)** | `SocialAuthHandler` — single active handler, processes the token after driver auth. |
| **Facade** | `SocialAuth` — static entry point, delegates to `Magic.make<SocialAuthManager>('social_auth')`. |

---

## <a name="component-diagram"></a>Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│  App Layer                                              │
│                                                         │
│   SocialAuthButtons (Widget)                            │
│   ─ reads config, filters by platform + enabled flag    │
│   ─ calls onAuthenticate(provider) on tap               │
│                                                         │
│   SocialAuth (Facade)                                   │
│   ─ .driver(name)   → SocialAuthManager.driver()       │
│   ─ .supports(name) → driver.supportsPlatform()        │
│   ─ .signOut()      → SocialAuthManager.signOut()      │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  SocialAuthManager (Singleton)                          │
│                                                         │
│   _drivers: Map<String, SocialDriver>  (cache)          │
│   _factories: Map<String, Factory>     (extend() hooks) │
│   _handler: SocialAuthHandler          (replaceable)    │
│                                                         │
│   driver(name) → resolve → cache → return               │
│   handleAuth(token) → _handler.handle(token)            │
│   extend(name, factory)                                 │
│   setHandler(handler)                                   │
│   registerProviderDefaults(name, defaults)              │
│   signOut() → each driver.signOut() → clear cache       │
└──────────┬───────────────────────┬──────────────────────┘
           │                       │
┌──────────▼──────────┐   ┌────────▼─────────────────────┐
│  SocialDriver       │   │  SocialAuthHandler            │
│  (abstract)         │   │  (abstract)                   │
│                     │   │                               │
│  GoogleDriver       │   │  HttpSocialAuthHandler        │
│  MicrosoftDriver    │   │  ─ POST /auth/social/{p}      │
│  GithubDriver       │   │  ─ Auth.login(token, user)    │
│  CustomDriver       │   │                               │
│                     │   │  FirebaseAuthHandler (custom) │
│  → getToken()       │   │  SupabaseAuthHandler (custom) │
│  → authenticate()   │   └───────────────────────────────┘
│  → signOut()        │
└─────────────────────┘
```

---

## <a name="data-flow"></a>Data Flow

A complete authentication cycle from button tap to session:

```
1. User taps "Sign in with Google"
   SocialAuthButtons.onAuthenticate('google')

2. App calls: await SocialAuth.driver('google').authenticate()

3. SocialAuthManager.driver('google')
   - Check _drivers cache → miss
   - Read Config.get('social_auth.providers.google')
   - Check enabled flag
   - Instantiate GoogleDriver(config) → cache

4. GoogleDriver.authenticate()
   - GoogleDriver.getToken()
     - _ensureInitialized() (calls GoogleSignIn.instance.initialize)
     - GoogleSignIn.instance.authenticate()  [mobile]
       or authorizationClient.authorizeScopes()  [web]
     - Returns SocialToken { provider: 'google', accessToken, idToken, email, ... }
   - SocialAuth.manager.handleAuth(token)

5. SocialAuthManager.handleAuth(token)
   - Delegates to _handler.handle(token)

6. HttpSocialAuthHandler.handle(token)  [default]
   - POST /auth/social/google  { provider, access_token, id_token, email, ... }
   - Parse response { data: { token, user } }
   - SocialAuth.manager.createUser(user) → Auth.manager.createUser(user)
   - Auth.login({ token }, user)

7. Session established — app reacts to Auth state change
```

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

The `SocialAuth` facade resolves it on every call:

```dart
static SocialAuthManager get manager =>
    Magic.make<SocialAuthManager>('social_auth');
```

Config is read lazily when a driver is first resolved:

```dart
// Inside SocialAuthManager._getConfig
Config.get<Map<String, dynamic>>('social_auth.providers.$name') ?? {}
```

This means config can be mutated between `Magic.init` and the first driver access, which is useful in tests.

---

## <a name="extensibility-points"></a>Extensibility Points

There are two primary extension seams:

### 1. Custom Drivers — `extend()`

```dart
SocialAuth.manager.extend('apple', (config) => AppleDriver(config));
```

- Registers a factory for the given driver name.
- Clears any cached instance of that name.
- Config is read from `social_auth.providers.apple` automatically.

### 2. Custom Handlers — `setHandler()`

```dart
SocialAuth.manager.setHandler(FirebaseAuthHandler());
```

- Replaces the manager's single active handler.
- All subsequent `authenticate()` calls route through the new handler.

Both seams are independent — you can use a custom driver with the default handler, or the default driver with a custom handler.

---

## <a name="ui-layer"></a>UI Layer

`SocialAuthButtons` is a config-driven stateless widget. It does not call drivers directly; it only calls the `onAuthenticate` callback provided by the parent widget. This keeps UI completely decoupled from auth logic.

Resolution order for button metadata:

```
config['label'] / config['icon_svg'] / config['order']
        ↓ fallback
SocialProviderIcons.forProvider(name)   ← registered via registerProviderDefaults()
        ↓ fallback
Capitalised provider name, insertion-order index
```

Platform filtering is applied before rendering: `SocialAuth.supports(name)` is called for each enabled provider and unsupported entries are omitted silently.

---

**Related**

- [Installation](https://magic.fluttersdk.com/packages/social-auth/getting-started/installation)
- [Configuration](https://magic.fluttersdk.com/packages/social-auth/getting-started/configuration)
- [Drivers](https://magic.fluttersdk.com/packages/social-auth/basics/drivers)
- [Handlers](https://magic.fluttersdk.com/packages/social-auth/basics/handlers)
