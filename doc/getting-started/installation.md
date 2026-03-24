# Installation

Social authentication for Flutter apps using the Magic Framework. Laravel Socialite-style API with extensible drivers for Google, Microsoft, and GitHub.

## Table of Contents

- [Requirements](#requirements)
- [Install the Package](#install-the-package)
- [Register the Service Provider](#register-the-service-provider)
- [Create the Config File](#create-the-config-file)
- [Platform Setup](#platform-setup)
- [Verify the Installation](#verify-the-installation)

---

## <a name="requirements"></a>Requirements

| Dependency | Version |
|---|---|
| Dart SDK | `>=3.6.0 <4.0.0` |
| Flutter | `>=3.27.0` |
| magic | `^1.0.0-alpha.3` |

---

## <a name="install-the-package"></a>Install the Package

Add `magic_social_auth` to your `pubspec.yaml`:

```yaml
dependencies:
  magic_social_auth: ^0.0.1-alpha.1
```

Then fetch dependencies:

```bash
flutter pub get
```

---

## <a name="register-the-service-provider"></a>Register the Service Provider

Add `SocialAuthServiceProvider` to your Magic application kernel. The provider registers the `SocialAuthManager` singleton into the IoC container under the `social_auth` key.

```dart
import 'package:magic/magic.dart';
import 'package:magic_social_auth/magic_social_auth.dart';

await Magic.init(
  providers: [
    (app) => SocialAuthServiceProvider(app),
    // ... other providers
  ],
);
```

> [!NOTE]
> `SocialAuthServiceProvider` must be registered after your app's `AuthServiceProvider` because `SocialAuthManager.createUser` delegates to `Auth.manager.createUser`, which depends on a registered user factory.

---

## <a name="create-the-config-file"></a>Create the Config File

Create `lib/config/social_auth.dart` with your provider credentials:

```dart
Map<String, dynamic> socialAuthConfig() => {
  'endpoint': '/auth/social/{provider}',

  'providers': {
    'google': {
      'enabled': true,
      'client_id': 'YOUR_GOOGLE_CLIENT_ID',
      'server_client_id': 'YOUR_GOOGLE_SERVER_CLIENT_ID',
      'scopes': ['email', 'profile'],
    },
    'microsoft': {
      'enabled': true,
      'client_id': 'YOUR_MICROSOFT_CLIENT_ID',
      'tenant': 'common',
      'scopes': ['openid', 'profile', 'email'],
      'callback_scheme': 'myapp',
    },
    'github': {
      'enabled': false,
      'client_id': 'YOUR_GITHUB_CLIENT_ID',
      'scopes': ['read:user', 'user:email'],
      'callback_scheme': 'myapp',
    },
  },
};
```

Register the config factory inside `Magic.init`:

```dart
await Magic.init(
  config: {
    'social_auth': socialAuthConfig(),
  },
  providers: [
    (app) => SocialAuthServiceProvider(app),
  ],
);
```

> [!TIP]
> Store credentials in environment variables or a secrets manager — never commit raw client IDs to your repository.

---

## <a name="platform-setup"></a>Platform Setup

### Android

Add your Google Services file (`google-services.json`) to `android/app/`. For the callback scheme used by Microsoft and GitHub, add an intent filter to `AndroidManifest.xml`:

```xml
<activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity" android:exported="true">
  <intent-filter android:label="flutter_web_auth_2">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="myapp" />
  </intent-filter>
</activity>
```

### iOS

Add `GoogleService-Info.plist` to `ios/Runner/`. Register the URL scheme for OAuth callbacks in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>
```

### Web

No additional setup is required for the web platform. The Google driver uses the authorization popup flow, and Microsoft/GitHub use `flutter_web_auth_2` with a configurable `web_callback_url`.

---

## <a name="verify-the-installation"></a>Verify the Installation

After setup, run a quick platform support check:

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

// Check if Google is available on the current platform
if (SocialAuth.supports('google')) {
  print('Google Sign In is available');
}
```

---

**Related**

- [Configuration reference](https://magic.fluttersdk.com/packages/social-auth/getting-started/configuration)
- [Drivers](https://magic.fluttersdk.com/packages/social-auth/basics/drivers)
- [Handlers](https://magic.fluttersdk.com/packages/social-auth/basics/handlers)
