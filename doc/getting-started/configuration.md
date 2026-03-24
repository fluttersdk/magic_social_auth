# Configuration

The `social_auth` config file controls which providers are active, their OAuth credentials, platform-specific behavior, and UI rendering options for the `SocialAuthButtons` widget.

## Table of Contents

- [Full Config Structure](#full-config-structure)
- [Top-level Keys](#top-level-keys)
- [Provider Options](#provider-options)
- [Provider-specific Options](#provider-specific-options)
- [UI Overrides](#ui-overrides)
- [Minimal Example](#minimal-example)

---

## <a name="full-config-structure"></a>Full Config Structure

```dart
Map<String, dynamic> socialAuthConfig() => {
  // Backend endpoint. {provider} is replaced at runtime.
  'endpoint': '/auth/social/{provider}',

  'providers': {
    'google': {
      'enabled': true,
      'client_id': 'YOUR_CLIENT_ID.apps.googleusercontent.com',
      'server_client_id': 'YOUR_SERVER_CLIENT_ID.apps.googleusercontent.com',
      'scopes': ['email', 'profile'],
      // UI
      'label': 'Google',
      'order': 1,
    },
    'microsoft': {
      'enabled': true,
      'client_id': 'YOUR_AZURE_APP_CLIENT_ID',
      'tenant': 'common',
      'scopes': ['openid', 'profile', 'email'],
      'callback_scheme': 'myapp',
      'web_callback_url': 'https://myapp.com/auth/callback',
      // UI
      'label': 'Microsoft',
      'order': 2,
    },
    'github': {
      'enabled': true,
      'client_id': 'YOUR_GITHUB_CLIENT_ID',
      'scopes': ['read:user', 'user:email'],
      'callback_scheme': 'myapp',
      'web_callback_url': 'https://myapp.com/auth/callback',
      // UI
      'label': 'GitHub',
      'order': 3,
    },
  },
};
```

---

## <a name="top-level-keys"></a>Top-level Keys

| Key | Type | Default | Description |
|---|---|---|---|
| `endpoint` | `String` | `/auth/social/{provider}` | Backend URL. `{provider}` is replaced by driver name at runtime (e.g., `/auth/social/google`). Used by the default `HttpSocialAuthHandler`. |

---

## <a name="provider-options"></a>Provider Options

These keys apply to every provider:

| Key | Type | Default | Description |
|---|---|---|---|
| `enabled` | `bool` | `true` | When `false`, the provider is skipped by `SocialAuthButtons` and throws `ProviderNotConfiguredException` if resolved via `SocialAuth.driver()`. |
| `client_id` | `String` | — | OAuth client ID. Required for Microsoft and GitHub; optional for Google on Android (read from `google-services.json`). |
| `scopes` | `List<String>` | driver default | OAuth scopes to request. |
| `callback_scheme` | `String` | `uptizm` | URL scheme for the OAuth redirect on mobile. Must match the scheme registered in `AndroidManifest.xml` / `Info.plist`. Used by Microsoft and GitHub drivers. |
| `web_callback_url` | `String` | `http://localhost:8080/auth/callback` | Full redirect URL for the web platform. Used by Microsoft and GitHub drivers. |

---

## <a name="provider-specific-options"></a>Provider-specific Options

### Google

| Key | Type | Default | Description |
|---|---|---|---|
| `server_client_id` | `String` | — | Server-side OAuth client ID. Used on mobile to request an ID token for backend verification. Ignored on web. |

### Microsoft

| Key | Type | Default | Description |
|---|---|---|---|
| `tenant` | `String` | `common` | Azure AD tenant. Use `common` for multi-tenant apps, or your directory tenant ID for single-tenant apps. |

### GitHub

No provider-specific options beyond the common set.

---

## <a name="ui-overrides"></a>UI Overrides

These keys are read by `SocialAuthButtons` to customise the rendered button. When omitted, the widget falls back to built-in defaults (icon SVG, label, order).

| Key | Type | Description |
|---|---|---|
| `label` | `String` | Display name shown on the button (e.g., `'Sign in with Google'`). |
| `icon_svg` | `String` | Raw SVG string rendered as the button icon. Overrides the built-in icon. |
| `icon_class` | `String` | CSS/Tailwind class applied to the icon element. Defaults to `'w-5 h-5'`. |
| `order` | `int` | Rendering order. Lower values appear first. Defaults to insertion order. |

> [!TIP]
> For custom providers registered via `SocialAuth.manager.extend()`, call `SocialAuth.manager.registerProviderDefaults()` instead of config-level UI overrides so the defaults are always available regardless of config state.

---

## <a name="minimal-example"></a>Minimal Example

Google-only setup with default scopes and no UI customisation:

```dart
Map<String, dynamic> socialAuthConfig() => {
  'endpoint': '/auth/social/{provider}',
  'providers': {
    'google': {
      'enabled': true,
      'server_client_id': 'YOUR_SERVER_CLIENT_ID.apps.googleusercontent.com',
    },
  },
};
```

Register via `Magic.init`:

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

---

**Related**

- [Installation](https://magic.fluttersdk.com/packages/social-auth/getting-started/installation)
- [Drivers](https://magic.fluttersdk.com/packages/social-auth/basics/drivers)
- [Handlers](https://magic.fluttersdk.com/packages/social-auth/basics/handlers)
