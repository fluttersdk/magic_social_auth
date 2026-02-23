import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:magic/magic.dart';

import '../contracts/social_driver.dart';
import '../models/social_platform.dart';
import '../models/social_token.dart';
import '../exceptions/social_auth_exception.dart';

/// GitHub OAuth driver.
///
/// Uses OAuth browser flow via flutter_web_auth_2.
/// Note: GitHub only returns authorization code, which must be exchanged
/// on the backend for an access token.
class GithubDriver extends SocialDriver {
  GithubDriver(super.config);

  @override
  String get name => 'github';

  @override
  Set<SocialPlatform> get supportedPlatforms => {
    SocialPlatform.ios,
    SocialPlatform.android,
    SocialPlatform.web,
    SocialPlatform.macos,
    SocialPlatform.windows,
    SocialPlatform.linux,
  };

  @override
  Future<SocialToken> getToken() async {
    final clientId = config['client_id'] as String?;
    final callbackScheme = config['callback_scheme'] as String? ?? 'uptizm';
    final webCallbackUrl = config['web_callback_url'] as String?;
    final scopes =
        (config['scopes'] as List<dynamic>?)?.cast<String>() ??
        ['read:user', 'user:email'];

    if (clientId == null) {
      throw const ProviderNotConfiguredException('github');
    }

    // Determine redirect URI based on platform
    final platform = SocialPlatformExtension.current;
    final redirectUri = platform == SocialPlatform.web
        ? (webCallbackUrl ?? 'http://localhost:8080/auth/callback')
        : '$callbackScheme://callback';

    final authUrl = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scopes.join(' '),
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme:
            platform == SocialPlatform.web ? 'http' : callbackScheme,
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code == null) {
        throw const SocialAuthException('No authorization code in response');
      }

      // GitHub returns a code that must be exchanged by the backend.
      // Use authorizationCode field instead of stuffing into accessToken.
      return SocialToken(
        provider: name,
        accessToken: '', // Empty - backend will exchange code for token
        authorizationCode: code,
      );
    } catch (e) {
      if (e is SocialAuthException) rethrow;
      if (e.toString().contains('CANCELED') ||
          e.toString().contains('cancelled')) {
        throw const SocialAuthCancelledException();
      }
      Log.error('GitHub Sign In failed: $e');
      throw SocialAuthException('GitHub Sign In failed: $e');
    }
  }
}
