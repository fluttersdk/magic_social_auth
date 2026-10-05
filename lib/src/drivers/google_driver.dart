import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:magic/magic.dart' show Log;

import '../contracts/social_driver.dart';
import '../exceptions/social_auth_exception.dart';
import '../flow/social_flow.dart';
import '../models/social_auth_result.dart';
import '../models/social_platform.dart';

/// Google through the native SDK on iOS and Android.
///
/// The SDK's ID token is posted to `auth/social/google/token`, which verifies
/// it; no nonce goes with it (the backend prohibits one for Google). The web
/// signs in with Google through `RedirectDriver`, so this driver never touches
/// the SDK there.
///
/// Config (`social_auth.providers.google`): `ios_client_id` (the iOS OAuth
/// client) and `server_client_id` (the web OAuth client, the ID token's
/// audience the backend accepts).
class GoogleDriver extends SocialDriver {
  GoogleDriver(super.config, {super.platform, SocialFlow? flow})
    : _flow = flow ?? SocialFlow(platform: platform);

  /// The SDK accepts one `initialize` per process, so every instance shares
  /// the first one, failed or not.
  static Future<void>? _initialization;

  final SocialFlow _flow;

  @override
  String get name => 'google';

  @override
  Set<SocialPlatform> get supportedPlatforms => {
    SocialPlatform.ios,
    SocialPlatform.android,
  };

  /// The iOS OAuth client; Android reads its client from the signing key.
  ///
  /// Null when unset or empty, so the SDK falls back to `GIDClientID` in
  /// `Info.plist` instead of being handed the config stub's `''`.
  String? get clientId =>
      platform == SocialPlatform.ios ? _configured('ios_client_id') : null;

  /// The web OAuth client the ID token is minted for, the audience the backend
  /// verifies; null when unset or empty, as with [clientId].
  String? get serverClientId => _configured('server_client_id');

  @override
  Future<SocialAuthResult> signIn() => _post(SocialIntent.signIn);

  @override
  Future<Future<SocialAuthResult> Function()> beginConnect(
    Map<String, String>? proof,
  ) async {
    return () => _post(SocialIntent.connect, proof);
  }

  @override
  Future<SocialAuthResult> confirm() => _post(SocialIntent.confirm);

  /// Signs the SDK out, so the next sign-in offers the account picker again.
  @override
  Future<void> signOut() async {
    if (!supportsPlatform()) return;

    await _ensureInitialized();
    await signOutSdk();
  }

  /// Forgets the process-wide initialize, so each test starts from none.
  @visibleForTesting
  static void resetInitialization() => _initialization = null;

  /// The SDK's `initialize`; a seam over the platform channel.
  @visibleForTesting
  Future<void> initializeSdk() {
    return GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
  }

  /// Opens the native account sheet and answers the account's ID token; a
  /// seam over the platform channel.
  @visibleForTesting
  Future<String?> nativeSignIn() async {
    final GoogleSignInAccount account = await GoogleSignIn.instance
        .authenticate();

    return account.authentication.idToken;
  }

  /// The SDK's `signOut`; a seam over the platform channel.
  @visibleForTesting
  Future<void> signOutSdk() => GoogleSignIn.instance.signOut();

  Future<void> _ensureInitialized() => _initialization ??= initializeSdk();

  String? _configured(String key) {
    final String? value = config[key] as String?;

    return value == null || value.isEmpty ? null : value;
  }

  Future<SocialAuthResult> _post(
    SocialIntent intent, [
    Map<String, String>? proof,
  ]) async {
    final String idToken = await _idToken();

    return _flow.token(name, idToken: idToken, intent: intent, proof: proof);
  }

  Future<String> _idToken() async {
    final String? idToken;
    try {
      await _ensureInitialized();
      idToken = await nativeSignIn();
    } on GoogleSignInException catch (error) {
      // Android also reports a misconfigured client (SHA-1, package name,
      // server_client_id) as canceled, so the cancel copy invites a retry.
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialAuthCancelledException();
      }

      Log.error(
        'Google sign-in failed: ${error.description ?? error.code.name}',
      );
      throw const SocialAuthException(
        'Google sign-in could not be completed.',
        code: 'sdk_error',
      );
    }

    if (idToken == null) {
      Log.error(
        'Google returned no ID token. Set '
        'social_auth.providers.google.server_client_id.',
      );
      throw const SocialAuthException(
        'Google sign-in could not be completed.',
        code: 'sdk_error',
      );
    }

    return idToken;
  }
}
