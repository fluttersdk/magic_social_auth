import 'social_platform.dart';

/// Stub implementation for unsupported platforms.
/// This file is used when neither dart:io nor dart:html is available.
SocialPlatform getCurrentPlatform() {
  return SocialPlatform.web; // Default fallback
}
