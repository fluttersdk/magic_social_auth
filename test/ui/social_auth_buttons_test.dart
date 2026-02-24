import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_social_auth/src/social_auth_manager.dart';
import 'package:magic_social_auth/src/contracts/social_driver.dart';
import 'package:magic_social_auth/src/models/social_token.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';
import 'package:magic_social_auth/src/ui/social_auth_buttons.dart';
import 'package:magic_social_auth/src/ui/social_provider_icons.dart';

/// Mock driver for testing
class MockDriver extends SocialDriver {
  final bool _supportsPlatform;

  MockDriver(super.config, {bool supportsPlatform = true})
      : _supportsPlatform = supportsPlatform;

  @override
  String get name => config['provider_name'] as String? ?? 'mock';

  @override
  Set<SocialPlatform> get supportedPlatforms {
    if (!_supportsPlatform) return {};
    return {
      SocialPlatform.ios,
      SocialPlatform.android,
      SocialPlatform.web,
      SocialPlatform.macos,
      SocialPlatform.windows,
      SocialPlatform.linux,
    };
  }

  @override
  Future<SocialToken> getToken() async {
    return const SocialToken(
      provider: 'mock',
      accessToken: 'mock_token',
    );
  }

  @override
  Future<void> signOut() async {}
}

/// Helper to wrap widget in MaterialApp with WindTheme
Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    home: WindTheme(
      data: WindThemeData(),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    MagicApp.reset();
    Config.flush();
    SocialProviderIcons.reset();

    // Register SocialAuthManager in the container
    final manager = SocialAuthManager();
    MagicApp.instance.singleton('social_auth', () => manager);

    // Register mock drivers
    manager.extend('google', (config) => MockDriver(config));
    manager.extend('microsoft', (config) => MockDriver(config));
    manager.extend('github', (config) => MockDriver(config));
    manager.extend(
        'unsupported', (config) => MockDriver(config, supportsPlatform: false));
  });

  group('SocialAuthButtons', () {
    testWidgets('renders nothing when providers config is empty',
        (tester) async {
      Config.set('social_auth.providers', {});

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(onAuthenticate: (_) async {}),
      ));

      expect(find.byType(WButton), findsNothing);
    });

    testWidgets('renders nothing when providers config is null',
        (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(onAuthenticate: (_) async {}),
      ));

      expect(find.byType(WButton), findsNothing);
    });

    testWidgets('renders buttons for enabled providers only', (tester) async {
      Config.set('social_auth.providers', {
        'google': {'enabled': true},
        'microsoft': {'enabled': false}, // Disabled
        'github': {'enabled': true},
      });

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (_) async {},
          labelBuilder: (label, _) => label, // Simplify labels for testing
        ),
      ));

      expect(find.byType(WButton), findsNWidgets(2));
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Microsoft'), findsNothing);
    });

    testWidgets('skips unsupported platform providers', (tester) async {
      Config.set('social_auth.providers', {
        'google': {'enabled': true},
        'unsupported': {'enabled': true},
      });

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (_) async {},
          labelBuilder: (label, _) => label,
        ),
      ));

      expect(find.byType(WButton), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Unsupported'), findsNothing);
    });

    testWidgets('shows loading indicator for matching loadingProvider',
        (tester) async {
      Config.set('social_auth.providers', {
        'google': {'enabled': true},
        'github': {'enabled': true},
      });

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (_) async {},
          loadingProvider: 'google', // Google is loading
          labelBuilder: (label, _) => label,
        ),
      ));

      // We should have 2 buttons
      final buttons = tester.widgetList<WButton>(find.byType(WButton)).toList();
      expect(buttons.length, 2);

      // Sort to reliably check properties (by default google is before github due to built-in order)
      // Google (loading: true, enabled: false due to loading)
      expect(buttons[0].isLoading, isTrue);
      // Disable means onTap is null for WButton but we should test the internal logic directly via widget tree

      // GitHub (loading: false, disabled because another is loading)
      expect(buttons[1].isLoading, isFalse);
      expect(buttons[1].onTap, isNull); // Disabled
    });

    testWidgets('disables all buttons when loadingProvider is empty string',
        (tester) async {
      Config.set('social_auth.providers', {
        'google': {'enabled': true},
        'github': {'enabled': true},
      });

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (_) async {},
          loadingProvider: '', // Empty means all disabled, no spinners
          labelBuilder: (label, _) => label,
        ),
      ));

      final buttons = tester.widgetList<WButton>(find.byType(WButton)).toList();

      for (final button in buttons) {
        expect(button.isLoading, isFalse);
        expect(button.onTap, isNull);
      }
    });

    testWidgets('config-driven label override works', (tester) async {
      Config.set('social_auth.providers', {
        'google': {
          'enabled': true,
          'label': 'Sign in with Alphabet',
        },
      });

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (_) async {},
          labelBuilder: (label, _) => label,
        ),
      ));

      expect(find.text('Sign in with Alphabet'), findsOneWidget);
    });

    testWidgets('custom labelBuilder overrides default labels', (tester) async {
      Config.set('social_auth.providers', {
        'google': {'enabled': true},
      });

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (_) async {},
          labelBuilder: (providerLabel, mode) => 'Custom: $providerLabel',
        ),
      ));

      expect(find.text('Custom: Google'), findsOneWidget);
    });

    testWidgets('providers sorted by order field', (tester) async {
      Config.set('social_auth.providers', {
        'github': {'enabled': true, 'order': 1}, // Should be first
        'microsoft': {'enabled': true, 'order': 3}, // Should be third
        'google': {'enabled': true, 'order': 2}, // Should be second
      });

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (_) async {},
          labelBuilder: (label, _) => label,
        ),
      ));

      final texts = tester.widgetList<WText>(find.byType(WText)).toList();
      expect(texts[0].data, 'GitHub');
      expect(texts[1].data, 'Google');
      expect(texts[2].data, 'Microsoft');
    });

    testWidgets('custom provider with icon_svg in config renders',
        (tester) async {
      Config.set('social_auth.providers', {
        'custom': {
          'enabled': true,
          'icon_svg': '<svg><rect/></svg>',
        },
      });

      // Register mock driver for custom provider so it passes supports()
      final manager = Magic.make<SocialAuthManager>('social_auth');
      manager.extend('custom', (config) => MockDriver(config));

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (_) async {},
          labelBuilder: (label, _) => label,
        ),
      ));

      expect(find.text('Custom'), findsOneWidget);
      expect(find.byType(WSvg), findsOneWidget);
    });

    testWidgets('onAuthenticate fires with correct provider name on tap',
        (tester) async {
      Config.set('social_auth.providers', {
        'google': {'enabled': true},
      });

      String? tappedProvider;

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (provider) async {
            tappedProvider = provider;
          },
          labelBuilder: (label, _) => label,
        ),
      ));

      await tester.tap(find.byType(WButton));

      expect(tappedProvider, 'google');
    });

    testWidgets('buttonClassName override applies to buttons', (tester) async {
      Config.set('social_auth.providers', {
        'google': {'enabled': true},
      });

      await tester.pumpWidget(wrapWithTheme(
        SocialAuthButtons(
          onAuthenticate: (_) async {},
          buttonClassName: 'custom-button-class text-red-500',
        ),
      ));

      final button = tester.widget<WButton>(find.byType(WButton));
      expect(button.className, 'custom-button-class text-red-500');
    });
  });
}
