import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../contracts/social_driver.dart';
import '../models/social_platform.dart';
import '../models/social_token.dart';
import '../exceptions/social_auth_exception.dart';

/// Google Sign In driver.
///
/// Uses native Google Sign In SDK on mobile.
/// On web, uses authorization popup flow.
///
/// Requires google_sign_in 7.x+ with new singleton API.
class GoogleDriver extends SocialDriver {
  GoogleDriver(super.config);

  bool _initialized = false;

  @override
  String get name => 'google';

  @override
  Set<SocialPlatform> get supportedPlatforms => {
        SocialPlatform.ios,
        SocialPlatform.android,
        SocialPlatform.web,
      };

  @override
  Future<SocialToken> getToken() async {
    await _ensureInitialized();

    try {
      final signIn = GoogleSignIn.instance;
      final scopes = (config['scopes'] as List<dynamic>?)?.cast<String>() ??
          ['email', 'profile'];

      // Mobile: Use native authenticate
      if (signIn.supportsAuthenticate()) {
        final account = await signIn.authenticate();
        return _accountToToken(account);
      }

      // Web: Skip FedCM One Tap, go directly to authorization popup
      Log.info('Starting Google authorization popup...');

      final authClient = signIn.authorizationClient;
      final authorization = await authClient.authorizeScopes(scopes);

      if (authorization != null) {
        Log.info('Google authorization successful');

        // Web authorization only gives access_token
        // Backend will fetch user info from Google's userinfo API
        return SocialToken(
          provider: name,
          accessToken: authorization.accessToken,
          idToken: null,
          email: null,
          name: null,
          avatarUrl: null,
        );
      }

      throw const SocialAuthException('Google authorization failed');
    } on SocialAuthException {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialAuthCancelledException();
      }
      Log.error('Google Sign In failed: ${e.code} - ${e.description}');
      throw SocialAuthException('Google Sign In failed: ${e.description}');
    } catch (e) {
      Log.error('Google Sign In failed: $e');
      throw SocialAuthException('Google Sign In failed: $e');
    }
  }

  /// Convert account to SocialToken
  Future<SocialToken> _accountToToken(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    final scopes = (config['scopes'] as List<dynamic>?)?.cast<String>() ??
        ['email', 'profile'];

    String? accessToken;
    try {
      final authorization =
          await account.authorizationClient.authorizationForScopes(scopes);
      accessToken = authorization?.accessToken;
    } catch (e) {
      Log.warning('Could not get access token: $e');
    }

    return SocialToken(
      provider: name,
      accessToken: accessToken ?? '',
      idToken: idToken,
      email: account.email,
      name: account.displayName,
      avatarUrl: account.photoUrl,
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      Log.info('Google Sign Out successful');
    } catch (e) {
      Log.warning('Google Sign Out failed: $e');
      // Don't throw - sign out is best effort
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final clientId = config['client_id'] as String?;
    final serverClientId = config['server_client_id'] as String?;

    // serverClientId is only supported on mobile (iOS/Android), not on web
    await GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: kIsWeb ? null : serverClientId,
    );

    _initialized = true;
  }
}
