# Drivers

A driver runs one provider's flow and answers what the backend concluded. It never logs the app in itself: it returns a `SocialAuthResult`, and the caller decides what a session, a 2FA challenge or a cancelled deletion means (see [Flows](flows.md)). `SocialAuthManager` resolves drivers by name and caches them for the lifetime of the app.

## Table of Contents

- [SocialDriver Contract](#socialdriver-contract)
- [SocialAuthResult](#socialauthresult)
- [Built-in Drivers](#built-in-drivers)
- [Platform Support Matrix](#platform-support-matrix)
- [Registering a Custom Driver](#registering-a-custom-driver)

---

## <a name="socialdriver-contract"></a>SocialDriver Contract

```dart
abstract class SocialDriver {
  SocialDriver(this.config, {SocialPlatform? platform});

  final Map<String, dynamic> config;   // social_auth.providers.<name>
  final SocialPlatform platform;

  /// The provider name the backend routes on ('google', 'github', ...).
  String get name;

  Set<SocialPlatform> get supportedPlatforms;
  bool supportsPlatform([SocialPlatform? platform]);

  /// Signs in, or registers, with the provider.
  Future<SocialAuthResult> signIn();

  /// Prepares a connect and returns the call that opens the provider.
  Future<Future<SocialAuthResult> Function()> beginConnect(
    Map<String, String>? proof,
  );

  /// Links the provider to the signed-in account in one go.
  Future<SocialAuthResult> connect(Map<String, String>? proof);

  /// Re-authenticates with a linked provider for a step-up proof.
  Future<SocialAuthResult> confirm();

  /// Ends the provider SDK's own session, if it keeps one. Default is a no-op.
  Future<void> signOut();
}
```

| Method | Backend intent | Answer carries |
|---|---|---|
| `signIn()` | `signin` | `token` and `user`, or `isTwoFactor` and `twoFactorToken`; `deletionCancelled` when the sign-in cancelled a scheduled deletion. |
| `beginConnect(proof)` / `connect(proof)` | `connect` | `connectedProvider`. Needs the caller's bearer token. |
| `confirm()` | `confirm` | `confirmationToken`, a single-use step-up proof. Needs the caller's bearer token. |

`proof` is the step-up field the account can give: `{'password': ...}`, `{'code': ...}` or `{'confirmation_token': ...}`; `null` for a guest, who sends none. It is minted for this one call; never cache or reuse it.

`beginConnect` exists for the web. A connect needs a link ticket first, which is a network request; a popup opened after an `await` is blocked as not user-initiated. So `beginConnect` does everything that needs the network and returns the call that opens the provider before its own first `await`. Run it from a fresh tap (an explicit "Continue to GitHub" button) and the popup opens. `connect(proof)` is `beginConnect` followed by the opener in one go, for mobile.

On the web a `signIn()` opens the popup in the same synchronous run as the call, so call it straight from the tap handler with no `await` before it.

```dart
final SocialDriver driver = SocialAuth.driver('github');

// Sign in
final SocialAuthResult result = await driver.signIn();

// Connect (mobile)
await driver.connect({'password': currentPassword});

// Connect (web): prepare, then open from a second tap
final Future<SocialAuthResult> Function() open = await driver.beginConnect(proof);
// ...in the next tap handler:
final SocialAuthResult linked = await open();
```

---

## <a name="socialauthresult"></a>SocialAuthResult

| Field | Type | Set by |
|---|---|---|
| `token` | `String?` | A completed sign-in: the Sanctum token. |
| `user` | `Map<String, dynamic>?` | A completed sign-in: the user resource. |
| `isTwoFactor` | `bool` | A sign-in on an account with confirmed 2FA. |
| `twoFactorToken` | `String?` | Same: finish at `auth/two-factor-challenge` with it. |
| `deletionCancelled` | `bool` | A sign-in that cancelled a scheduled account deletion. |
| `connectedProvider` | `String?` | A connect. |
| `confirmationToken` | `String?` | A confirm. |

`AppleSignInResult` extends it with `givenName` and `familyName`: Apple shares the name on the first authorization only and never puts it in the ID token, so pass it on to a profile update or it is lost.

---

## <a name="built-in-drivers"></a>Built-in Drivers

The manager picks the driver that runs on the current platform. `SocialAuth.driver('google')` is a `GoogleDriver` on iOS and Android and a `RedirectDriver` on the web.

### GoogleDriver

Native Google SDK (`google_sign_in ^7.2.0`) on iOS and Android. The SDK's ID token is posted to `auth/social/google/token`, which verifies it. No nonce goes with it: the backend prohibits one for Google.

- Config: `ios_client_id` (iOS only) and `server_client_id` (the ID token's audience). See [Configuration](../getting-started/configuration.md#google).
- The SDK accepts one `initialize` per process, so every instance shares the first one.
- `signOut()` signs the SDK out so the next sign-in offers the account picker again.
- A canceled sheet throws `SocialAuthCancelledException`. Android also reports a misconfigured client (SHA-1, package name, `server_client_id`) as canceled.

### AppleDriver

Sign in with Apple through the native sheet on iOS (`sign_in_with_apple ^8.2.0`). Every sheet gets a fresh `Nonce`: Apple receives its lowercase sha256 hex and seals it into the ID token, the backend receives the raw value and checks the two match, so a token lifted from another sign-in is refused. The authorization code goes along for the refresh token that account deletion revokes. The result is an `AppleSignInResult`.

### RedirectDriver

Any provider through the backend's browser flow: GitHub and Microsoft everywhere, Apple on Android and the web, Google on the web. The app mints a PKCE pair, opens `<base_url>/auth/social/{provider}/redirect`, receives a one-time code on the callback and trades it with the verifier at `auth/social/exchange`. See [Flows](flows.md#browser-flow).

---

## <a name="platform-support-matrix"></a>Platform Support Matrix

| Provider | iOS | Android | Web |
|---|---|---|---|
| Google | native SDK | native SDK | browser flow (popup) |
| Apple | native sheet | browser flow | browser flow (popup) |
| GitHub | browser flow | browser flow | browser flow (popup) |
| Microsoft | browser flow | browser flow | browser flow (popup) |

macOS, Windows and Linux are not supported: `SocialAuth.supports(name)` answers `false` there, and `SocialAuthButtons` omits the provider.

---

## <a name="registering-a-custom-driver"></a>Registering a Custom Driver

The backend serves Google, Apple, GitHub and Microsoft. A custom driver is for a provider your own backend adds, or for a different way of running one of these. Extend `SocialDriver`, or reuse `RedirectDriver` for a provider the backend hosts a browser flow for:

```dart
SocialAuth.manager.extend(
  'gitlab',
  (config) => RedirectDriver('gitlab', config),
);

SocialAuth.manager.registerProviderDefaults(
  'gitlab',
  const SocialProviderDefaults(
    label: 'GitLab',
    iconSvg: '<svg>...</svg>',
    order: 5,
  ),
);
```

Call `extend()` before the first `SocialAuth.driver('gitlab')`. It clears a cached instance of that name, so re-registering is safe. A custom driver is resolved after the `enabled` check, so `social_auth.providers.gitlab.enabled: false` still disables it.

---

**Related**

- [Installation](../getting-started/installation.md)
- [Configuration](../getting-started/configuration.md)
- [Flows](flows.md)
- [Architecture overview](../architecture/overview.md)
