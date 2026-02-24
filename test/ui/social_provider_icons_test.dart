import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/ui/social_provider_icons.dart';

void main() {
  setUp(() {
    SocialProviderIcons.reset();
  });

  group('SocialProviderIcons', () {
    test('forProvider returns built-in defaults for google', () {
      final defaults = SocialProviderIcons.forProvider('google');
      expect(defaults, isNotNull);
      expect(defaults!.label, 'Google');
      expect(defaults.iconSvg, SocialProviderIcons.googleSvg);
      expect(defaults.order, 1);
      expect(defaults.iconClassName, isNull);
    });

    test('forProvider returns built-in defaults for microsoft', () {
      final defaults = SocialProviderIcons.forProvider('microsoft');
      expect(defaults, isNotNull);
      expect(defaults!.label, 'Microsoft');
      expect(defaults.iconSvg, SocialProviderIcons.microsoftSvg);
      expect(defaults.order, 2);
      expect(defaults.iconClassName, isNull);
    });

    test('forProvider returns built-in defaults for github', () {
      final defaults = SocialProviderIcons.forProvider('github');
      expect(defaults, isNotNull);
      expect(defaults!.label, 'GitHub');
      expect(defaults.iconSvg, SocialProviderIcons.githubSvg);
      expect(defaults.order, 3);
      expect(defaults.iconClassName, 'fill-slate-900 dark:fill-white');
    });

    test('forProvider returns null for unknown provider', () {
      final defaults = SocialProviderIcons.forProvider('unknown');
      expect(defaults, isNull);
    });

    test('has returns true for known and false for unknown providers', () {
      expect(SocialProviderIcons.has('google'), isTrue);
      expect(SocialProviderIcons.has('microsoft'), isTrue);
      expect(SocialProviderIcons.has('github'), isTrue);
      expect(SocialProviderIcons.has('unknown'), isFalse);
    });

    test('register adds custom provider that is returned by forProvider', () {
      const customDefaults = SocialProviderDefaults(
        label: 'MyProvider',
        iconSvg: '<svg></svg>',
        order: 10,
      );

      SocialProviderIcons.register('custom', customDefaults);

      expect(SocialProviderIcons.has('custom'), isTrue);

      final defaults = SocialProviderIcons.forProvider('custom');
      expect(defaults, isNotNull);
      expect(defaults!.label, 'MyProvider');
      expect(defaults.iconSvg, '<svg></svg>');
      expect(defaults.order, 10);
      expect(defaults.iconClassName, isNull);
    });

    test('register overrides built-in provider with same key', () {
      const customGoogle = SocialProviderDefaults(
        label: 'Custom Google',
        iconSvg: '<svg>custom</svg>',
        order: 99,
      );

      SocialProviderIcons.register('google', customGoogle);

      final defaults = SocialProviderIcons.forProvider('google');
      expect(defaults, isNotNull);
      expect(defaults!.label, 'Custom Google');
      expect(defaults.iconSvg, '<svg>custom</svg>');
      expect(defaults.order, 99);
    });

    test('reset clears custom registrations but keeps built-in', () {
      const customDefaults = SocialProviderDefaults(
        label: 'MyProvider',
        iconSvg: '<svg></svg>',
      );

      SocialProviderIcons.register('custom', customDefaults);
      SocialProviderIcons.register('google', customDefaults); // Override

      SocialProviderIcons.reset();

      expect(SocialProviderIcons.has('custom'), isFalse);

      final googleDefaults = SocialProviderIcons.forProvider('google');
      expect(googleDefaults, isNotNull);
      expect(googleDefaults!.label, 'Google'); // Restored to built-in
    });

    test('built-in SVG constants are non-empty valid strings', () {
      expect(SocialProviderIcons.googleSvg, startsWith('<svg'));
      expect(SocialProviderIcons.googleSvg, endsWith('</svg>'));
      expect(SocialProviderIcons.googleSvg.length, greaterThan(10));

      expect(SocialProviderIcons.microsoftSvg, startsWith('<svg'));
      expect(SocialProviderIcons.microsoftSvg, endsWith('</svg>'));
      expect(SocialProviderIcons.microsoftSvg.length, greaterThan(10));

      expect(SocialProviderIcons.githubSvg, startsWith('<svg'));
      expect(SocialProviderIcons.githubSvg, endsWith('</svg>'));
      expect(SocialProviderIcons.githubSvg.length, greaterThan(10));
    });
  });
}
