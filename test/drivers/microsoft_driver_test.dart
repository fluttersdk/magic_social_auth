import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/drivers/microsoft_driver.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

void main() {
  group('MicrosoftDriver', () {
    late MicrosoftDriver driver;

    setUp(() {
      driver = MicrosoftDriver({
        'client_id': 'test-microsoft-client-id',
        'tenant': 'common',
        'callback_scheme': 'myapp',
        'web_callback_url': 'http://localhost:3000/callback',
        'scopes': ['openid', 'profile', 'email'],
      });
    });

    test('name returns microsoft', () {
      expect(driver.name, 'microsoft');
    });

    test('supports iOS, Android, and Web platforms', () {
      expect(
        driver.supportedPlatforms,
        containsAll([
          SocialPlatform.ios,
          SocialPlatform.android,
          SocialPlatform.web,
        ]),
      );
    });

    test('supportsPlatform returns true for supported platforms', () {
      expect(driver.supportsPlatform(SocialPlatform.ios), isTrue);
      expect(driver.supportsPlatform(SocialPlatform.android), isTrue);
      expect(driver.supportsPlatform(SocialPlatform.web), isTrue);
    });

    test('supports some desktop platforms', () {
      // Microsoft driver supports macos and windows (but not linux)
      expect(driver.supportedPlatforms.contains(SocialPlatform.macos), isTrue);
      expect(driver.supportedPlatforms.contains(SocialPlatform.windows), isTrue);
      expect(driver.supportedPlatforms.contains(SocialPlatform.linux), isFalse);
    });

    test('config is accessible', () {
      expect(driver.config['client_id'], 'test-microsoft-client-id');
      expect(driver.config['tenant'], 'common');
      expect(driver.config['callback_scheme'], 'myapp');
      expect(driver.config['web_callback_url'], 'http://localhost:3000/callback');
      expect(driver.config['scopes'], ['openid', 'profile', 'email']);
    });

    test('signOut does not throw', () async {
      // Microsoft driver doesn't need sign out, but should not throw
      await expectLater(driver.signOut(), completes);
    });
  });
}
