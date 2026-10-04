import 'package:magic/magic.dart' show MagicResponse;

/// Base exception for social authentication errors.
///
/// A backend refusal carries its machine [code] (`social_email_taken`,
/// `flow_expired`, `step_up_required`, ...); switch on that, never on
/// [message], which the backend translates.
class SocialAuthException implements Exception {
  const SocialAuthException(this.message, {this.code, this.statusCode});

  /// Reads a refusal's `{message, code}` body.
  ///
  /// A response with no JSON body (a transport failure answers status 0) falls
  /// back to the transport's own message.
  factory SocialAuthException.fromResponse(MagicResponse response) {
    final Object? body = response.data;
    final Map<dynamic, dynamic> json = body is Map ? body : const {};

    return SocialAuthException(
      json['message'] as String? ??
          response.message ??
          'The request failed with status ${response.statusCode}.',
      code: json['code'] as String?,
      statusCode: response.statusCode,
    );
  }

  /// Error message.
  final String message;

  /// The backend's refusal code, or the `error` a browser callback carried.
  final String? code;

  /// The HTTP status of a refused request; null when no request failed.
  final int? statusCode;

  @override
  String toString() =>
      'SocialAuthException: $message${code != null ? ' ($code)' : ''}';
}

/// Thrown when a sign-in ends without an answer: the user closed the sheet,
/// or another flow took the browser.
///
/// The message invites a retry because an Android Auth Tab whose App Link
/// verification failed closes instantly and reports exactly this
/// (flutter_web_auth_2 #215), so a cancel is not always the user's.
class SocialAuthCancelledException extends SocialAuthException {
  const SocialAuthCancelledException({this.superseded = false})
    : super('The sign-in was cancelled or did not finish. Please try again.');

  /// True when another flow owns the browser: a newer web start superseded
  /// this one, or a mobile flow was already open. The newer flow reports the
  /// outcome, so a caller seeing this stays quiet.
  final bool superseded;
}

/// Thrown when a provider is not supported on the current platform.
class UnsupportedPlatformException extends SocialAuthException {
  const UnsupportedPlatformException(super.message);
}

/// Thrown when a provider is not configured or enabled.
class ProviderNotConfiguredException extends SocialAuthException {
  const ProviderNotConfiguredException(String provider)
    : super('Provider "$provider" is not configured');
}
