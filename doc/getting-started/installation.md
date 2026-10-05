# Installation

Social sign-in for Flutter apps built on the Magic Framework, against the `magic-starter-laravel` backend: native Google and Apple sheets on mobile, a backend-hosted browser flow (PKCE) for GitHub, Microsoft and everything else, on iOS, Android and web.

## Table of Contents

- [Requirements](#requirements)
- [Install the Package](#install-the-package)
- [Run social:install](#run-socialinstall)
- [What social:install Writes](#what-socialinstall-writes)
- [Run social:doctor](#run-socialdoctor)
- [Backend Environment](#backend-environment)
- [Provider Consoles](#provider-consoles)
- [Platform Notes](#platform-notes)
- [Without magic_starter](#without-magic_starter)
- [Manual Setup](#manual-setup)
- [Verify the Installation](#verify-the-installation)

---

## <a name="requirements"></a>Requirements

| Dependency | Version |
|---|---|
| Dart SDK | `^3.12.0` |
| Flutter | `>=3.44.0` |
| magic | `^0.0.24` |
| fluttersdk_artisan | `^0.0.18` |
| Backend | `magic-starter-laravel` with the `social-login` feature on |

The Dart and Flutter floors come from `sign_in_with_apple` 8.2. The package depends on `google_sign_in ^7.2.0`, `sign_in_with_apple ^8.2.0`, `flutter_web_auth_2 ^5.1.0` and `crypto ^3.0.7`.

The backend side (routes, provider keys, the error codes) is documented in magic-starter-laravel's `doc/basics/social-login.md` and `doc/basics/account-deletion.md`; this package is its client and the two must agree on every value listed under [Backend Environment](#backend-environment).

---

## <a name="install-the-package"></a>Install the Package

Add `magic_social_auth` to your `pubspec.yaml`:

```yaml
dependencies:
  magic_social_auth: ^0.0.8
```

Fetch dependencies, then register the package's artisan commands (`social:install`, `social:doctor`):

```bash
flutter pub get
dart run fluttersdk_artisan plugin:install magic_social_auth
```

---

## <a name="run-socialinstall"></a>Run social:install

One non-interactive run leaves the app ready to sign in. Replace the values with your own:

```bash
dart run <app>:artisan social:install \
  --providers=google,apple,github,microsoft \
  --google-ios-client-id=123-abc.apps.googleusercontent.com \
  --google-server-client-id=123-def.apps.googleusercontent.com \
  --ios-scheme=myapp \
  --android-callback=https://auth.example.com/auth/social
```

Preview without writing anything:

```bash
dart run <app>:artisan social:install --dry-run
```

`<app>` is your app's pubspec package name. Every flag is optional; an omitted value is written as an empty string in the config and `social:doctor` names it until you fill it.

### Flags

| Flag | Default | What it does |
|---|---|---|
| `--providers=` | `google,apple,github,microsoft` | Comma-separated providers to enable. Each becomes `enabled: true` in the config, the rest `enabled: false`. An unknown name stops the run. Google and Apple only add their native iOS edits when they are in the list. |
| `--google-ios-client-id=` | empty | The Google iOS OAuth client id (`123-abc.apps.googleusercontent.com`). Written to the config as `google.ios_client_id`, to `Info.plist` as `GIDClientID`, and its reversed form (`com.googleusercontent.apps.123-abc`) is registered as a URL scheme. Needs `google` in `--providers`. |
| `--google-server-client-id=` | empty | The Google web OAuth client id, the audience the backend verifies. Written to the config as `google.server_client_id` and to `Info.plist` as `GIDServerClientID`. Needs `google` in `--providers`. |
| `--ios-scheme=` | empty | The custom URL scheme the browser flow returns to on iOS (`myapp`). Written to the config as `callback.ios` = `myapp://auth/social`. A value that is not a URL scheme stops the run. |
| `--android-callback=` | empty | The https App Link the browser flow returns to on Android (`https://auth.example.com/auth/social`). Written to the config as `callback.android` and declared as the `CallbackActivity` intent filter (host and path). Must be an https URL with a host and a path, without a query or fragment; use a host your app's other App Link filters do not claim (see [Android](#android)). |
| `--force` | off | Overwrite files that were changed since the last install, or that the installer did not write. Without it such a file is reported as a conflict and the run exits 1. |
| `--dry-run` | off | Print every staged operation and write nothing. |
| `--non-interactive` | off | Inherited from every artisan install command. `social:install` asks no questions, so it changes nothing; it is safe to pass in CI. |
| `--no-bootstrap` | off | Inherited from every artisan install command. `social:install` does not read it, and the post-install message is printed either way. |

The Google client ids must look like `123-abc.apps.googleusercontent.com`; anything else stops the run before a file is touched.

Re-running with different flag values rewrites the files the installer created while you have not edited them. A file you edited is reported as a conflict, and `--force` overwrites it.

---

## <a name="what-socialinstall-writes"></a>What social:install Writes

| Target | Written when | Content |
|---|---|---|
| `lib/config/app.dart` | always | `SocialAuthServiceProvider` is added to the providers list. |
| `lib/config/social_auth.dart` | always | The config (see [Configuration](configuration.md)), and `() => socialAuthConfig` is added to `Magic.init`'s `configFactories` in `lib/main.dart`. |
| `ios/Runner/Info.plist` | `google` enabled and `--google-ios-client-id` given | `GIDClientID` and the reversed client id as a `CFBundleURLTypes` scheme. |
| `ios/Runner/Info.plist` | `google` enabled and `--google-server-client-id` given | `GIDServerClientID`. |
| Every entitlements file the iOS app target signs with | `apple` enabled | `com.apple.developer.applesignin` = `[Default]`, merged into any array the file already has. A project that signs with no entitlements file gets `ios/Runner/Runner.entitlements` and the target is pointed at it. |
| `android/app/src/main/AndroidManifest.xml` | `--android-callback` given | The `com.linusu.flutter_web_auth_2.CallbackActivity` activity: `exported="true"`, `taskAffinity=""`, one `autoVerify` intent filter (`VIEW`, `DEFAULT`, `BROWSABLE`, scheme `https`, the callback's host and path). An existing activity with different filters is never rewritten; the install warns with the block it expected. |
| `web/auth.html` | the project has a `web/` directory | The page the web popup posts its result back through. |
| `lib/app/providers/social_auth_starter_service_provider.dart` | `magic_starter` is in `pubspec.yaml` | The bridge that plugs this package into the starter's screens, registered in `lib/config/app.dart`. |

The browser flow's iOS custom scheme is not registered in `Info.plist`: `ASWebAuthenticationSession` delivers the return only to the app that started it. The Android Google sign-in needs no manifest edit.

---

## <a name="run-socialdoctor"></a>Run social:doctor

```bash
dart run <app>:artisan social:doctor
```

Every way of getting the native half wrong is silent: a sign-in sheet that closes at once, a button that does nothing, a review rejection months later. The doctor reads `lib/config/social_auth.dart`, `Info.plist`, the entitlements files the app target signs with, `AndroidManifest.xml`, `web/` and the pubspec, and names what is missing. A section is printed only when the project has that platform. It exits 0 when every check passes and 1 otherwise.

| Section | Checks |
|---|---|
| Config | The config exists; at least one provider is enabled; `google.ios_client_id` and `google.server_client_id` are set when Google is on; `callback.ios` is set when a browser-flow provider needs it on iOS; `callback.android` is set and is an https URL with a host and a path when a browser-flow provider needs it on Android. |
| iOS | `Info.plist` has `GIDClientID`, `GIDServerClientID` and the reversed client id URL scheme; Sign in with Apple is in every entitlements file the app target signs with; Apple is not disabled while another provider is enabled (App Store guideline 4.8 asks an iOS app that offers another third-party sign-in to offer Sign in with Apple too). |
| Android | The `CallbackActivity` is declared with `exported="true"`, `taskAffinity=""` and an `autoVerify` https filter for the callback; no other activity's App Link filter overlaps the callback. |
| Web | `web/auth.html` exists and posts the `flutter-web-auth-2` message back to the app. |
| magic_starter bridge | Only when `magic_starter` is a dependency: the bridge file exists and `SocialAuthStarterServiceProvider` is registered in `lib/config/app.dart`. |

The doctor cannot prove that an Android App Link verifies (Google fetches `assetlinks.json` at install time) or that a provider console lists the callback; those stay a device and a console check.

---

## <a name="backend-environment"></a>Backend Environment

After the checks, the doctor prints the `.env` lines of `magic-starter-laravel` that mirror your config, and the callback each provider console has to list. This is the shape (values come from your config; angle brackets are yours to fill):

```
Backend env (magic-starter-laravel)
  MAGIC_STARTER_SOCIAL_PROVIDERS=google,apple,github,microsoft
  MAGIC_STARTER_SOCIAL_IOS_REDIRECT=myapp://auth/social
  MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT=https://auth.example.com/auth/social
  MAGIC_STARTER_SOCIAL_WEB_REDIRECT=https://<app origin>/auth.html
  MAGIC_STARTER_SOCIAL_GOOGLE_AUDIENCES=123-abc.apps.googleusercontent.com,123-def.apps.googleusercontent.com
  MAGIC_STARTER_SOCIAL_APPLE_AUDIENCES=<ios bundle id>
  MAGIC_STARTER_APPLE_TEAM_ID=
  MAGIC_STARTER_APPLE_KEY_ID=
  MAGIC_STARTER_APPLE_PRIVATE_KEY=
  MAGIC_STARTER_APPLE_BUNDLE_ID=<ios bundle id>
  MAGIC_STARTER_APPLE_SERVICES_ID=
  https://<api host>/magic-starter/social/google/callback
  https://<api host>/magic-starter/social/apple/callback
  https://<api host>/magic-starter/social/github/callback
  https://<api host>/magic-starter/social/microsoft/callback
```

The Apple lines appear only when Apple is enabled, the Google audiences line only when Google is, and one callback URL is printed per enabled provider.

- `MAGIC_STARTER_SOCIAL_IOS_REDIRECT` and `MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT` must equal `social_auth.callback.ios` and `social_auth.callback.android` exactly. The backend takes the redirect target only from its own config, so a mismatch means the browser lands somewhere the app is not listening.
- `MAGIC_STARTER_SOCIAL_WEB_REDIRECT` is the app's own `auth.html`, on the origin the web build is served from.
- The Google audiences are the client ids whose ID tokens the backend accepts: the iOS client id and the web (server) client id.
- The browser flow starts at `<network.drivers.api.base_url>/auth/social/{provider}/redirect`, so the app's `network.drivers.api.base_url` has to be the backend's API base.

---

## <a name="provider-consoles"></a>Provider Consoles

Register the fixed callback URL in every provider console. It does not use the backend's route prefix:

```
https://<api host>/magic-starter/social/{provider}/callback
```

| Provider | In the console |
|---|---|
| Google | A **web** OAuth client with the callback as an authorized redirect URI; its client id is `--google-server-client-id`. An **iOS** OAuth client for the app's bundle id; its client id is `--google-ios-client-id`. An **Android** OAuth client for the app's package name and signing SHA-1. |
| Apple | A **Services ID** with the callback as a return URL (the browser flow runs as this client, for Android and web). A **Sign in with Apple key** (`.p8`) for the Team ID and Key ID. The iOS app's capability for Sign in with Apple (the entitlement `social:install` writes). Optionally, `https://<api host>/magic-starter/social/apple/notifications` as the server-to-server notification endpoint. |
| GitHub | An **OAuth app** whose authorization callback URL is the callback. |
| Microsoft | An **Entra app registration** with the **Web** platform and the callback as a redirect URI. The backend uses the `common` tenant unless `MICROSOFT_TENANT` says otherwise. |

Client secrets and Apple's key live in the backend's environment, never in the Flutter app. See magic-starter-laravel's `doc/basics/social-login.md` for the `config/services.php` keys.

---

## <a name="platform-notes"></a>Platform Notes

### iOS

- Google and Apple sign in through their native sheets. GitHub and Microsoft open `ASWebAuthenticationSession` and return through the custom scheme from `--ios-scheme`.
- The callback is a custom scheme on purpose: an https callback needs iOS 17.4. `ASWebAuthenticationSession` delivers the return only to the app that started it, so a custom scheme is safe.
- Confirming an identity (the step-up) opens an ephemeral session, so the provider asks for the account again instead of waving a remembered one through.
- Sign in with Apple hands out the user's name on the first authorization only. `AppleSignInResult.givenName` and `familyName` carry it; pass them on to a profile update or they are lost.

### Android

- Google signs in through the native Credential Manager; Apple, GitHub and Microsoft use the browser flow.
- The callback is an https App Link on a **dedicated host** (`auth.example.com`), not the app's main domain. The app's other App Link filters must not claim that host: when one does, Android may open that activity instead of the callback activity, and `social:doctor` flags the overlap.
- The host must serve a Digital Asset Links file (`/.well-known/assetlinks.json`) for the app, since the filter is `autoVerify`.
- An Auth Tab whose App Link verification failed closes at once and reports a plain cancel (flutter_web_auth_2 issue 215), so a cancel is not always the user's. The cancel copy invites a retry.
- A misconfigured Google client (SHA-1, package name, `server_client_id`) is also reported as a cancel by the SDK.
- The package never sets `preferEphemeral` on Android.

### Web

- All four providers use the browser flow in a popup. `web/auth.html` receives the callback inside the popup and posts it back to the app.
- The popup must open from the tap itself: call `SocialAuth.driver(name).signIn()` straight from the tap handler, with no `await` before it. `SocialAuthButtons` calls `onPressed` synchronously for this reason.
- Do not serve the app shell or `auth.html` with `Cross-Origin-Opener-Policy: same-origin`. It severs the popup's link to the app (`window.opener`), which is how the result gets back.
- A new click supersedes a popup that is still pending; only the newest flow spends its code.

### macOS, Windows, Linux

Not supported. `SocialAuth.supports(name)` answers `false` and `SocialAuthButtons` renders nothing for the provider.

---

## <a name="without-magic_starter"></a>Without magic_starter

The package works on its own: the drivers answer a `SocialAuthResult` and the app decides what a session, a 2FA challenge or a cancelled deletion means (see [Flows](../basics/flows.md)). Without `magic_starter` there is no bridge, so the app owns one more thing: **sign Google out on its own sign-out.** The Google SDK keeps its own session; if it is not signed out, the next sign-in skips the account picker. The bridge does this for starter apps on every transition to signed-out. In an app without it:

```dart
Auth.stateNotifier.addListener(() {
  if (!Auth.check()) {
    unawaited(SocialAuth.driver('google').signOut());
  }
});
```

Call the driver by name rather than `SocialAuth.signOut()`: the manager only signs out drivers it has cached in this process, and a session restored at boot has created none. Guard the call to `google` being enabled and the platform being iOS or Android.

---

## <a name="manual-setup"></a>Manual Setup

`social:install` is the supported path. To wire it by hand: register the provider and the config factory,

```dart
// lib/config/app.dart
(app) => SocialAuthServiceProvider(app),
```

```dart
// lib/main.dart
await Magic.init(
  configFactories: [
    () => appConfig,
    () => socialAuthConfig,
  ],
);
```

and make the native edits listed under [What social:install Writes](#what-socialinstall-writes). `SocialAuthServiceProvider` must come after your auth provider, because `SocialAuthManager.createUser` delegates to `Auth.manager.createUser`.

---

## <a name="verify-the-installation"></a>Verify the Installation

```dart
import 'package:magic_social_auth/magic_social_auth.dart';

if (SocialAuth.supports('google')) {
  // Google is available on this platform.
}
```

Then run `social:doctor` and sign in once per provider on a device.

---

**Related**

- [Configuration reference](configuration.md)
- [Drivers](../basics/drivers.md)
- [Flows](../basics/flows.md)
- [Architecture overview](../architecture/overview.md)
