---
path: "lib/**/*.dart"
---

# Flutter / Dart Stack

- Dart >=3.6.0, Flutter >=3.27.0 — use modern patterns (records, switch expressions, strict null safety)
- Import order: dart/flutter stdlib → third-party packages → `package:magic/magic.dart` → `package:magic_social_auth/...` → relative imports
- Naming: `{Concept}Manager` (singleton), `{Concept}Driver` (strategy impl), `SocialAuthHandler` (contract), `{Concept}ServiceProvider` (bootstrap), `{Concept}Exception`
- Singleton pattern: `static final _instance = Class._internal(); factory Class() => _instance;`
- Contract-first: abstract class defines API (`SocialDriver`, `SocialAuthHandler`). Implementations in subdirectories
- Two-phase bootstrap: `register()` binds singletons to IoC (sync), `boot()` configures them (`Future<void>`)
- IoC binding: `app.singleton('key', () => Service())` in register, `app.make<T>('key')` in boot
- Config access: always via `Config.get()` — e.g. `Config.get('social_auth.providers.google')`, never hardcode
- Driver contract: `name`, `supportedPlatforms`, `supportsPlatform()`, `getToken()`, `authenticate()`, `signOut()`
- Platform detection: use `SocialPlatform` enum + `SocialPlatformExtension.current`. Conditional imports via `kIsWeb` for platform-specific SDKs
- Barrel export: `lib/magic_social_auth.dart` groups by concern (Contracts, Drivers, Models, Handlers, Exceptions)
- `analysis_options.yaml` uses `package:flutter_lints/flutter.yaml` — zero warnings required
