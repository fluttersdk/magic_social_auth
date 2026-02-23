import 'package:magic/magic.dart';

import '../models/social_token.dart';
import '../exceptions/social_auth_exception.dart';
import '../facades/social_auth.dart';

/// Handler for processing social auth tokens.
///
/// Override to customize how tokens are processed after provider auth.
///
/// ```dart
/// class FirebaseAuthHandler implements SocialAuthHandler {
///   @override
///   Future<void> handle(SocialToken token) async {
///     final credential = GoogleAuthProvider.credential(
///       idToken: token.idToken,
///       accessToken: token.accessToken,
///     );
///     await FirebaseAuth.instance.signInWithCredential(credential);
///   }
/// }
/// ```
abstract class SocialAuthHandler {
  /// Process the token after provider authentication.
  Future<void> handle(SocialToken token);
}

/// Default handler that sends token to Laravel backend.
///
/// Sends POST to configured endpoint, expects Sanctum token response.
class HttpSocialAuthHandler implements SocialAuthHandler {
  @override
  Future<void> handle(SocialToken token) async {
    final endpoint =
        Config.get<String>('social_auth.endpoint') ?? '/auth/social/{provider}';
    final url = endpoint.replaceAll('{provider}', token.provider);

    final response = await Http.post(url, data: token.toMap());

    if (!response.successful) {
      throw SocialAuthException(
        response['message'] as String? ?? 'Authentication failed',
        code: response['code'] as String?,
      );
    }

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const SocialAuthException('Invalid response format');
    }

    final authToken = data['token'] as String?;
    final userData = data['user'] as Map<String, dynamic>?;

    if (authToken == null || userData == null) {
      throw const SocialAuthException('Missing token or user data');
    }

    final user = SocialAuth.manager.createUser(userData);
    await Auth.login({'token': authToken}, user);
  }
}
