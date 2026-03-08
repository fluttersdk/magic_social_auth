import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/drivers/github_driver.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

void main() {
  group('GithubDriver', () {
    late GithubDriver driver;

    setUp(() {
      driver = GithubDriver({
        'client_id': 'test-github-client-id',
        'callback_scheme': 'myapp',
        'web_callback_url': 'http://localhost:3000/callback',
        'scopes': ['read:user', 'user:email'],
      });
    });

    test('name returns github', () {
      expect(driver.name, 'github');
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

    test('supports desktop platforms', () {
      // GitHub driver supports all platforms including desktop
      expect(driver.supportedPlatforms.contains(SocialPlatform.macos), isTrue);
      expect(
          driver.supportedPlatforms.contains(SocialPlatform.windows), isTrue);
      expect(driver.supportedPlatforms.contains(SocialPlatform.linux), isTrue);
    });

    test('config is accessible', () {
      expect(driver.config['client_id'], 'test-github-client-id');
      expect(driver.config['callback_scheme'], 'myapp');
      expect(
          driver.config['web_callback_url'], 'http://localhost:3000/callback');
      expect(driver.config['scopes'], ['read:user', 'user:email']);
    });

    test('signOut does not throw', () async {
      // GitHub driver doesn't need sign out, but should not throw
      await expectLater(driver.signOut(), completes);
    });
  });
}
