/// The broker's store (D-121): its settings, the access-token hash,
/// sessions, single-use sign-in links and OIDC sign-ins in progress.
///
/// Anything that could sign someone in arrives here already hashed; the store
/// never sees a token, a session id or a link itself. Times are integer
/// milliseconds, and every table carries the `broker_` prefix so that a
/// shared database can hold them.
library;

import '../environment.dart';
import 'location.dart';
import 'sql.dart';

/// The store holds a schema this broker does not know how to use.
class StoreSchemaException implements Exception {
  StoreSchemaException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A signed-in browser, as the store keeps it.
final class StoredSession {
  const StoredSession({required this.idHash, required this.user, required this.via, this.subject, required this.createdAt, required this.expiresAt});

  /// The hash of the session id the browser holds in its cookie.
  final String idHash;

  /// The web user, `N` in `/u/<N>/`.
  final int user;

  /// How the browser signed in: `token`, `link` or `oidc`.
  final String via;

  /// The provider's subject, for an OIDC sign-in.
  final String? subject;

  final DateTime createdAt;
  final DateTime expiresAt;
}

/// An OIDC sign-in the browser has started and the provider has not yet
/// sent back.
final class OidcPending {
  const OidcPending({required this.stateHash, required this.nonce, required this.verifier, required this.nextPath, required this.expiresAt});

  /// The hash of the `state` parameter sent to the provider.
  final String stateHash;
  final String nonce;

  /// The PKCE code verifier.
  final String verifier;

  /// Where the browser goes once signed in.
  final String nextPath;
  final DateTime expiresAt;
}

/// The broker's store, on whichever engine [SqlConnection] reaches.
final class BrokerStore {
  BrokerStore(this._sql, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  /// Opens the store at [location] and brings its schema up to date.
  static Future<BrokerStore> open(StoreLocation location, {DateTime Function()? clock}) async {
    final sql = switch (location) {
      SqliteLocation(:final path) => await SqliteConnection.open(path),
      PostgresLocation() => throw BrokerConfigException('This broker cannot use a Postgres store yet. Use a sqlite: path in ${StoreLocation.variable}.'),
    };
    final store = BrokerStore(sql, clock: clock);
    try {
      await store.migrate();
    } catch (_) {
      await sql.close();
      rethrow;
    }
    return store;
  }

  final SqlConnection _sql;
  final DateTime Function() _now;

  int get _nowMs => _now().millisecondsSinceEpoch;

  /// The newest schema version this broker knows.
  static int get schemaVersion => _migrations.length;

  /// Applies the migrations the store has not seen, under the lock that
  /// keeps two brokers from applying them at once. A store whose schema is
  /// newer than this broker's is refused, not guessed at.
  Future<void> migrate() => _sql.transaction(exclusive: true, () async {
    await _sql.execute('CREATE TABLE IF NOT EXISTS broker_schema (version INTEGER NOT NULL)');
    final rows = await _sql.select('SELECT MAX(version) AS version FROM broker_schema');
    final current = rows.single['version'] as int? ?? 0;
    if (current > _migrations.length) {
      throw StoreSchemaException('The store has schema version $current; this broker knows up to ${_migrations.length}. Run a newer broker.');
    }
    for (var version = current + 1; version <= _migrations.length; version++) {
      for (final statement in _migrations[version - 1]) {
        await _sql.execute(statement);
      }
      await _sql.execute(r'INSERT INTO broker_schema (version) VALUES ($1)', [version]);
    }
  });

  Future<void> close() => _sql.close();

  // -- settings -------------------------------------------------------------

  /// Every stored setting, by key.
  Future<Map<String, String>> settings() async => {
    for (final row in await _sql.select('SELECT key, value FROM broker_settings ORDER BY key')) row['key']! as String: row['value']! as String,
  };

  Future<void> putSetting(String key, String value) => _sql.execute(
    r'INSERT INTO broker_settings (key, value, updated_at) VALUES ($1, $2, $3) '
    'ON CONFLICT (key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at',
    [key, value, _nowMs],
  );

  /// Removes a stored setting and answers whether there was one.
  Future<bool> deleteSetting(String key) async => await _sql.execute(r'DELETE FROM broker_settings WHERE key = $1', [key]) == 1;

  // -- the access token -------------------------------------------------------

  /// The hash of [user]'s access token, or null when none has been issued.
  Future<String?> tokenHash(int user) async {
    final rows = await _sql.select(r'SELECT token_hash FROM broker_credentials WHERE user_n = $1', [user]);
    return rows.isEmpty ? null : rows.single['token_hash']! as String;
  }

  /// Replaces [user]'s token hash and ends every session of theirs, so a
  /// rotated token also shuts out whoever held the old one (D-118).
  Future<void> rotateToken(int user, String hash) => _sql.transaction(() async {
    await _sql.execute(
      r'INSERT INTO broker_credentials (user_n, token_hash, rotated_at) VALUES ($1, $2, $3) '
      'ON CONFLICT (user_n) DO UPDATE SET token_hash = excluded.token_hash, rotated_at = excluded.rotated_at',
      [user, hash, _nowMs],
    );
    await _sql.execute(r'DELETE FROM broker_sessions WHERE user_n = $1', [user]);
  });

  // -- sessions ---------------------------------------------------------------

  Future<void> putSession(StoredSession session) => _sql.execute(
    r'INSERT INTO broker_sessions (id_hash, user_n, via, subject, created_at, expires_at) VALUES ($1, $2, $3, $4, $5, $6)',
    [session.idHash, session.user, session.via, session.subject, session.createdAt.millisecondsSinceEpoch, session.expiresAt.millisecondsSinceEpoch],
  );

  /// The live session whose id hashes to [idHash], or null when there is
  /// none or it has expired.
  Future<StoredSession?> session(String idHash) async {
    final rows = await _sql.select(
      r'SELECT id_hash, user_n, via, subject, created_at, expires_at FROM broker_sessions WHERE id_hash = $1 AND expires_at > $2',
      [idHash, _nowMs],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return StoredSession(
      idHash: row['id_hash']! as String,
      user: row['user_n']! as int,
      via: row['via']! as String,
      subject: row['subject'] as String?,
      createdAt: _utc(row['created_at']),
      expiresAt: _utc(row['expires_at']),
    );
  }

  /// Ends one session and answers whether it existed.
  Future<bool> endSession(String idHash) async => await _sql.execute(r'DELETE FROM broker_sessions WHERE id_hash = $1', [idHash]) == 1;

  // -- single-use sign-in links -----------------------------------------------

  Future<void> putSigninLink(String hash, int user, DateTime expiresAt) =>
      _sql.execute(r'INSERT INTO broker_signin_links (hash, user_n, expires_at) VALUES ($1, $2, $3)', [hash, user, expiresAt.millisecondsSinceEpoch]);

  /// Uses up the live link whose value hashes to [hash] and answers its
  /// user, or null when there is none. Of two requests racing for one link,
  /// only the one whose delete removed the row gets the user.
  Future<int?> useSigninLink(String hash) => _sql.transaction(() async {
    final rows = await _sql.select(r'SELECT user_n FROM broker_signin_links WHERE hash = $1 AND expires_at > $2', [hash, _nowMs]);
    if (rows.isEmpty) return null;
    final removed = await _sql.execute(r'DELETE FROM broker_signin_links WHERE hash = $1', [hash]);
    return removed == 1 ? rows.single['user_n']! as int : null;
  });

  // -- OIDC sign-ins in progress ------------------------------------------------

  Future<void> putOidcPending(OidcPending pending) => _sql.execute(
    r'INSERT INTO broker_oidc_pending (state_hash, nonce, verifier, next_path, expires_at) VALUES ($1, $2, $3, $4, $5)',
    [pending.stateHash, pending.nonce, pending.verifier, pending.nextPath, pending.expiresAt.millisecondsSinceEpoch],
  );

  /// Takes the live sign-in whose `state` hashes to [stateHash], so that a
  /// provider's reply is accepted once, or answers null.
  Future<OidcPending?> takeOidcPending(String stateHash) => _sql.transaction(() async {
    final rows = await _sql.select(
      r'SELECT state_hash, nonce, verifier, next_path, expires_at FROM broker_oidc_pending WHERE state_hash = $1 AND expires_at > $2',
      [stateHash, _nowMs],
    );
    if (rows.isEmpty) return null;
    if (await _sql.execute(r'DELETE FROM broker_oidc_pending WHERE state_hash = $1', [stateHash]) != 1) return null;
    final row = rows.single;
    return OidcPending(
      stateHash: row['state_hash']! as String,
      nonce: row['nonce']! as String,
      verifier: row['verifier']! as String,
      nextPath: row['next_path']! as String,
      expiresAt: _utc(row['expires_at']),
    );
  });

  // -- housekeeping -------------------------------------------------------------

  /// Deletes every expired session, link and pending sign-in, and answers
  /// how many rows went.
  Future<int> sweep() => _sql.transaction(() async {
    final now = _nowMs;
    var removed = 0;
    for (final table in const ['broker_sessions', 'broker_signin_links', 'broker_oidc_pending']) {
      removed += await _sql.execute('DELETE FROM $table WHERE expires_at <= \$1', [now]);
    }
    return removed;
  });
}

/// Stored times come back in UTC, whatever the host's zone.
DateTime _utc(Object? milliseconds) => DateTime.fromMillisecondsSinceEpoch(milliseconds! as int, isUtc: true);

/// Schema migrations, oldest first. A released migration never changes;
/// a change to the schema is a new one appended here.
const _migrations = <List<String>>[
  [
    'CREATE TABLE broker_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at BIGINT NOT NULL)',
    'CREATE TABLE broker_credentials (user_n INTEGER PRIMARY KEY, token_hash TEXT NOT NULL, rotated_at BIGINT NOT NULL)',
    'CREATE TABLE broker_sessions (id_hash TEXT PRIMARY KEY, user_n INTEGER NOT NULL, via TEXT NOT NULL, subject TEXT, '
        'created_at BIGINT NOT NULL, expires_at BIGINT NOT NULL)',
    'CREATE INDEX broker_sessions_user ON broker_sessions (user_n)',
    'CREATE INDEX broker_sessions_expiry ON broker_sessions (expires_at)',
    'CREATE TABLE broker_signin_links (hash TEXT PRIMARY KEY, user_n INTEGER NOT NULL, expires_at BIGINT NOT NULL)',
    'CREATE TABLE broker_oidc_pending (state_hash TEXT PRIMARY KEY, nonce TEXT NOT NULL, verifier TEXT NOT NULL, next_path TEXT NOT NULL, '
        'expires_at BIGINT NOT NULL)',
  ],
];
