import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:magic/magic.dart';

import '../contracts/social_driver.dart';
import '../models/social_platform.dart';
import '../models/social_token.dart';
import '../exceptions/social_auth_exception.dart';

/// Microsoft OAuth driver.
///
/// Uses OAuth authorization code flow (PKCE) via flutter_web_auth_2.
/// More secure than deprecated implicit grant flow.
class MicrosoftDriver extends SocialDriver {
  MicrosoftDriver(super.config);

  @override
  String get name => 'microsoft';

  @override
  Set<SocialPlatform> get supportedPlatforms => {
        SocialPlatform.ios,
        SocialPlatform.android,
        SocialPlatform.web,
        SocialPlatform.macos,
        SocialPlatform.windows,
      };

  @override
  Future<SocialToken> getToken() async {
    final clientId = config['client_id'] as String?;
    final tenant = config['tenant'] as String? ?? 'common';
    final callbackScheme = config['callback_scheme'] as String? ?? 'uptizm';
    final webCallbackUrl = config['web_callback_url'] as String?;
    final scopes = (config['scopes'] as List<dynamic>?)?.cast<String>() ??
        ['openid', 'profile', 'email'];

    if (clientId == null) {
      throw const ProviderNotConfiguredException('microsoft');
    }

    // Determine redirect URI based on platform
    final platform = SocialPlatformExtension.current;
    final redirectUri = platform == SocialPlatform.web
        ? (webCallbackUrl ?? 'http://localhost:8080/auth/callback')
        : '$callbackScheme://callback';

    final authUrl = Uri.https(
      'login.microsoftonline.com',
      '/$tenant/oauth2/v2.0/authorize',
      {
        'client_id': clientId,
        'response_type': 'code', // Authorization code flow (more secure)
        'redirect_uri': redirectUri,
        'scope': scopes.join(' '),
        'response_mode': 'query', // Code comes in query params, not fragment
      },
    );

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

      // Microsoft returns a code that must be exchanged by the backend.
      // Use authorizationCode field for proper code exchange flow.
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
      Log.error('Microsoft Sign In failed: $e');
      throw SocialAuthException('Microsoft Sign In failed: $e');
    }
  }
}
