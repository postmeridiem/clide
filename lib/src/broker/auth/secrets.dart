/// The secrets the broker hands out, and the hashes it keeps instead of
/// them (D-118). A token, a session id or a sign-in link reaches the store
/// only as its SHA-256.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A random secret with [bytes] of entropy, in base64url without padding,
/// so that it is safe in a URL fragment, a form field and a cookie.
String randomSecret({int bytes = 32}) {
  final random = Random.secure();
  return base64Url.encode(List<int>.generate(bytes, (_) => random.nextInt(256))).replaceAll('=', '');
}

/// Whether [value] could be a secret [randomSecret] made. Anything else is
/// refused before it is hashed or looked up.
bool looksLikeSecret(String value) => _secretShape.hasMatch(value);

final _secretShape = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

/// What the store keeps for [secret]: its SHA-256, in hex. The secrets are
/// random and long, so a plain hash is enough; there is nothing to guess.
String secretHash(String secret) => sha256.convert(utf8.encode(secret)).toString();

/// Compares two hashes in time that does not depend on where they differ.
bool sameHash(String a, String b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}
