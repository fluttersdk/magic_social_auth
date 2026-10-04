import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:magic/magic.dart' show Log;

import '../contracts/social_driver.dart';
import '../exceptions/social_auth_exception.dart';
import '../flow/nonce.dart';
import '../flow/social_flow.dart';
import '../models/social_auth_result.dart';
import '../models/social_platform.dart';

/// What an Apple sign-in concluded, plus the name Apple shared.
///
/// Apple hands out the user's name on the first authorization only and never
/// puts it in the ID token, so the caller passes [givenName] and [familyName]
/// on (to a profile update) or they are lost.
class AppleSignInResult extends SocialAuthResult {
  AppleSignInResult(SocialAuthResult result, {this.givenName, this.familyName})
    : super(
        isTwoFactor: result.isTwoFactor,
        twoFactorToken: result.twoFactorToken,
        token: result.token,
        user: result.user,
        deletionCancelled: result.deletionCancelled,
        connectedProvider: result.connectedProvider,
        confirmationToken: result.confirmationToken,
      );

  /// The given name Apple shared; null on every authorization but the first,
  /// or when the user withheld it.
  final String? givenName;

  /// The family name Apple shared; null as [givenName] is.
  final String? familyName;
}

/// Sign in with Apple through the native sheet on iOS.
///
/// Every sheet gets a fresh [Nonce]: Apple receives its sha256 hex and seals
/// it into the ID token, the backend receives the raw value and checks the
/// two match, so a token lifted from another sign-in is refused. The
/// authorization code goes along for the refresh token that account deletion
/// revokes. Android and the web sign in with Apple through `RedirectDriver`.
class AppleDriver extends SocialDriver {
  AppleDriver(super.config, {super.platform, SocialFlow? flow})
    : _flow = flow ?? SocialFlow(platform: platform);

  final SocialFlow _flow;

  @override
  String get name => 'apple';

  @override
  Set<SocialPlatform> get supportedPlatforms => {SocialPlatform.ios};

  @override
  Future<AppleSignInResult> signIn() => _post(SocialIntent.signIn);

  @override
  Future<Future<SocialAuthResult> Function()> beginConnect(
    Map<String, String>? proof,
  ) async {
    return () => _post(SocialIntent.connect, proof);
  }

  @override
  Future<SocialAuthResult> confirm() => _post(SocialIntent.confirm);

  /// Opens the native sheet with [hashedNonce]; a seam over the platform
  /// channel.
  @visibleForTesting
  Future<AuthorizationCredentialAppleID> requestCredential(String hashedNonce) {
    return SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
  }

  Future<AppleSignInResult> _post(
    SocialIntent intent, [
    Map<String, String>? proof,
  ]) async {
    // 1. A nonce per sheet: the backend refuses one it has seen before.
    final Nonce nonce = Nonce.generate();
    final AuthorizationCredentialAppleID credential = await _credential(nonce);
    final String? idToken = credential.identityToken;

    if (idToken == null) throw _sdkError('no identity token in the credential');

    // 2. The raw nonce to the backend, which hashes it against the token's.
    final SocialAuthResult result = await _flow.token(
      name,
      idToken: idToken,
      nonce: nonce,
      authorizationCode: credential.authorizationCode,
      intent: intent,
      proof: proof,
    );

    // 3. The name exists only in this credential; hand it on with the result.
    return AppleSignInResult(
      result,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }

  Future<AuthorizationCredentialAppleID> _credential(Nonce nonce) async {
    try {
      return await requestCredential(nonce.hashed);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const SocialAuthCancelledException();
      }

      throw _sdkError('${error.code.name} ${error.message}');
    } on SignInWithAppleException catch (error) {
      throw _sdkError('$error');
    }
  }

  SocialAuthException _sdkError(String detail) {
    Log.error('Apple sign-in failed: $detail');

    return const SocialAuthException(
      'Apple sign-in could not be completed.',
      code: 'sdk_error',
    );
  }
}
