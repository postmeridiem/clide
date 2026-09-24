/// SCRAM-SHA-256 (RFC 5802, RFC 7677), the client's side, as Postgres uses
/// it: no channel binding, and the user name left empty, since the server
/// takes it from the startup message.
///
/// The exchange is mutual. The client proves it knows the password without
/// sending it, and the server's final message proves that the server holds
/// the role's verifier, so a server that is not the real one fails here.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The exchange failed, or the server's messages were not acceptable.
class ScramException implements Exception {
  ScramException(this.message);

  final String message;

  @override
  String toString() => 'ScramException: $message';
}

/// One SCRAM-SHA-256 exchange, from the client's side.
final class ScramClient {
  ScramClient(this._password, {String user = '', String? nonce}) : _user = user, _nonce = nonce ?? _randomNonce();

  static const mechanism = 'SCRAM-SHA-256';

  /// The fewest iterations accepted. RFC 7677 asks for at least 4096; a
  /// lower count from a server makes a captured exchange cheaper to crack.
  static const minIterations = 4096;

  /// The most iterations accepted, so that a hostile server cannot make the
  /// client spin.
  static const maxIterations = 1000000;

  final String _password;
  final String _user;
  final String _nonce;
  String? _authMessage;
  List<int>? _serverKey;

  /// The first message: no channel binding, then the bare part.
  String get clientFirstMessage => 'n,,$_clientFirstBare';

  String get _clientFirstBare => 'n=${_user.replaceAll('=', '=3D').replaceAll(',', '=2C')},r=$_nonce';

  /// Answers [serverFirst] with the final message, which carries the proof.
  String clientFinalMessage(String serverFirst) {
    final attributes = _attributes(serverFirst);
    final serverNonce = attributes['r'];
    if (serverNonce == null || serverNonce.length <= _nonce.length || !serverNonce.startsWith(_nonce)) {
      throw ScramException("the server's nonce does not extend the client's");
    }
    final List<int> salt;
    try {
      salt = base64.decode(attributes['s'] ?? '');
    } on FormatException {
      throw ScramException("the server's salt is not base64");
    }
    if (salt.isEmpty) throw ScramException('the server sent no salt');
    final iterations = int.tryParse(attributes['i'] ?? '');
    if (iterations == null || iterations < minIterations || iterations > maxIterations) {
      throw ScramException('the server asked for an iteration count outside $minIterations to $maxIterations');
    }

    final saltedPassword = _hi(utf8.encode(_password), salt, iterations);
    final clientKey = _hmac(saltedPassword, 'Client Key');
    final storedKey = sha256.convert(clientKey).bytes;
    final withoutProof = 'c=biws,r=$serverNonce';
    final authMessage = '$_clientFirstBare,$serverFirst,$withoutProof';
    final clientSignature = _hmac(storedKey, authMessage);
    final proof = [for (var i = 0; i < clientKey.length; i++) clientKey[i] ^ clientSignature[i]];
    _authMessage = authMessage;
    _serverKey = _hmac(saltedPassword, 'Server Key');
    return '$withoutProof,p=${base64.encode(proof)}';
  }

  /// Checks the server's final message, whose signature only a server
  /// holding the role's verifier can produce.
  void verifyServerFinal(String serverFinal) {
    final authMessage = _authMessage;
    final serverKey = _serverKey;
    if (authMessage == null || serverKey == null) throw ScramException('the server finished before the client sent its proof');
    final attributes = _attributes(serverFinal);
    final error = attributes['e'];
    if (error != null) throw ScramException('the server refused the proof: $error');
    final List<int> signature;
    try {
      signature = base64.decode(attributes['v'] ?? '');
    } on FormatException {
      throw ScramException("the server's signature is not base64");
    }
    if (!_equal(signature, _hmac(serverKey, authMessage))) {
      throw ScramException("the server's signature is wrong, so it does not hold this role's verifier");
    }
  }

  /// A message's `key=value` attributes. An unknown mandatory extension
  /// (`m=`) ends the exchange, as RFC 5802 requires.
  static Map<String, String> _attributes(String message) {
    final attributes = <String, String>{};
    for (final part in message.split(',')) {
      final eq = part.indexOf('=');
      if (eq != 1) throw ScramException('a malformed attribute in the server message');
      attributes[part.substring(0, 1)] = part.substring(2);
    }
    if (attributes.containsKey('m')) throw ScramException('the server requires an extension the client does not support');
    return attributes;
  }

  static String _randomNonce() {
    final random = Random.secure();
    return base64.encode(List<int>.generate(18, (_) => random.nextInt(256)));
  }
}

/// `Hi` from RFC 5802: PBKDF2 with HMAC-SHA-256, one block.
List<int> _hi(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final result = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= u[j];
    }
  }
  return result;
}

List<int> _hmac(List<int> key, String message) => Hmac(sha256, key).convert(utf8.encode(message)).bytes;

/// Compares in time that does not depend on where the inputs differ.
bool _equal(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
