# Configuration

The `social_auth` config decides which providers are on, which Google client ids the native SDK uses, and where the browser flow returns to on each platform. `social:install` writes it to `lib/config/social_auth.dart`; every value is read at runtime through `Config.get`.

## Table of Contents

- [Full Config Structure](#full-config-structure)
- [Providers](#providers)
- [Callbacks](#callbacks)
- [UI Overrides](#ui-overrides)
- [Keys Owned by Other Packages](#keys-owned-by-other-packages)
- [Minimal Example](#minimal-example)
- [Removed Keys](#removed-keys)

---

## <a name="full-config-structure"></a>Full Config Structure

This is what `social:install --providers=google,apple,github,microsoft --google-ios-client-id=123-abc.apps.googleusercontent.com --google-server-client-id=123-def.apps.googleusercontent.com --ios-scheme=myapp --android-callback=https://auth.example.com/auth/social` writes:

```dart
// What `dart run <app>:artisan social:doctor` checks, and the values it prints
// for the backend: the callbacks below must equal the backend's
// MAGIC_STARTER_SOCIAL_IOS_REDIRECT and MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT.
Map<String, dynamic> get socialAuthConfig => {
  'social_auth': {
    'providers': {
      'google': {
        'enabled': true,
        'ios_client_id': '123-abc.apps.googleusercontent.com',
        'server_client_id': '123-def.apps.googleusercontent.com',
      },
      'apple': {
        'enabled': true,
      },
      'github': {
        'enabled': true,
      },
      'microsoft': {
        'enabled': true,
      },
    },

    'callback': {
      'ios': 'myapp://auth/social',
      'android': 'https://auth.example.com/auth/social',
    },
  },
};
```

`social:doctor` reads this file back with a textual scan, so keep provider entries and `callback` flat maps of string and bool literals.

---

## <a name="providers"></a>Providers

`social_auth.providers.<name>` for `google`, `apple`, `github` and `microsoft`.

| Key | Type | Default | Description |
|---|---|---|---|
| `enabled` | `bool` | `true` | When `false`, `SocialAuthButtons` skips the provider and `SocialAuth.driver(name)` throws `ProviderNotConfiguredException`. |

### Google

| Key | Type | Default | Description |
|---|---|---|---|
| `ios_client_id` | `String` | none | The Google iOS OAuth client id. Read on iOS only (Android reads its client from the signing key). It must also be in `Info.plist` as `GIDClientID`; `social:install` writes both. |
| `server_client_id` | `String` | none | The Google web OAuth client id. It is the audience of the ID token the backend verifies, so it must be in `MAGIC_STARTER_SOCIAL_GOOGLE_AUDIENCES`. Without it Google returns no ID token and the driver throws a `SocialAuthException` that names this key. |

### Apple, GitHub, Microsoft

No keys beyond `enabled`. Their client ids and secrets live in the backend: the app only opens the sheet (Apple on iOS) or the backend's browser flow (everything else).

---

## <a name="callbacks"></a>Callbacks

`social_auth.callback.<platform>` is where the backend sends the browser when a browser flow ends. It must equal the backend's redirect target for the same platform.

| Key | Type | Backend env | Description |
|---|---|---|---|
| `callback.ios` | `String` | `MAGIC_STARTER_SOCIAL_IOS_REDIRECT` | A custom scheme URL: `myapp://auth/social`. The scheme is what the app listens on. An https callback would need iOS 17.4. |
| `callback.android` | `String` | `MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT` | An https App Link: `https://auth.example.com/auth/social`. Its host and path become the Auth Tab's `httpsHost` and `httpsPath`, and the `CallbackActivity` intent filter. Use a dedicated host that no other App Link filter in the app claims. |

There is no web key: the web flow lands on the app's own `/auth.html` (the backend's `MAGIC_STARTER_SOCIAL_WEB_REDIRECT`).

A flow that needs a callback which is empty throws a `SocialAuthException` that names the key (`Set social_auth.callback.ios to the URL the backend redirects ios to.`). A callback is needed by GitHub and Microsoft on iOS and Android, and by Apple on Android. Google and Apple on iOS use native sheets, Google on Android does too, and the web needs no callback key.

---

## <a name="ui-overrides"></a>UI Overrides

Read by `SocialAuthButtons` from each provider's entry. When omitted, the widget falls back to the built-in defaults.

| Key | Type | Description |
|---|---|---|
| `label` | `String` | Name shown on the button (`Google` becomes `Sign in with Google` through `auth.sign_in_with`). |
| `icon_svg` | `String` | Raw SVG string for the icon. Overrides the built-in one. |
| `icon_class` | `String` | Class applied to the icon element. Defaults to `w-5 h-5`. |
| `order` | `int` | Rendering order, lower first. Built-in order is Google 1, Microsoft 2, GitHub 3, Apple 4. On iOS Apple is always first, as Apple's review guidelines expect. |

> [!TIP]
> For a custom provider registered with `SocialAuth.manager.extend()`, call `SocialAuth.manager.registerProviderDefaults()` instead of per-config overrides, so the defaults are available regardless of config state.

---

## <a name="keys-owned-by-other-packages"></a>Keys Owned by Other Packages

| Key | Owner | Used for |
|---|---|---|
| `network.drivers.api.base_url` | magic | The backend base URL. The browser flow starts at `<base_url>/auth/social/{provider}/redirect`, and the native and exchange calls go through the same `Http` facade, so the auth interceptor attaches the bearer a connect or confirm needs. |
| `auth.sign_in_with`, `auth.sign_up_with` | translations | Button labels. |

---

## <a name="minimal-example"></a>Minimal Example

Google and GitHub only, no Apple, no Android browser flow:

```dart
Map<String, dynamic> get socialAuthConfig => {
  'social_auth': {
    'providers': {
      'google': {
        'enabled': true,
        'ios_client_id': '123-abc.apps.googleusercontent.com',
        'server_client_id': '123-def.apps.googleusercontent.com',
      },
      'github': {
        'enabled': true,
      },
    },
    'callback': {
      'ios': 'myapp://auth/social',
      'android': '',
    },
  },
};
```

Register it in `Magic.init`:

```dart
await Magic.init(
  configFactories: [
    () => appConfig,
    () => socialAuthConfig,
  ],
);
```

> [!NOTE]
> `social:doctor` fails an empty `callback.android` on an Android project as soon as GitHub is enabled, because GitHub signs in through the browser flow there.

---

## <a name="removed-keys"></a>Removed Keys

0.0.8 removed the top-level `social_auth.endpoint` and, per provider, `client_id`, `scopes`, `tenant`, and the keys that named a mobile URL scheme and a web callback URL for the old OAuth flow. The backend now owns scopes, tenants and client ids, and the callbacks are the two `callback.*` keys above. Delete the old keys from your config; they are read nowhere.

---

**Related**

- [Installation](installation.md)
- [Drivers](../basics/drivers.md)
- [Flows](../basics/flows.md)
