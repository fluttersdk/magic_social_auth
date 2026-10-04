---
paths:
  - "lib/**/*.dart"
---

# Flutter / Dart Stack

- Dart ^3.12.0, Flutter >=3.44.0: use modern patterns (records, switch expressions, null-aware map elements, strict null safety); `dart format` uses the tall style
- Import order: dart/flutter stdlib, then third-party packages, then `package:magic/magic.dart`, then `package:magic_social_auth/...`, then relative imports
- Naming: `{Concept}Manager` (singleton), `{Concept}Driver` (strategy impl), `{Concept}ServiceProvider` (bootstrap), `{Concept}Exception`
- Singleton pattern: `static final _instance = Class._internal(); factory Class() => _instance;`
- Contract-first: `SocialDriver` defines the driver API; implementations live in `lib/src/drivers/`. Backend calls, PKCE and nonces live only in `lib/src/flow/` (`SocialFlow`, `Pkce`, `Nonce`); drivers compose them and never duplicate them
- Two-phase bootstrap: `register()` binds singletons to IoC (sync), `boot()` configures them (`Future<void>`)
- IoC binding: `app.singleton('key', () => Service())` in register, `app.make<T>('key')` in boot
- Config access: always via `Config.get()` — e.g. `Config.get('social_auth.providers.google')`, never hardcode
- Driver contract: `name`, `supportedPlatforms`, `supportsPlatform()`, `signIn()`, `beginConnect(proof)` (network first, then an opener that reaches the provider before its first await), `connect(proof)`, `confirm()`, `signOut()`
- Web popups: nothing may be awaited between the user's tap and `FlutterWebAuth2.authenticate`, or the browser blocks the popup
- Platform detection: use `SocialPlatform` enum + `SocialPlatformExtension.current`; the manager picks the driver class per platform (native Google on iOS/Android, native Apple on iOS, `RedirectDriver` otherwise)
- Barrel export: `lib/magic_social_auth.dart` groups by concern (Contracts, Drivers, Flow, Models, Exceptions, UI)
- `analysis_options.yaml` uses `package:flutter_lints/flutter.yaml` — zero warnings required
