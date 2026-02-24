import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/models/social_platform.dart';

void main() {
  group('SocialPlatformExtension', () {
    test('current returns a valid platform', () {
      final platform = SocialPlatformExtension.current;
      expect(platform, isA<SocialPlatform>());
      expect(
        platform,
        isIn([
          SocialPlatform.ios,
          SocialPlatform.android,
          SocialPlatform.web,
          SocialPlatform.macos,
          SocialPlatform.windows,
          SocialPlatform.linux,
        ]),
      );
    });

    test('isMobile returns true for ios and android', () {
      expect(SocialPlatform.ios.isMobile, isTrue);
      expect(SocialPlatform.android.isMobile, isTrue);
      expect(SocialPlatform.web.isMobile, isFalse);
      expect(SocialPlatform.macos.isMobile, isFalse);
      expect(SocialPlatform.windows.isMobile, isFalse);
      expect(SocialPlatform.linux.isMobile, isFalse);
    });

    test('isDesktop returns true for macos, windows, linux', () {
      expect(SocialPlatform.macos.isDesktop, isTrue);
      expect(SocialPlatform.windows.isDesktop, isTrue);
      expect(SocialPlatform.linux.isDesktop, isTrue);
      expect(SocialPlatform.ios.isDesktop, isFalse);
      expect(SocialPlatform.android.isDesktop, isFalse);
      expect(SocialPlatform.web.isDesktop, isFalse);
    });
  });
}
