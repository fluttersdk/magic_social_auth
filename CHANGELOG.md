# Changelog

## [Unreleased]

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
