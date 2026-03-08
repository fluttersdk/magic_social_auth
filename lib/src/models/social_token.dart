/// Token and profile data returned by a social provider.
///
/// Contains the access token, optional ID token, and user profile info.
/// Supports two authentication flows:
/// - Token flow: provider returns access_token directly (Google native SDK)
/// - Code exchange flow: provider returns authorization_code (GitHub, Microsoft web)
class SocialToken {
  /// Creates a new social token.
  const SocialToken({
    required this.provider,
    required this.accessToken,
    this.authorizationCode,
    this.idToken,
    this.email,
    this.name,
    this.avatarUrl,
    this.extra,
  });

  /// Provider name ('google', 'microsoft', 'github', etc.)
  final String provider;

  /// OAuth access token.
  final String accessToken;

  /// OAuth authorization code (for code exchange flow).
  ///
  /// When present, backend should exchange this code for a token
  /// instead of using accessToken directly.
  final String? authorizationCode;

  /// ID token (JWT) - available for Google, Microsoft.
  final String? idToken;

  /// User's email address.
  final String? email;

  /// User's display name.
  final String? name;

  /// User's avatar URL.
  final String? avatarUrl;

  /// Additional provider-specific data.
  final Map<String, dynamic>? extra;

  /// Check if this is a code exchange flow (vs token flow).
  bool get isCodeExchange => authorizationCode != null;

  /// Convert to map for API requests.
  Map<String, dynamic> toMap() => {
        'provider': provider,
        'access_token': accessToken,
        if (authorizationCode != null) 'authorization_code': authorizationCode,
        if (idToken != null) 'id_token': idToken,
        if (email != null) 'email': email,
        if (name != null) 'name': name,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (extra != null) ...extra!,
      };
}
