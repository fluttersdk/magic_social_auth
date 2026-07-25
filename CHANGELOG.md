# Changelog

## [Unreleased]

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
