<p align="center">
  <img src="https://raw.githubusercontent.com/fluttersdk/magic/master/.github/magic-logo.svg" width="120" alt="Magic Logo" />
</p>

<h1 align="center">Magic Social Auth</h1>

<p align="center">
  <strong>Laravel Socialite-style social authentication for the Magic Framework.</strong><br/>
  Native Google and Apple sheets, a backend-hosted browser flow for GitHub and Microsoft, on iOS, Android and web.
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

> **Alpha**: `magic_social_auth` is under active development. APIs may change between minor versions until `1.0.0`.

---

## Why Magic Social Auth?

Adding social login to a Flutter app means juggling platform SDKs, OAuth redirects, nonce and PKCE rules, native project edits on three platforms, and a backend that has to agree on every value. Every project reinvents the same boilerplate.

**Magic Social Auth** is the client of `magic-starter-laravel`'s social login. `social:install` makes the native edits, `social:doctor` checks them and prints the backend `.env` lines, and the drivers run the flow: native Google and Apple sheets on mobile, a backend-hosted browser flow with PKCE for everything else.

> **One contract, four providers.** Google, Apple, GitHub and Microsoft on iOS, Android and web, signing in, connecting, confirming and disconnecting against the same backend API.

---

## Features

| | Feature | Description |
|---|---------|-------------|
| :key: | **Socialite-Style API** | `SocialAuth.driver('google').signIn()`, familiar and expressive |
| :iphone: | **Native Sheets** | Google on iOS and Android, Sign in with Apple on iOS: the ID token is verified by the backend, never a provider access token |
| :globe_with_meridians: | **Browser Flow with PKCE** | GitHub and Microsoft everywhere, Apple on Android and web, Google on web: backend-hosted, one-time code, verifier-bound |
| :link: | **Connect and Confirm** | Link another provider to a signed-in account, or re-authenticate with a linked one for a step-up proof |
| :hammer_and_wrench: | **social:install** | Config, iOS Google keys and URL scheme, Sign in with Apple entitlement, Android callback activity, `web/auth.html`, the starter bridge |
| :stethoscope: | **social:doctor** | Checks the native setup against the config and prints the backend env to set |
| :electric_plug: | **Extensible Drivers** | Add a provider via `SocialAuth.manager.extend()` |
| :art: | **Config-Driven UI** | `SocialAuthButtons` renders enabled, platform-supported providers; Apple first on iOS |
| :package: | **Service Provider** | Two-phase bootstrap via Magic's IoC container |

---

## Quick Start

### 1. Add the dependency

```yaml
dependencies:
  magic_social_auth: ^0.0.8
```

Requires Dart `^3.12.0` and Flutter `>=3.44.0`.

### 2. Install

```bash
flutter pub get
dart run fluttersdk_artisan plugin:install magic_social_auth
dart run <app>:artisan social:install \
  --providers=google,apple,github,microsoft \
  --google-ios-client-id=123-abc.apps.googleusercontent.com \
  --google-server-client-id=123-def.apps.googleusercontent.com \
  --ios-scheme=myapp \
  --android-callback=https://auth.example.com/auth/social
```

Every flag is documented in the [installation guide](https://magic.fluttersdk.com/packages/social-auth/getting-started/installation).

### 3. Check it

```bash
dart run <app>:artisan social:doctor
```

The doctor names every missing native edit and prints the `MAGIC_STARTER_SOCIAL_*` lines to set in the backend `.env`, and the callback URL each provider console has to list.

### 4. Sign in

```dart
final SocialAuthResult result = await SocialAuth.driver('google').signIn();

if (result.isTwoFactor) {
  // Finish at auth/two-factor-challenge with result.twoFactorToken.
  return;
}

await Auth.login(
  {'token': result.token},
  SocialAuth.manager.createUser(result.user!),
);
```

With `magic_starter` you write none of this: the bridge `social:install` publishes feeds the result into the starter's login, registration and account screens.

---

## Configuration

`social:install` writes `lib/config/social_auth.dart`:

```dart
Map<String, dynamic> get socialAuthConfig => {
  'social_auth': {
    'providers': {
      'google': {
        'enabled': true,
        'ios_client_id': '123-abc.apps.googleusercontent.com',
        'server_client_id': '123-def.apps.googleusercontent.com',
      },
      'apple': {'enabled': true},
      'github': {'enabled': true},
      'microsoft': {'enabled': true},
    },
    'callback': {
      'ios': 'myapp://auth/social',
      'android': 'https://auth.example.com/auth/social',
    },
  },
};
```

The callbacks must equal the backend's `MAGIC_STARTER_SOCIAL_IOS_REDIRECT` and `MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT`. Provider console setup (Google iOS, Android and web clients, the Apple Services ID and key, a GitHub OAuth app, an Entra Web registration) is covered in the [installation guide](https://magic.fluttersdk.com/packages/social-auth/getting-started/installation) and the [configuration reference](https://magic.fluttersdk.com/packages/social-auth/getting-started/configuration).

---

## Usage

### Sign In, Connect, Confirm

```dart
final SocialDriver driver = SocialAuth.driver('github');

await driver.signIn();                          // sign in, or register
await driver.connect({'password': password});   // link to the signed-in account
await driver.confirm();                         // step-up proof in result.confirmationToken
```

`connect` takes the step-up proof the account can give (`password`, a TOTP `code`, or a `confirmation_token` from `confirm()`); a guest sends `null`. On the web, a popup opened after an `await` is blocked: use `beginConnect(proof)` and run the returned opener from a second tap.

### Check Platform Support

```dart
if (SocialAuth.supports('apple')) {
  // Show Sign in with Apple
}
```

### Custom Driver

```dart
SocialAuth.manager.extend('gitlab', (config) => RedirectDriver('gitlab', config));
```

### SocialAuthButtons Widget

```dart
SocialAuthButtons(
  onPressed: (provider) => controller.doSocialSignIn(provider),
  loadingProvider: currentlyLoading,
  mode: SocialAuthMode.signIn, // or SocialAuthMode.signUp
)
```

`onPressed` runs synchronously from the tap, which a web popup needs.

### Sign Out

```dart
await SocialAuth.signOut(); // signs out every cached driver (Google's SDK session)
```

`SocialAuth.signOut()` only reaches drivers cached in this process. An app without `magic_starter` must sign Google out on its own sign-out with `SocialAuth.driver('google').signOut()`; the starter bridge does it for starter apps.

---

## Platform Support

| Provider | iOS | Android | Web |
|---|---|---|---|
| Google | native SDK | native SDK | browser flow |
| Apple | native sheet | browser flow | browser flow |
| GitHub | browser flow | browser flow | browser flow |
| Microsoft | browser flow | browser flow | browser flow |

iOS returns through a custom scheme (an https callback needs iOS 17.4). Android returns through an https App Link on a dedicated host. Web uses a popup and `web/auth.html`. macOS, Windows and Linux are not supported.

---

## Architecture

```
SocialAuth.driver('github').signIn()
  → SocialAuthManager resolves a driver for the platform (Google/Apple native, else RedirectDriver)
  → SocialFlow: PKCE pair → system browser → backend → callback with a one-time code
  → POST auth/social/exchange {code, code_verifier}
  → SocialAuthResult (token + user, or a 2FA challenge)
  → the caller runs Auth.login
```

| Pattern | Implementation |
|---------|---------------|
| Singleton Manager | `SocialAuthManager`, central orchestrator |
| Strategy (Driver) | `GoogleDriver`, `AppleDriver`, `RedirectDriver` implement `SocialDriver` |
| Flow client | `SocialFlow` speaks the backend protocol; `Pkce` and `Nonce` mint the per-flow secrets |
| Service Provider | Two-phase bootstrap: `register()` (sync) → `boot()` (async) |
| Static Facade | `SocialAuth`, zero-instance access to the manager |

---

## Upgrading from 0.0.7

0.0.8 is a breaking release.

- **Removed:** `SocialToken`, `SocialAuthHandler`, the default HTTP handler that posted a provider token and `SocialAuth.manager.setHandler()`, the Microsoft and GitHub drivers (both are a `RedirectDriver` now), `getToken()` and `authenticate()` on drivers, and the per-provider config keys `client_id`, `scopes`, `tenant` and the mobile scheme and web callback URL keys, plus the top-level `endpoint`.
- **Changed:** drivers answer a `SocialAuthResult`; the app (or the starter bridge) calls `Auth.login`. `SocialAuthButtons` takes `onPressed` instead of `onAuthenticate`.
- **Added:** Apple, `signIn`, `connect`, `beginConnect`, `confirm`, `social:doctor`, and the `callback.ios` and `callback.android` config keys.
- **Raised:** Dart `^3.12.0`, Flutter `>=3.44.0`, `fluttersdk_artisan ^0.0.18`.
- **Backend:** requires `magic-starter-laravel` with the `social-login` feature.

---

## Documentation

| Document | Description |
|----------|-------------|
| [Installation](https://magic.fluttersdk.com/packages/social-auth/getting-started/installation) | `social:install` flags, `social:doctor`, backend env, provider consoles, platform notes |
| [Configuration](https://magic.fluttersdk.com/packages/social-auth/getting-started/configuration) | Every config key |
| [Drivers](https://magic.fluttersdk.com/packages/social-auth/basics/drivers) | The driver contract, built-in drivers and custom ones |
| [Flows](https://magic.fluttersdk.com/packages/social-auth/basics/flows) | Native token flow, browser flow, connect, confirm, errors |
| [Architecture](https://magic.fluttersdk.com/packages/social-auth/architecture/overview) | Manager, facade, driver and flow client |

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
