import 'dart:io' show Platform;
import 'social_platform.dart';

/// IO implementation for native platforms (iOS, Android, macOS, Windows, Linux).
SocialPlatform getCurrentPlatform() {
  if (Platform.isIOS) return SocialPlatform.ios;
  if (Platform.isAndroid) return SocialPlatform.android;
  if (Platform.isMacOS) return SocialPlatform.macos;
  if (Platform.isWindows) return SocialPlatform.windows;
  if (Platform.isLinux) return SocialPlatform.linux;
  return SocialPlatform.web; // Fallback
}
