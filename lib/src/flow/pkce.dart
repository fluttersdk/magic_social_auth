import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// An RFC 7636 PKCE pair for one browser flow.
///
/// The backend binds the one-time code a flow ends in to [challenge], so a
/// code intercepted on its way back to the app is worthless without
/// [verifier]. The pair lives in memory for one flow and is never persisted;
/// every flow mints a new one through [Pkce.generate].
@immutable
class Pkce {
  const Pkce._(this.verifier, this.challenge);

  /// A fresh pair from 48 secure random bytes.
  ///
  /// 48 bytes encode to exactly 64 base64url characters with no padding, all
  /// inside the verifier alphabet (`A-Z a-z 0-9 - _`).
  factory Pkce.generate() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(48, (_) => random.nextInt(256));
    final String verifier = _unpadded(base64Url.encode(bytes));

    return Pkce._(verifier, challengeFor(verifier));
  }

  /// Sent once, to the exchange, as `code_verifier`.
  final String verifier;

  /// `base64url(sha256(verifier))` without padding: always 43 characters.
  final String challenge;

  /// The S256 challenge for [verifier].
  static String challengeFor(String verifier) {
    return _unpadded(
      base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes),
    );
  }

  static String _unpadded(String encoded) => encoded.replaceAll('=', '');
}
