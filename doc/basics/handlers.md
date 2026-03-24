# Handlers

A handler receives the `SocialToken` produced by a driver and decides what to do with it — typically sending it to a backend, or signing in directly with a third-party SDK like Firebase or Supabase. The `SocialAuthManager` holds exactly one active handler at a time; the default is `HttpSocialAuthHandler`.

## Table of Contents

- [SocialAuthHandler Contract](#socialauthhandler-contract)
- [Handler Lifecycle](#handler-lifecycle)
- [Default Handler: HttpSocialAuthHandler](#default-handler-httpsocialauthhandler)
- [Replacing the Handler](#replacing-the-handler)
- [Custom Handler Examples](#custom-handler-examples)

---

## <a name="socialauthhandler-contract"></a>SocialAuthHandler Contract

```dart
abstract class SocialAuthHandler {
  /// Called after a driver successfully obtains a token.
  Future<void> handle(SocialToken token);
}
```

`handle` receives a fully-populated `SocialToken` and is responsible for completing the sign-in — storing credentials, creating a session, calling a backend API, etc.

---

## <a name="handler-lifecycle"></a>Handler Lifecycle

```
User taps button
      │
      ▼
SocialAuth.driver(name).authenticate()
      │
      ├─ driver.getToken()        ← provider SDK / OAuth browser
      │        │
      │        ▼
      │    SocialToken
      │
      ▼
SocialAuthManager.handleAuth(token)
      │
      ▼
SocialAuthHandler.handle(token)   ← your logic runs here
      │
      ▼
  Session established
```

The `SocialDriver.authenticate()` method (inherited by all drivers) orchestrates this flow:

```dart
Future<void> authenticate() async {
  final token = await getToken();
  await SocialAuth.manager.handleAuth(token);
}
```

---

## <a name="default-handler-httpsocialauthhandler"></a>Default Handler: HttpSocialAuthHandler

The built-in `HttpSocialAuthHandler` is designed for a Laravel backend secured with Sanctum. It:

1. Reads `social_auth.endpoint` from config (default: `/auth/social/{provider}`).
2. Replaces `{provider}` with `token.provider`.
3. POSTs the serialised token (`token.toMap()`) to that URL via Magic's `Http` client.
4. Expects a JSON response: `{ "data": { "token": "...", "user": { ... } } }`.
5. Calls `Auth.login({ "token": authToken }, user)` to establish a Magic session.

```dart
// Expected backend response shape
{
  "data": {
    "token": "1|sanctum-token...",
    "user": {
      "id": 1,
      "name": "Jane Doe",
      "email": "jane@example.com"
    }
  }
}
```

> [!NOTE]
> The user object is passed to `Auth.manager.createUser(userData)`, which uses your app's registered user factory. No additional configuration in `magic_social_auth` is required.

---

## <a name="replacing-the-handler"></a>Replacing the Handler

Call `SocialAuth.manager.setHandler()` with your custom handler instance — typically during app bootstrap, before any authentication occurs.

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

// In your service provider boot(), or Magic.init callback
SocialAuth.manager.setHandler(FirebaseAuthHandler());
```

---

## <a name="custom-handler-examples"></a>Custom Handler Examples

### Firebase

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:magic_social_auth/magic_social_auth.dart';

class FirebaseAuthHandler implements SocialAuthHandler {
  @override
  Future<void> handle(SocialToken token) async {
    final AuthCredential credential;

    switch (token.provider) {
      case 'google':
        credential = GoogleAuthProvider.credential(
          idToken: token.idToken,
          accessToken: token.accessToken,
        );
      default:
        throw UnsupportedError('Provider ${token.provider} not supported');
    }

    await FirebaseAuth.instance.signInWithCredential(credential);
  }
}
```

Register it before first authentication:

```dart
SocialAuth.manager.setHandler(FirebaseAuthHandler());
```

### Supabase

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:magic_social_auth/magic_social_auth.dart';

class SupabaseAuthHandler implements SocialAuthHandler {
  final _supabase = Supabase.instance.client;

  @override
  Future<void> handle(SocialToken token) async {
    // Google: use id_token + access_token
    if (token.provider == 'google' && token.idToken != null) {
      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: token.idToken!,
        accessToken: token.accessToken,
      );
      return;
    }

    // Code-exchange providers: pass authorization_code to Supabase
    if (token.isCodeExchange) {
      await _supabase.auth.exchangeCodeForSession(token.authorizationCode!);
      return;
    }

    throw UnsupportedError('Unhandled token type for ${token.provider}');
  }
}
```

> [!TIP]
> Use `token.isCodeExchange` to branch between token-flow providers (Google) and code-exchange providers (Microsoft, GitHub) without hardcoding provider names.

---

**Related**

- [Drivers](https://magic.fluttersdk.com/packages/social-auth/basics/drivers)
- [Configuration](https://magic.fluttersdk.com/packages/social-auth/getting-started/configuration)
- [Architecture overview](https://magic.fluttersdk.com/packages/social-auth/architecture/overview)
