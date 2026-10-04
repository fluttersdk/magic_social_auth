import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// The nonce of one native Apple sign-in.
///
/// Apple gets [hashed] and writes it into the ID token's `nonce` claim; the
/// backend gets [raw] and checks `hash('sha256', raw)` against that claim, so a
/// token replayed from another sign-in fails. Sending [raw] to Apple, or any
/// nonce for Google (the backend prohibits one), breaks the sign-in.
@immutable
class Nonce {
  /// A nonce around a known [raw] value.
  const Nonce.fromRaw(this.raw);

  /// A fresh nonce: 32 secure random bytes, base64url without padding.
  factory Nonce.generate() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(32, (_) => random.nextInt(256));

    return Nonce.fromRaw(base64Url.encode(bytes).replaceAll('=', ''));
  }

  /// What the backend receives as `nonce`.
  final String raw;

  /// Lowercase sha256 hex of [raw]: what Apple receives.
  String get hashed => sha256.convert(utf8.encode(raw)).toString();
}
