<p align="center">
  <img src="https://raw.githubusercontent.com/fluttersdk/magic/master/.github/magic-logo.svg" width="120" alt="Magic Logo" />
</p>

<h1 align="center">Magic Social Auth</h1>

<p align="center">
  <strong>Laravel Socialite-style social authentication for the Magic Framework.</strong><br/>
  Config-driven OAuth with extensible drivers for Google, Microsoft, GitHub, and beyond.
</p>

<p align="center">
  <a href="https://pub.dev/packages/magic_social_auth"><img src="https://img.shields.io/pub/v/magic_social_auth.svg" alt="pub.dev version" /></a>
  <a href="https://github.com/fluttersdk/magic_social_auth/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/fluttersdk/magic_social_auth/ci.yml?branch=master&label=CI" alt="CI Status" /></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT" /></a>
  <a href="https://pub.dev/packages/magic_social_auth/score"><img src="https://img.shields.io/pub/points/magic_social_auth" alt="pub points" /></a>
  <a href="https://github.com/fluttersdk/magic_social_auth/stargazers"><img src="https://img.shields.io/github/stars/fluttersdk/magic_social_auth?style=flat" alt="GitHub Stars" /></a>
</p>

<p align="center">
  <a href="https://magic.fluttersdk.com/social-auth">Website</a> ·
  <a href="https://magic.fluttersdk.com/packages/social-auth/getting-started/installation">Docs</a> ·
  <a href="https://pub.dev/packages/magic_social_auth">pub.dev</a> ·
  <a href="https://github.com/fluttersdk/magic_social_auth/issues">Issues</a> ·
  <a href="https://github.com/fluttersdk/magic_social_auth/discussions">Discussions</a>
</p>

---

> **Alpha** — `magic_social_auth` is under active development. APIs may change between minor versions until `1.0.0`.

---

## Why Magic Social Auth?

Adding social login to a Flutter app means juggling platform-specific SDKs, OAuth redirect flows, token exchange with your backend, and wiring it all together differently for each provider. Every project reinvents the same boilerplate.

**Magic Social Auth** gives you a Socialite-style facade. One config file declares your providers. One line authenticates. Drivers handle platform differences. A pluggable handler chain sends tokens to your backend.

> **Config-driven social auth.** Define your providers, credentials, and scopes once. Magic Social Auth handles the rest.

---

## Features

| | Feature | Description |
|---|---------|-------------|
| :key: | **Socialite-Style API** | `SocialAuth.driver('google').authenticate()` — familiar, expressive |
| :busts_in_silhouette: | **Built-in Drivers** | Google (native SDK), Microsoft (OAuth), GitHub (OAuth) out of the box |
| :electric_plug: | **Extensible Drivers** | Add any provider via `manager.extend('apple', factory)` |
| :arrows_counterclockwise: | **Custom Auth Handlers** | Swap the default HTTP handler for Firebase, Supabase, or anything else |
| :iphone: | **Platform Detection** | Drivers declare supported platforms — check with `SocialAuth.supports()` |
| :art: | **Config-Driven UI** | `SocialAuthButtons` widget renders enabled providers with icons automatically |
| :door: | **Sign-Out Support** | `SocialAuth.signOut()` clears cached sessions across all providers |
| :package: | **Service Provider** | Two-phase bootstrap via Magic's IoC container — zero manual wiring |

---

## Quick Start

### 1. Add the dependency

```yaml
dependencies:
  magic_social_auth: ^0.0.1-alpha.1
```

### 2. Register the service provider

```dart
// lib/config/app.dart
import 'package:magic_social_auth/magic_social_auth.dart';

Map<String, dynamic> get appConfig => {
  'app': {
    'providers': [
      // ... other providers
      (app) => SocialAuthServiceProvider(app),
    ],
  },
};
```

### 3. Create the config file

```dart
// lib/config/social_auth.dart
import 'package:magic/magic.dart';

Map<String, dynamic> get socialAuthConfig => {
  'social_auth': {
    'endpoint': '/auth/social/{provider}',
    'providers': {
      'google': {
        'enabled': true,
        'client_id': env('GOOGLE_CLIENT_ID'),
        'server_client_id': env('GOOGLE_SERVER_CLIENT_ID'),
        'scopes': ['email', 'profile'],
      },
      'microsoft': {
        'enabled': true,
        'client_id': env('MICROSOFT_CLIENT_ID'),
        'tenant': env('MICROSOFT_TENANT', 'common'),
        'callback_scheme': 'myapp',
        'scopes': ['openid', 'profile', 'email'],
      },
      'github': {
        'enabled': true,
        'client_id': env('GITHUB_CLIENT_ID'),
        'callback_scheme': 'myapp',
        'scopes': ['read:user', 'user:email'],
      },
    },
  },
};
```

### 4. Register config in main.dart

```dart
// lib/main.dart
import 'config/social_auth.dart';

await Magic.init(
  configFactories: [
    () => appConfig,
    () => socialAuthConfig, // Add this
  ],
);
```

### 5. Authenticate

```dart
await SocialAuth.driver('google').authenticate();
```

That's it — the default `HttpSocialAuthHandler` sends the token to your Laravel backend and logs the user in via Sanctum.

---

## Configuration

The config file at `lib/config/social_auth.dart` controls everything:

```dart
Map<String, dynamic> get socialAuthConfig => {
  'social_auth': {
    // Backend endpoint for token exchange
    'endpoint': '/auth/social/{provider}',

    'providers': {
      'google': {
        'enabled': true,
        'client_id': env('GOOGLE_CLIENT_ID'),
        'server_client_id': env('GOOGLE_SERVER_CLIENT_ID'),
        'scopes': ['email', 'profile'],
      },
      'microsoft': {
        'enabled': true,
        'client_id': env('MICROSOFT_CLIENT_ID'),
        'tenant': env('MICROSOFT_TENANT', 'common'),
        'callback_scheme': 'myapp',
        'scopes': ['openid', 'profile', 'email'],
      },
      'github': {
        'enabled': true,
        'client_id': env('GITHUB_CLIENT_ID'),
        'callback_scheme': 'myapp',
        'scopes': ['read:user', 'user:email'],
      },
    },
  },
};
```

All values are read at runtime via `ConfigRepository`. Provider-specific OAuth setup (Google Cloud Console, Azure Portal, GitHub Developer Settings) is covered in the [configuration docs](https://magic.fluttersdk.com/packages/social-auth/getting-started/configuration).

---

## Usage

### Basic Authentication

```dart
await SocialAuth.driver('google').authenticate();
await SocialAuth.driver('microsoft').authenticate();
await SocialAuth.driver('github').authenticate();
```

### Check Platform Support

```dart
if (SocialAuth.supports('google')) {
  // Show Google sign-in button
}
```

### Custom Driver

```dart
// Register in your ServiceProvider.boot()
SocialAuth.manager.extend('apple', (config) => AppleDriver(config));

// Use it
await SocialAuth.driver('apple').authenticate();
```

### Custom Auth Handler

Replace the default HTTP handler with your own logic:

```dart
class FirebaseAuthHandler implements SocialAuthHandler {
  @override
  Future<void> handle(SocialToken token) async {
    final credential = GoogleAuthProvider.credential(
      idToken: token.idToken,
      accessToken: token.accessToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }
}

// Register it
SocialAuth.manager.setHandler(FirebaseAuthHandler());
```

### SocialAuthButtons Widget

Config-driven UI that renders buttons for all enabled, platform-supported providers:

```dart
SocialAuthButtons(
  onAuthenticate: (provider) async {
    await SocialAuth.driver(provider).authenticate();
  },
  loadingProvider: currentlyLoading, // shows spinner on active button
  mode: SocialAuthMode.signIn,      // or SocialAuthMode.signUp
)
```

Register UI metadata for custom providers:

```dart
SocialAuth.manager.registerProviderDefaults('apple', SocialProviderDefaults(
  label: 'Apple',
  iconSvg: '<svg>...</svg>',
  order: 4,
));
```

### Sign Out

```dart
await SocialAuth.signOut(); // Clears cached sessions across all providers
```

---

## Architecture

```
App launch → SocialAuthServiceProvider.register()
  → binds SocialAuthManager singleton via IoC
  → SocialAuth facade resolves manager from container
  → SocialAuth.driver('google') → manager.driver('google')
    → reads config via ConfigRepository
    → resolves built-in or custom driver
  → driver.authenticate()
    → driver.getToken() (native SDK / OAuth browser)
    → manager.handleAuth(token) → handler.handle(token)
    → default handler POSTs to backend → Auth.login()
```

**Key patterns:**

| Pattern | Implementation |
|---------|---------------|
| Singleton Manager | `SocialAuthManager` — central orchestrator |
| Strategy (Driver) | `GoogleDriver`, `MicrosoftDriver`, `GithubDriver` implement `SocialDriver` |
| Handler Chain | `SocialAuthHandler` — swap HTTP for Firebase, Supabase, etc. |
| Service Provider | Two-phase bootstrap: `register()` (sync) → `boot()` (async) |
| IoC Container | Binding via `app.singleton()` / `Magic.make()` |
| Static Facade | `SocialAuth` — zero-instance access to the manager |

---

## Documentation

| Document | Description |
|----------|-------------|
| [Installation](https://magic.fluttersdk.com/packages/social-auth/getting-started/installation) | Adding the package and registering the provider |
| [Configuration](https://magic.fluttersdk.com/packages/social-auth/getting-started/configuration) | Config reference, OAuth setup for Google/Microsoft/GitHub |
| [Drivers](https://magic.fluttersdk.com/packages/social-auth/basics/drivers) | Built-in drivers and writing custom ones |
| [Handlers](https://magic.fluttersdk.com/packages/social-auth/basics/handlers) | Default HTTP handler and custom handler implementations |
| [Architecture](https://magic.fluttersdk.com/packages/social-auth/architecture/overview) | Manager, facade, driver, and handler patterns |

---

## Contributing

Contributions are welcome! Please see the [issues page](https://github.com/fluttersdk/magic_social_auth/issues) for open tasks or to report bugs.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests following the [TDD flow](#) — red, green, refactor
4. Ensure all checks pass: `flutter test`, `dart analyze`, `dart format .`
5. Submit a pull request

---

## License

Magic Social Auth is open-sourced software licensed under the [MIT License](LICENSE).

---

<p align="center">
  Built with care by <a href="https://github.com/fluttersdk">FlutterSDK</a><br/>
  <sub>If Magic Social Auth helps your project, consider giving it a <a href="https://github.com/fluttersdk/magic_social_auth">star on GitHub</a>.</sub>
</p>
