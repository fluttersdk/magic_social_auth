import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/drivers/google_driver.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

void main() {
  group('GoogleDriver', () {
    late GoogleDriver driver;

    setUp(() {
      driver = GoogleDriver({
        'client_id': 'test-client-id',
        'server_client_id': 'test-server-client-id',
        'scopes': ['email', 'profile'],
      });
    });

    test('name returns google', () {
      expect(driver.name, 'google');
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

    test('config is accessible', () {
      expect(driver.config['client_id'], 'test-client-id');
      expect(driver.config['server_client_id'], 'test-server-client-id');
      expect(driver.config['scopes'], ['email', 'profile']);
    });

    test('has signOut method', () {
      // Verify signOut method exists (calling it requires Magic container)
      expect(driver.signOut, isA<Function>());
    });
  });
}
