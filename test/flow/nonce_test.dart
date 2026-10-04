import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_social_auth/src/flow/nonce.dart';

void main() {
  group('Nonce', () {
    test('hashed is the lowercase sha256 hex of raw', () {
      final Nonce nonce = Nonce.generate();

      expect(nonce.hashed, sha256.convert(utf8.encode(nonce.raw)).toString());
      expect(nonce.hashed, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('hashed matches a known sha256 vector', () {
      // php -r "echo hash('sha256', 'abc');"
      expect(
        const Nonce.fromRaw('abc').hashed,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('raw is unpadded base64url of 32 bytes', () {
      final Nonce nonce = Nonce.generate();

      expect(nonce.raw, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(nonce.raw, isNot(nonce.hashed));
    });

    test('every nonce is fresh', () {
      expect(Nonce.generate().raw, isNot(Nonce.generate().raw));
    });
  });
}
