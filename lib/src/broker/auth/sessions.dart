/// Browser sessions (D-118): a random id in a `__Host-` cookie, kept in the
/// store only as its hash, with a fixed lifetime.
library;

import '../store/broker_store.dart';
import 'secrets.dart';

final class Sessions {
  Sessions(this._store, {required this.lifetime, DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  /// `__Host-` binds the cookie to this exact origin: it must be `Secure`,
  /// have `Path=/` and carry no `Domain`, so no other host can set it.
  static const cookieName = '__Host-clide_session';

  final BrokerStore _store;
  final DateTime Function() _now;
  final Duration lifetime;

  /// Starts a session for [user] and answers the `Set-Cookie` value that
  /// carries it.
  Future<String> start(int user, {required String via, String? subject}) async {
    final id = randomSecret();
    final now = _now();
    await _store.putSession(StoredSession(idHash: secretHash(id), user: user, via: via, subject: subject, createdAt: now, expiresAt: now.add(lifetime)));
    return '$cookieName=$id; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=${lifetime.inSeconds}';
  }

  /// The live session the request's `Cookie` header names, or null.
  Future<StoredSession?> find(String? cookieHeader) async {
    final id = sessionId(cookieHeader);
    return id == null ? null : _store.session(secretHash(id));
  }

  /// Ends the session the `Cookie` header names, if there is one.
  Future<void> end(String? cookieHeader) async {
    final id = sessionId(cookieHeader);
    if (id != null) await _store.endSession(secretHash(id));
  }

  /// The `Set-Cookie` value that removes the cookie from the browser.
  static const clearCookie = '$cookieName=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0';

  /// The session id in a `Cookie` header, when it holds one shaped like a
  /// secret this broker makes.
  static String? sessionId(String? cookieHeader) {
    if (cookieHeader == null) return null;
    for (final part in cookieHeader.split(';')) {
      final eq = part.indexOf('=');
      if (eq < 0 || part.substring(0, eq).trim() != cookieName) continue;
      final value = part.substring(eq + 1).trim();
      return looksLikeSecret(value) ? value : null;
    }
    return null;
  }
}
