# Changelog

## [Unreleased]

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
