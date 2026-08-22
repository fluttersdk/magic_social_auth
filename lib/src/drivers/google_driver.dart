import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:magic/magic.dart';

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

  /// Whether the platform offers the native sign-in sheet.
  ///
  /// A seam, not indirection for its own sake: everything below it talks to the
  /// platform channel, so without something to override a test cannot reach
  /// [getToken]'s try/catch at all, which is where this driver's whole contract
  /// lives.
  @visibleForTesting
  bool get supportsNativeSignIn => GoogleSignIn.instance.supportsAuthenticate();

  /// Runs the native sheet and converts the account it returns.
  ///
  /// Overridden in tests to stand in for the platform channel. See
  /// [supportsNativeSignIn] for why the seam exists.
  @visibleForTesting
  Future<SocialToken> nativeSignIn() async {
    final account = await GoogleSignIn.instance.authenticate();
    return await accountToToken(account);
  }

  /// Prepares the SDK, exposed so a test can stand in for the platform channel.
  @visibleForTesting
  Future<void> ensureInitialized() => _ensureInitialized();

  @override
  Future<SocialToken> getToken() async {
    await ensureInitialized();

    try {
      final scopes = (config['scopes'] as List<dynamic>?)?.cast<String>() ??
          ['email', 'profile'];

      // Mobile: Use native authenticate
      if (supportsNativeSignIn) {
        // `await`, not a bare return: this sits inside the try whose catch
        // clauses are what turn a provider error into SocialAuthException /
        // SocialAuthCancelledException. Returning the future unawaited lets
        // anything the native path throws skip those handlers and reach the
        // caller raw, breaking the driver's contract.
        return await nativeSignIn();
      }

      final signIn = GoogleSignIn.instance;

      // Web: Skip FedCM One Tap, go directly to authorization popup
      Log.info('Starting Google authorization popup...');

      final authClient = signIn.authorizationClient;
      final authorization = await authClient.authorizeScopes(scopes);

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

  /// Convert account to SocialToken.
  @visibleForTesting
  Future<SocialToken> accountToToken(GoogleSignInAccount account) async {
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
