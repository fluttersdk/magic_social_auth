# fluttersdk_magic_social_auth

Social authentication plugin for Magic Framework with Laravel Socialite-style API.

## Features

- ✅ Laravel Socialite-style `SocialAuth.driver('google')` API
- ✅ Platform-aware drivers (iOS, Android, Web)
- ✅ Extensible with custom drivers via `extend()`
- ✅ Customizable auth handler for Firebase, Supabase, etc.
- ✅ Built-in: Google, Microsoft, GitHub

---

## Installation

### 1. Add Dependency

```yaml
# pubspec.yaml
dependencies:
  fluttersdk_magic_social_auth:
    path: ./plugins/fluttersdk_magic_social_auth
```

```bash
flutter pub get
```

### 2. Register Service Provider

```dart
// lib/config/app.dart
import 'package:fluttersdk_magic_social_auth/fluttersdk_magic_social_auth.dart';

Map<String, dynamic> get appConfig => {
  'app': {
    'providers': [
      // ... other providers
      (app) => SocialAuthServiceProvider(app),
    ],
  },
};
```

### 3. Create Config File

```dart
// lib/config/social_auth.dart
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

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

### 4. Register Config in main.dart

```dart
// lib/main.dart
import 'config/social_auth.dart';

await Magic.init(
  configFactories: [
    () => appConfig,
    () => authConfig,
    () => socialAuthConfig, // Add this
  ],
);
```

> **Note:** The plugin automatically uses your app's user factory from
> `Auth.manager.setUserFactory()` - no separate configuration needed!

---

## OAuth Credentials Setup

### Google Cloud Console

Google OAuth requires **different OAuth clients for each platform**. Here's why:

| Client Type | Used For | Token Flow |
|-------------|----------|------------|
| **Web Application** | Browser-based auth (Web platform) | User authenticates → access token returned |
| **iOS** | Native iOS app | Native SDK → access token + id token |
| **Android** | Native Android app | Native SDK → access token + id token |
| **Server/Backend** | Backend token verification | Verifies tokens from mobile apps |

#### Understanding the Flow

**Mobile (iOS/Android):**
```
Flutter App (Native SDK) → Google → Access Token + ID Token
                                    ↓
                          POST to Backend /auth/social/google
                                    ↓
        Backend verifies with Socialite using serverClientId
                                    ↓
                          Returns Sanctum token
```

**Web:**
```
Flutter App (Browser) → Google OAuth Popup → Access Token
                                    ↓
                    POST to Backend /auth/social/google
                                    ↓
                Backend verifies with Socialite
                                    ↓
                        Returns Sanctum token
```

#### Step-by-Step Setup

1. **Go to [Google Cloud Console](https://console.cloud.google.com)**
2. Create a new project or select existing
3. **Enable Google Sign-In API**:
   - APIs & Services → Library → Search "Google Sign-In" → Enable

4. **Create OAuth Credentials** (you need multiple clients):

   **Web Application Client (Required for Web + Backend verification):**
   - APIs & Services → Credentials → Create OAuth client ID
   - Application type: **Web application**
   - Name: `Your App (Web + Backend)`
   - **Authorized JavaScript origins:**
     ```
     http://localhost:61883
     http://localhost
     https://yourapp.com
     ```
   - **Authorized redirect URIs:**
     ```
     http://localhost:61883
     http://localhost:61883/
     https://yourapp.com
     https://yourapp.com/
     ```
   - Copy **Client ID** and **Client Secret**
   - This is your **server/backend client** and **web client**

   **iOS Client (Required for iOS app):**
   - Create OAuth client ID → Application type: **iOS**
   - Bundle ID: Get from `ios/Runner/Info.plist` (e.g., `com.yourcompany.yourapp`)
   - Download `GoogleService-Info.plist` (optional, not required for this plugin)
   - Copy **Client ID** → This is your iOS `GOOGLE_CLIENT_ID`

   **Android Client (Required for Android app):**
   - Create OAuth client ID → Application type: **Android**
   - Package name: Get from `android/app/src/main/AndroidManifest.xml`
   - SHA-1 certificate fingerprint:
     ```bash
     # For debug builds (development)
     cd android
     ./gradlew signingReport
     # Copy SHA1 from "Variant: debug" section

     # For release builds (production)
     keytool -list -v -keystore your-release-key.keystore -alias your-alias
     ```
   - Copy **Client ID** → This is your Android `GOOGLE_CLIENT_ID`

#### Environment Variables Setup

After creating the OAuth clients, update your `.env` files:

**Flutter `.env`:**
```env
# For Web: Use the web/backend client ID
# For iOS: Use the iOS client ID
# For Android: Use the Android client ID
GOOGLE_CLIENT_ID=your-platform-specific-client-id

# Server client ID (backend OAuth client) - used by mobile for token verification
GOOGLE_SERVER_CLIENT_ID=your-web-backend-client-id
```

**Backend `.env` (Laravel):**
```env
# Use the web/backend client credentials
GOOGLE_CLIENT_ID=your-web-backend-client-id
GOOGLE_CLIENT_SECRET=your-web-backend-client-secret
GOOGLE_REDIRECT_URI=  # Empty for stateless token flow
```

**Backend `config/services.php`:**
```php
'google' => [
    'client_id' => env('GOOGLE_CLIENT_ID'),
    'client_secret' => env('GOOGLE_CLIENT_SECRET'),
    'redirect' => env('GOOGLE_REDIRECT_URI'), // Not used with stateless()->userFromToken()
],
```

#### Platform-Specific Configuration

**Option A: Single Client ID (Simple, Web-only):**
```env
# Use the web/backend client for all platforms (works for web only)
GOOGLE_CLIENT_ID=357275154402-xxx.apps.googleusercontent.com
GOOGLE_SERVER_CLIENT_ID=357275154402-xxx.apps.googleusercontent.com
```

**Option B: Platform-Aware (Proper, supports all platforms):**
```dart
// lib/config/social_auth.dart
Map<String, dynamic> get socialAuthConfig => {
  'social_auth': {
    'providers': {
      'google': {
        'enabled': true,
        // Select client_id based on platform
        'client_id': kIsWeb
            ? env('GOOGLE_WEB_CLIENT_ID')
            : Platform.isIOS
                ? env('GOOGLE_IOS_CLIENT_ID')
                : env('GOOGLE_ANDROID_CLIENT_ID'),
        'server_client_id': env('GOOGLE_SERVER_CLIENT_ID'),
        'scopes': ['email', 'profile'],
      },
    },
  },
};
```

> **Important Notes:**
> - `GOOGLE_CLIENT_ID` = Platform-specific OAuth client (web/iOS/Android)
> - `GOOGLE_SERVER_CLIENT_ID` = Backend OAuth client (only used by mobile)
> - Web doesn't use `serverClientId` (the plugin automatically sets it to null on web)
> - All OAuth clients must be from the **same Google Cloud project**

---

### Microsoft Azure Portal

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations** → **New registration**

3. Register your application:
   - Name: `Your App Name`
   - Supported account types: **Accounts in any organizational directory and personal Microsoft accounts**
   - Redirect URI: Select **Mobile and desktop applications** → `myapp://callback`

4. After creation:
   - Copy **Application (client) ID** → This is your `MICROSOFT_CLIENT_ID`
   - Copy **Directory (tenant) ID** → This is your `MICROSOFT_TENANT` (or use `common` for multi-tenant)

5. Add platform configurations:
   - Authentication → Add a platform
   - **iOS/macOS:** Bundle ID from Xcode
   - **Android:** Package name + Signature hash
   - **Web:** Redirect URI

6. API Permissions:
   - API permissions → Add permission → Microsoft Graph
   - Select: `openid`, `profile`, `email`, `User.Read`
   - Grant admin consent (if required)

> **Tenant Options:**
>
> - `common` - Any Microsoft account (personal + work/school)
> - `organizations` - Work/school accounts only
> - `consumers` - Personal Microsoft accounts only
> - `{tenant-id}` - Specific organization only

---

### GitHub Developer Settings

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click **OAuth Apps** → **New OAuth App**

3. Fill in the form:
   - Application name: `Your App Name`
   - Homepage URL: `https://yourapp.com`
   - Authorization callback URL: `myapp://callback`

4. After creation:
   - Copy **Client ID** → This is your `GITHUB_CLIENT_ID`
   - Generate **Client Secret** → Store securely on your backend (NOT in Flutter app!)

5. For multiple environments:
   - Create separate OAuth Apps for development and production
   - Development callback: `myapp://callback` or `http://localhost:3000/callback`
   - Production callback: `https://yourapp.com/callback`

> **Security Note:** GitHub requires the client secret for token exchange.
> This should happen on your backend, not in the Flutter app!

---

## Callback Scheme

The `callback_scheme` in your config (e.g., `myapp`) must match:

| Platform | Location |
|----------|----------|
| iOS | `Info.plist` → `CFBundleURLSchemes` |
| Android | `AndroidManifest.xml` → `intent-filter` → `data android:scheme` |
| OAuth Provider | Redirect URI in Google/Microsoft/GitHub console |

Example flow:

```
1. App opens: https://github.com/login/oauth/authorize?redirect_uri=myapp://callback
2. User authenticates
3. GitHub redirects to: myapp://callback?code=abc123
4. App receives the callback and extracts the code
```

---

## Platform Configuration

### Google Sign-In

#### iOS Setup

1. Download `GoogleService-Info.plist` from [Firebase Console](https://console.firebase.google.com)
2. Add to `ios/Runner/`
3. Update `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Reversed client ID from GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

#### Android Setup

1. Download `google-services.json` from [Firebase Console](https://console.firebase.google.com)
2. Add to `android/app/`
3. Update `android/build.gradle`:

```gradle
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
  }
}
```

1. Update `android/app/build.gradle`:

```gradle
apply plugin: 'com.google.gms.google-services'
```

#### Web Setup

1. Add client ID to `web/index.html`:

```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
```

1. Load Google Sign-In SDK:

```html
<script src="https://accounts.google.com/gsi/client" async defer></script>
```

---

### Microsoft & GitHub (flutter_web_auth_2)

#### iOS Setup

Add URL scheme to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string> <!-- Must match callback_scheme in config -->
    </array>
  </dict>
</array>
```

#### Android Setup

Add intent filter to `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
    android:exported="true">
    <intent-filter android:label="flutter_web_auth_2">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="myapp" /> <!-- Must match callback_scheme -->
    </intent-filter>
</activity>
```

#### Web Setup

Create `web/auth.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <title>Authentication Complete</title>
</head>
<body>
  <script>
    window.opener.postMessage(window.location.href, window.location.origin);
    window.close();
  </script>
</body>
</html>
```

---

## Environment Variables

### Flutter `.env`

Add to your `.env` file:

```env
# Google (see OAuth setup section for details)
GOOGLE_CLIENT_ID=your-platform-specific-client-id
GOOGLE_SERVER_CLIENT_ID=your-web-backend-client-id

# Or platform-aware (recommended for production)
GOOGLE_WEB_CLIENT_ID=357275154402-web.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=357275154402-ios.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=357275154402-android.apps.googleusercontent.com
GOOGLE_SERVER_CLIENT_ID=357275154402-web.apps.googleusercontent.com

# Microsoft
MICROSOFT_CLIENT_ID=your-azure-app-client-id
MICROSOFT_TENANT=common

# GitHub
GITHUB_CLIENT_ID=your-github-oauth-app-client-id
```

### Backend `.env` (Laravel)

```env
# Google - Use web/backend client credentials
GOOGLE_CLIENT_ID=357275154402-web.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxx
GOOGLE_REDIRECT_URI=  # Empty for stateless token flow

# Microsoft (if using Socialite)
MICROSOFT_CLIENT_ID=your-azure-app-client-id
MICROSOFT_CLIENT_SECRET=your-azure-app-client-secret

# GitHub (if using Socialite)
GITHUB_CLIENT_ID=your-github-oauth-app-client-id
GITHUB_CLIENT_SECRET=your-github-oauth-app-client-secret
```

---

## Usage

### Basic Authentication

```dart
// In your controller
await SocialAuth.driver('google').authenticate();
await SocialAuth.driver('microsoft').authenticate();
await SocialAuth.driver('github').authenticate();
```

### Check Platform Support

```dart
if (SocialAuth.supports('google')) {
  // Show Google button
}
```

### Custom Driver

```dart
// Register in ServiceProvider.boot()
SocialAuth.manager.extend('apple', (config) => AppleDriver(config));

// Use
await SocialAuth.driver('apple').authenticate();
```

### Custom Auth Handler

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

// Register
SocialAuth.manager.setHandler(FirebaseAuthHandler());
```

---

## Backend (Laravel)

### Installation

```bash
composer require laravel/socialite
composer require socialiteproviders/microsoft
```

### Endpoint Example

```php
// routes/api.php
Route::post('/auth/social/{provider}', [SocialAuthController::class, 'authenticate']);

// app/Http/Controllers/SocialAuthController.php
public function authenticate(Request $request, string $provider)
{
    $validated = $request->validate([
        'access_token' => 'required|string',
        'id_token' => 'nullable|string',
    ]);

    $socialUser = Socialite::driver($provider)
        ->stateless()
        ->userFromToken($validated['access_token']);

    $user = User::firstOrCreate(
        ['email' => $socialUser->getEmail()],
        ['name' => $socialUser->getName()]
    );

    $token = $user->createToken('api')->plainTextToken;

    return response()->json([
        'data' => [
            'token' => $token,
            'user' => $user,
        ],
    ]);
}
```

---

## Troubleshooting

### Error: "redirect_uri_mismatch" (Web)

**Problem:** Google OAuth popup shows "Error 400: redirect_uri_mismatch"

**Cause:** The redirect URI isn't authorized in Google Cloud Console

**Solution:**
1. Go to Google Cloud Console → Credentials
2. Click your web OAuth client
3. Add these to **Authorized redirect URIs**:
   ```
   http://localhost:YOUR_PORT
   http://localhost:YOUR_PORT/
   ```
4. Add these to **Authorized JavaScript origins**:
   ```
   http://localhost:YOUR_PORT
   http://localhost
   ```
5. Save and try again (may take a few minutes to propagate)

### Error: "serverClientId is not supported on Web"

**Problem:** Assertion error when running on web: `serverClientId is not supported on Web`

**Cause:** The plugin was passing `serverClientId` to Google Sign In on web platform

**Solution:** This is fixed in v1.0.0+. The plugin now automatically sets `serverClientId` to `null` on web:
```dart
await GoogleSignIn.instance.initialize(
  clientId: clientId,
  serverClientId: kIsWeb ? null : serverClientId, // ✅ Conditional
);
```

### Error: "Social login failed" (No details)

**Problem:** Generic error message with no specific details

**Common causes:**
1. **Backend not running** - Start Laravel: `cd back-end && php artisan serve`
2. **Wrong API URL** - Check `.env` `API_URL` matches backend URL
3. **Missing Socialite config** - Check `back-end/config/services.php` has provider config
4. **CORS issue** - Check Laravel CORS settings allow your frontend origin

**Debug steps:**
```bash
# 1. Check backend is running
curl http://localhost:8000/api/health

# 2. Check backend logs
tail -f back-end/storage/logs/laravel.log

# 3. Check Flutter console for detailed error
flutter run -d chrome --verbose
```

### Google Sign In shows cached account (no account picker)

**Problem:** Clicking "Sign in with Google" auto-selects the previous account without showing picker

**Cause:** Google session is cached and not cleared on logout

**Solution:** Ensure `SocialAuth.signOut()` is called on logout:
```dart
Future<void> doLogout() async {
  await SocialAuth.signOut(); // ✅ Clears Google session
  await Auth.logout();
  MagicRoute.to('/auth/login');
}
```

### iOS: Google Sign In not working

**Common issues:**
1. **Missing Bundle ID** in Google Cloud Console OAuth client
2. **Wrong Bundle ID** - must match `ios/Runner/Info.plist`
3. **Missing URL scheme** in `Info.plist` (required for some flows)

**Check:**
```bash
# Get your Bundle ID
cat ios/Runner/Info.plist | grep -A 1 CFBundleIdentifier
```

### Android: Google Sign In not working

**Common issues:**
1. **Wrong SHA-1 fingerprint** in Google Cloud Console
2. **Wrong package name** - must match `AndroidManifest.xml`
3. **Debug vs Release SHA-1** - use debug SHA-1 for development

**Get debug SHA-1:**
```bash
cd android
./gradlew signingReport
# Look for "Variant: debug" → "SHA1"
```

---

## API Reference

### SocialAuth Facade

| Method | Description |
|--------|-------------|
| `driver(String name)` | Get driver by name |
| `supports(String name)` | Check if provider supports current platform |
| `manager` | Access the manager instance |

### SocialAuthManager

| Method | Description |
|--------|-------------|
| `extend(name, factory)` | Register custom driver |
| `setHandler(handler)` | Set custom auth handler |
| `createUser(data)` | Create user (delegates to Auth.manager) |

### SocialDriver

| Property | Description |
|----------|-------------|
| `name` | Driver name |
| `supportedPlatforms` | Set of supported platforms |
| `supportsPlatform()` | Check current platform |
| `getToken()` | Get token from provider |
| `authenticate()` | Full auth flow |
