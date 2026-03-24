# Drivers

A driver encapsulates the provider-specific authentication logic — opening the native SDK or OAuth browser, waiting for user consent, and returning a `SocialToken`. The `SocialAuthManager` resolves drivers by name and caches instances for the lifetime of the application.

## Table of Contents

- [SocialDriver Contract](#socialdriver-contract)
- [SocialToken Model](#socialtoken-model)
- [Built-in Drivers](#built-in-drivers)
- [Platform Support Matrix](#platform-support-matrix)
- [Registering a Custom Driver](#registering-a-custom-driver)

---

## <a name="socialdriver-contract"></a>SocialDriver Contract

Every driver extends the abstract `SocialDriver` class:

```dart
abstract class SocialDriver {
  SocialDriver(this.config);

  final Map<String, dynamic> config;

  /// Driver name ('google', 'microsoft', 'github', etc.)
  String get name;

  /// Platforms this driver supports.
  Set<SocialPlatform> get supportedPlatforms;

  /// Check if the current runtime platform is supported.
  bool supportsPlatform([SocialPlatform? platform]);

  /// Open the provider flow and return a token.
  Future<SocialToken> getToken();

  /// Full auth flow: getToken() → manager.handleAuth(token).
  /// Drivers inherit this implementation; override only when needed.
  Future<void> authenticate();

  /// Sign out from the provider. Default is a no-op.
  Future<void> signOut();
}
```

Call a driver through the `SocialAuth` facade:

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

// Resolve and call in one line
await SocialAuth.driver('google').authenticate();

// Separate resolve and call
final driver = SocialAuth.driver('google');
final token = await driver.getToken();   // raw token, no handler
await driver.authenticate();             // token + handler
```

> [!NOTE]
> `authenticate()` is the standard entry point for UI buttons. Use `getToken()` directly only when you need the raw `SocialToken` before the handler runs.

---

## <a name="socialtoken-model"></a>SocialToken Model

`getToken()` returns a `SocialToken` that is passed to the active `SocialAuthHandler`:

```dart
class SocialToken {
  final String provider;          // 'google', 'microsoft', 'github'
  final String accessToken;       // OAuth access token (empty for code-exchange flows)
  final String? authorizationCode; // OAuth code — backend must exchange this
  final String? idToken;          // JWT id_token (Google, Microsoft)
  final String? email;
  final String? name;
  final String? avatarUrl;
  final Map<String, dynamic>? extra;

  bool get isCodeExchange => authorizationCode != null;

  Map<String, dynamic> toMap(); // serialised for HTTP POST
}
```

Two authentication flows are modelled:

| Flow | `accessToken` | `authorizationCode` | Used by |
|---|---|---|---|
| Token flow | non-empty | `null` | Google (mobile & web) |
| Code exchange | empty string | non-empty | Microsoft, GitHub |

---

## <a name="built-in-drivers"></a>Built-in Drivers

### Google (`google`)

Uses the `google_sign_in ^7.x` singleton API.

- **Mobile (iOS/Android):** calls `GoogleSignIn.instance.authenticate()` — native SDK popup, returns `idToken` + `accessToken`.
- **Web:** calls `authorizationClient.authorizeScopes()` — browser authorization popup, returns `accessToken` only (no `idToken`). The backend must call Google's `userinfo` API to fetch user details.

Config keys: `client_id`, `server_client_id` (mobile only), `scopes`.

```dart
// google section in social_auth config
'google': {
  'enabled': true,
  'client_id': 'WEB_OR_IOS_CLIENT_ID',
  'server_client_id': 'SERVER_CLIENT_ID',   // mobile only
  'scopes': ['email', 'profile'],
},
```

### Microsoft (`microsoft`)

Uses OAuth authorization code flow (PKCE) via `flutter_web_auth_2 ^4.x`. The driver opens the Microsoft login URL in a browser and captures the authorization code from the redirect URI. The backend must exchange the code for tokens.

Config keys: `client_id` (required), `tenant`, `scopes`, `callback_scheme`, `web_callback_url`.

```dart
'microsoft': {
  'enabled': true,
  'client_id': 'AZURE_APP_CLIENT_ID',
  'tenant': 'common',            // or your directory tenant ID
  'callback_scheme': 'myapp',
  'web_callback_url': 'https://myapp.com/auth/callback',
},
```

### GitHub (`github`)

Uses OAuth browser flow via `flutter_web_auth_2 ^4.x`. Like Microsoft, GitHub returns only an authorization code; the backend exchanges it for an access token using the GitHub token endpoint.

Config keys: `client_id` (required), `scopes`, `callback_scheme`, `web_callback_url`.

```dart
'github': {
  'enabled': true,
  'client_id': 'GITHUB_OAUTH_APP_CLIENT_ID',
  'scopes': ['read:user', 'user:email'],
  'callback_scheme': 'myapp',
},
```

---

## <a name="platform-support-matrix"></a>Platform Support Matrix

| Driver | iOS | Android | Web | macOS | Windows | Linux |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Google | Yes | Yes | Yes | — | — | — |
| Microsoft | Yes | Yes | Yes | Yes | Yes | — |
| GitHub | Yes | Yes | Yes | Yes | Yes | Yes |

> [!NOTE]
> `SocialAuth.supports('google')` returns `false` on macOS, Windows, and Linux at runtime. `SocialAuthButtons` uses this check to omit unsupported providers automatically.

---

## <a name="registering-a-custom-driver"></a>Registering a Custom Driver

Implement `SocialDriver`, then register via `SocialAuth.manager.extend()`. Optionally register UI metadata so `SocialAuthButtons` can render your provider.

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

class AppleDriver extends SocialDriver {
  AppleDriver(super.config);

  @override
  String get name => 'apple';

  @override
  Set<SocialPlatform> get supportedPlatforms => {
    SocialPlatform.ios,
    SocialPlatform.macos,
  };

  @override
  Future<SocialToken> getToken() async {
    // Call Sign in with Apple SDK, return SocialToken
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
    );
    return SocialToken(
      provider: name,
      accessToken: credential.authorizationCode,
      idToken: credential.identityToken,
      email: credential.email,
    );
  }
}
```

Register the driver and its UI defaults (for example, in your app's service provider `boot` method):

```dart
SocialAuth.manager.extend('apple', (config) => AppleDriver(config));

SocialAuth.manager.registerProviderDefaults(
  'apple',
  SocialProviderDefaults(
    label: 'Apple',
    iconSvg: '<svg>...</svg>',
    order: 4,
  ),
);
```

> [!TIP]
> Call `extend()` before any call to `SocialAuth.driver('apple')`. The manager clears cached instances when `extend()` is called, so re-registration is safe.

---

**Related**

- [Installation](https://magic.fluttersdk.com/packages/social-auth/getting-started/installation)
- [Configuration](https://magic.fluttersdk.com/packages/social-auth/getting-started/configuration)
- [Handlers](https://magic.fluttersdk.com/packages/social-auth/basics/handlers)
- [Architecture overview](https://magic.fluttersdk.com/packages/social-auth/architecture/overview)
