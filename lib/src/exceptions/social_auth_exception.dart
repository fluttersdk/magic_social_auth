/// Base exception for social authentication errors.
class SocialAuthException implements Exception {
  const SocialAuthException(this.message, {this.code});

  /// Error message.
  final String message;

  /// Optional error code from provider.
  final String? code;

  @override
  String toString() =>
      'SocialAuthException: $message${code != null ? ' ($code)' : ''}';
}

/// Thrown when user cancels the authentication flow.
class SocialAuthCancelledException extends SocialAuthException {
  const SocialAuthCancelledException()
      : super('Authentication was cancelled by user');
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
