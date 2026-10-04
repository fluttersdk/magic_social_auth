# Changelog

## [Unreleased]

## [0.0.8] - 2026-10-05

Requires `magic-starter-laravel` with its redesigned social login (`auth/social/{provider}/redirect`, `auth/social/exchange`, `auth/social/{provider}/token`, `user/social-accounts/link-ticket`).

### Added

- **Sign in with Apple, native on iOS.** `AppleDriver` opens the system sheet with the lowercase sha256 hex of a fresh nonce, then posts the identity token, the raw nonce and the authorization code to `auth/social/apple/token`. The nonce is new per sheet; the backend refuses one it has seen. The result is an `AppleSignInResult`, which carries the `givenName` and `familyName` Apple shares on the first authorization only. Apple on Android and the web goes through the browser flow. (`lib/src/drivers/apple_driver.dart`, `lib/src/flow/nonce.dart`)
- **A backend-hosted browser flow with PKCE for GitHub, Microsoft, Apple on Android and web, and Google on the web.** `RedirectDriver` mints a `Pkce` pair (64-character verifier, 43-character S256 challenge), opens `<network.drivers.api.base_url>/auth/social/{provider}/redirect?platform=&challenge=` through `flutter_web_auth_2`, takes the one-time code from the callback and trades it with the verifier at `auth/social/exchange`. iOS returns through a custom scheme, Android through an https App Link (Auth Tab with `httpsHost` and `httpsPath`), the web through a popup and `web/auth.html`. A refusal arrives as `SocialAuthException` with the backend's `code`. `preferEphemeral` is never set on Android. (`lib/src/drivers/redirect_driver.dart`, `lib/src/flow/social_flow.dart`, `lib/src/flow/pkce.dart`, `lib/src/flow/web_flow_slot.dart`)
- **`signIn`, `beginConnect`, `connect` and `confirm` on every driver, all answering a `SocialAuthResult`.** `connect(proof)` links a provider to the signed-in account; `proof` is the step-up field the account can give (`password`, `code` or `confirmation_token`) and `null` for a guest. `beginConnect(proof)` does the link-ticket request first and returns the call that opens the provider, so a web popup can open from a fresh tap. `confirm()` re-authenticates with a linked provider and returns a `confirmationToken`. `SocialAuthResult` exposes the token and user, the 2FA challenge (`isTwoFactor`, `twoFactorToken`), `deletionCancelled`, `connectedProvider` and `confirmationToken`. Every retry mints a new PKCE pair, link ticket and proof. (`lib/src/contracts/social_driver.dart`, `lib/src/models/social_auth_result.dart`)
- **`social:install` writes the whole setup.** Flags: `--providers`, `--google-ios-client-id`, `--google-server-client-id`, `--ios-scheme`, `--android-callback`, plus the inherited `--force`, `--dry-run`, `--non-interactive` and `--no-bootstrap`. It publishes `lib/config/social_auth.dart` and registers its factory, adds `GIDClientID`, `GIDServerClientID` and the reversed client id URL scheme to `Info.plist`, writes the Sign in with Apple entitlement into every entitlements file the app target signs with, declares the `CallbackActivity` with an `autoVerify` https intent filter, writes `web/auth.html`, and, when the app lists `magic_starter`, publishes the starter bridge and registers it. Needs `fluttersdk_artisan` 0.0.18. (`lib/src/cli/commands/social_install_command.dart`, `install.yaml`, `assets/stubs/install/`)
- **`social:doctor` checks the setup and prints the backend env.** It verifies the config, the iOS keys, URL scheme and Apple entitlement in every signing file, the Android callback activity (`exported`, `taskAffinity`, `autoVerify` filter) and any other App Link filter that overlaps the callback, `web/auth.html`, and the starter bridge, warns when an iOS app offers a provider but not Apple (App Store guideline 4.8), and prints the `MAGIC_STARTER_SOCIAL_*` and `MAGIC_STARTER_APPLE_*` lines and the callback URL each provider console has to list. (`lib/src/cli/commands/social_doctor_command.dart`)
- **`SocialAuthException.code` and `statusCode`, and `SocialAuthCancelledException.superseded`.** A backend refusal is read by `code`, never by message. `superseded` is true when another flow took the browser, so the caller stays quiet. (`lib/src/exceptions/social_auth_exception.dart`)
- **An Apple icon and label in `SocialAuthButtons`, Apple first on iOS.** (`lib/src/ui/social_provider_icons.dart`, `lib/src/ui/social_auth_buttons.dart`)

### Changed

- **BREAKING: the package no longer creates a session.** Drivers answer a `SocialAuthResult`; the caller (or the magic_starter bridge) runs `Auth.login`, finishes a 2FA challenge and handles `deletionCancelled`. `SocialAuthButtons` takes a synchronous `onPressed(provider)` in place of `onAuthenticate`, so a web popup opens from the tap itself. (`lib/src/social_auth_manager.dart`, `lib/src/ui/social_auth_buttons.dart`)
- **BREAKING: Google is native on iOS and Android only, and posts its ID token to the backend.** The web signs in with Google through the browser flow. No nonce is sent for Google. The SDK is initialized once per process and signed out through `signOut()`. (`lib/src/drivers/google_driver.dart`)
- **BREAKING: config.** `social_auth.callback.ios` and `social_auth.callback.android` are new and must equal the backend's `MAGIC_STARTER_SOCIAL_IOS_REDIRECT` and `MAGIC_STARTER_SOCIAL_ANDROID_REDIRECT`. `providers.google.ios_client_id` replaces `client_id`. (`assets/stubs/install/social_auth_config.stub`)
- **BREAKING: Dart `^3.12.0`, Flutter `>=3.44.0`** (from `sign_in_with_apple` 8.2), `flutter_web_auth_2 ^5.1.0`, and `fluttersdk_artisan ^0.0.18`. New dependencies: `sign_in_with_apple ^8.2.0`, `crypto ^3.0.7`. (`pubspec.yaml`)
- **The documentation is rewritten for the new flows**, and `doc/basics/handlers.md` is replaced by `doc/basics/flows.md`. An app without `magic_starter` has to sign Google out on its own sign-out; the bridge does it for starter apps. (`README.md`, `doc/`, `CLAUDE.md`)

### Removed

- **BREAKING: `SocialToken`, `SocialAuthHandler`, `HttpSocialAuthHandler` and `SocialAuth.manager.setHandler()`.** The handler posted a provider token to `auth/social/{provider}`, which the backend has removed. (`lib/src/models/social_token.dart`, `lib/src/contracts/social_auth_handler.dart`)
- **BREAKING: `MicrosoftDriver` and `GithubDriver`.** Both providers are a `RedirectDriver` now. `getToken()` and `authenticate()` are gone from `SocialDriver`.
- **BREAKING: the config keys `endpoint`, `providers.*.client_id`, `scopes`, `tenant`, `callback_scheme` and `web_callback_url`.** The backend owns scopes, tenants and client secrets.

## [0.0.7] - 2026-09-29

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.22` to `^0.0.24` and `fluttersdk_artisan` `^0.0.16` to `^0.0.17`. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floors name the releases this package is verified against. magic 0.0.24 removes `MagicController.onRefreshUI` (BREAKING); this package calls it nowhere in `lib/` or `test/`, so nothing here moves with it. (`pubspec.yaml`)

## [0.0.6] - 2026-09-27

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.16` to `^0.0.22`; `fluttersdk_artisan` stays at `^0.0.16`, still the newest. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floor names the release this package is verified against. magic 0.0.22's BREAKING changes (`Magic.delete` disposing the notifier it removes, `MagicTest.init()` resetting the Gate and Translator, `Min`/`Max` reading a numeric string by value beside `Numeric`) touch nothing this package calls. The installation guide's requirements table, which still named `magic ^0.0.5`, now matches. (`pubspec.yaml`, `doc/getting-started/installation.md`)

## [0.0.5] - 2026-09-22

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.15` to `^0.0.16`; `fluttersdk_artisan` stays at `^0.0.16`, still the newest. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floors name the releases this package is verified against. magic 0.0.16 widens `file_picker` to admit 13, where `PlatformFile.length()` answers null for an unreadable file; this package does not call `Pick`. (`pubspec.yaml`)

## [0.0.4] - 2026-09-21

### Changed

- **Every sibling floor names this batch's release.** `magic` moves `^0.0.5` to `^0.0.15` and `fluttersdk_artisan` `^0.0.8` to `^0.0.16`. The old ranges already admitted the new versions, so a fresh `pub get` resolves nothing differently; what changes is that the floors name the releases this package is verified against. magic 0.0.15 is breaking in its database layer (a migration may no longer manage its own transaction, and `DB.transaction` refuses a callback that closes the transaction itself); nothing in this package calls either, so no code here changes, but an app below magic 0.0.15 no longer resolves this release. (`pubspec.yaml`)

## [0.0.3] - 2026-08-25

### Added
- **The Google driver's error-translation contract has tests, and a seam to reach it through.** `getToken`'s try/catch is the whole contract consumers code against: a provider failure becomes `SocialAuthException`, a user cancel becomes `SocialAuthCancelledException` so "backed out" can be told from "failed", and an exception that is already ours is rethrown unchanged. Nothing covered any of it, because every route into that code runs through the platform channel. `supportsNativeSignIn`, `nativeSignIn` and `ensureInitialized` are now `@visibleForTesting` members a test subclass stands in for, and `_accountToToken` is `accountToToken` for the same reason. Four tests pin the contract; two of them fail if the `await` added in #10 is removed, so the fix has a regression guard rather than only an analyzer warning. Additive: no existing call site changes. (`lib/src/drivers/google_driver.dart`, `test/drivers/google_driver_test.dart`)
- **`codecov.yml`, with patch coverage informational and project coverage still a gate.** This package is a thin wrapper over provider SDKs whose calls only exist behind a platform channel, so a one-line fix in one of those branches scores 0% patch coverage however well the surrounding behaviour is tested. That is what happened on #10. Blocking on the number pushes toward inventing a seam for every platform call, or writing assertions like "this throws without a channel" purely to colour a line green. Total coverage is the honest gate and it went 55.0% -> 57.0% with the tests above. (`codecov.yml`)

### Fixed
- **A failure inside `_accountToToken` escaped the Google driver's error translation.** `getToken`'s native branch did `return _accountToToken(account)` inside the try whose catch clauses are the whole point of the method: they turn a `GoogleSignInException` into `SocialAuthCancelledException` on a user cancel and into `SocialAuthException` otherwise. Returning the future unawaited means anything it throws is raised after the try has already completed, so those handlers never see it and the caller gets a raw exception instead of this package's contract. It is reachable: `_accountToToken` reads `account.authentication.idToken` with no guard of its own, and only its inner `authorizationForScopes` call is wrapped. Now `return await`. Surfaced by the analyzer's `unawaited_return_in_try_block`, which turned `master` red on a newer Dart than the PR that last touched the file ran against, and the warning was right. (`lib/src/drivers/google_driver.dart`)

## [0.0.2] - 2026-07-26

### Changed
- **`magic` constraint bumped to `^0.0.3` -> `^0.0.5`.** The old bound excluded every magic release since 0.0.4: under pub's `0.0.z` caret semantics `^0.0.3` means `<0.0.4`, so this plugin could not resolve alongside a consumer on current magic at all. Now tracks magic 0.0.5. No behavior change in this package.

## [0.0.1] - 2026-06-24

### 📚 Documentation
- **README**: Rewrite to match Magic ecosystem format
- **doc/ folder**: Add comprehensive documentation

## [0.0.1-alpha.1] - 2026-03-25

### ✨ Core Features
- **Laravel Socialite-style API**: `SocialAuth.driver('google').authenticate()` facade pattern
- **Google Driver**: Native Google Sign-In SDK on mobile, auth popup on web
- **Microsoft Driver**: OAuth authorization code flow via `flutter_web_auth_2`
- **GitHub Driver**: OAuth browser flow with code exchange
- **Extensible Drivers**: Register custom drivers via `SocialAuth.manager.extend()`
- **Custom Auth Handlers**: Swap backend auth with `SocialAuth.manager.setHandler()`
- **Platform Detection**: Conditional imports for iOS, Android, Web, macOS, Windows, Linux
- **SocialToken Model**: Supports both token and code-exchange authentication flows
- **SocialAuthButtons Widget**: Config-driven UI with platform filtering and loading states
- **SocialProviderIcons**: SVG icon registry with custom provider support
- **Service Provider**: Magic Framework IoC integration via `SocialAuthServiceProvider`
- **Sign Out**: Global `SocialAuth.signOut()` clears all cached driver sessions
