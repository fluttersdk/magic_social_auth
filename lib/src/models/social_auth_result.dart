import 'package:flutter/foundation.dart';

/// What a social flow concluded, read from the backend's JSON answer.
///
/// One shape covers every intent; which fields are set depends on it:
///
/// - sign-in: [token] and [user], and [deletionCancelled] when the sign-in
///   cancelled a scheduled account deletion;
/// - sign-in on an account with confirmed 2FA: [isTwoFactor] and
///   [twoFactorToken], to finish at `auth/two-factor-challenge`;
/// - connect: [connectedProvider];
/// - confirm: [confirmationToken], a single-use step-up proof.
@immutable
class SocialAuthResult {
  const SocialAuthResult({
    this.isTwoFactor = false,
    this.twoFactorToken,
    this.token,
    this.user,
    this.deletionCancelled = false,
    this.connectedProvider,
    this.confirmationToken,
  });

  /// Reads the exchange or native token endpoint answer.
  ///
  /// The 2FA challenge sits at the top level; everything else under `data`.
  factory SocialAuthResult.fromJson(Map<String, dynamic> json) {
    final Object? data = json['data'];
    final Map<String, dynamic> body = data is Map<String, dynamic>
        ? data
        : const {};
    final Object? user = body['user'];

    return SocialAuthResult(
      isTwoFactor: json['two_factor'] == true,
      twoFactorToken: json['two_factor_token'] as String?,
      token: body['token'] as String?,
      user: user is Map<String, dynamic> ? user : null,
      deletionCancelled: body['deletion_cancelled'] == true,
      connectedProvider: body['provider'] as String?,
      confirmationToken: body['confirmation_token'] as String?,
    );
  }

  /// True when the account confirmed 2FA and the sign-in needs its code.
  final bool isTwoFactor;

  /// The challenge token to post with the 2FA code to
  /// `auth/two-factor-challenge`; set only when [isTwoFactor].
  final String? twoFactorToken;

  /// The Sanctum token of a completed sign-in.
  final String? token;

  /// The signed-in user resource.
  final Map<String, dynamic>? user;

  /// True when signing in cancelled a scheduled account deletion.
  final bool deletionCancelled;

  /// The provider a connect linked.
  final String? connectedProvider;

  /// The step-up proof a confirm produced.
  final String? confirmationToken;
}
