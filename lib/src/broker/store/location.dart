/// Where the broker's store is. The environment the container runs with is
/// the only source (D-121): the image carries no store configuration and no
/// default, so a broker started without one refuses to run.
library;

import 'dart:io';

import '../environment.dart';

/// Where the broker's store is: a SQLite file or a Postgres database.
sealed class StoreLocation {
  const StoreLocation();

  /// Chooses the store: `sqlite:/path/to/broker.db` or
  /// `postgres://user@host:5432/database`.
  static const variable = 'CLIDE_BROKER_STORE';

  /// The Postgres password, when the server asks for one. Its `_FILE`
  /// variant names a file that holds it instead.
  static const passwordVariable = 'CLIDE_BROKER_STORE_PASSWORD';

  static const _forms = 'sqlite:/clide/state/broker.db, or postgres://user@host:5432/database with the password in $passwordVariable';

  /// Reads the store's location from [environment].
  static StoreLocation fromEnvironment(Map<String, String> environment) {
    final raw = (environment[variable] ?? '').trim();
    if (raw.isEmpty) throw BrokerConfigException('$variable is not set. Set it where the container runs: $_forms.');
    if (raw.startsWith('sqlite:')) {
      var path = raw.substring('sqlite:'.length);
      if (path.startsWith('//')) path = path.substring(2);
      if (path.isEmpty || !File(path).isAbsolute) throw BrokerConfigException('$variable must name an absolute path: sqlite:/path/to/broker.db.');
      return SqliteLocation(path);
    }
    final scheme = raw.contains('://') ? raw.substring(0, raw.indexOf('://')) : null;
    if (scheme != 'postgres' && scheme != 'postgresql') {
      throw BrokerConfigException('$variable must start with sqlite: or postgres://. Use $_forms.');
    }
    final Uri uri;
    try {
      uri = Uri.parse(raw);
    } on FormatException {
      throw BrokerConfigException('$variable is not a valid postgres:// URL.');
    }
    if (uri.userInfo.contains(':')) {
      throw BrokerConfigException('$variable must not carry a password. Put it in $passwordVariable instead.');
    }
    if (uri.userInfo.isEmpty) throw BrokerConfigException('$variable names no user: postgres://user@host:5432/database.');
    if (uri.host.isEmpty) throw BrokerConfigException('$variable names no host: postgres://user@host:5432/database.');
    final database = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (database.length != 1) throw BrokerConfigException('$variable must name one database: postgres://user@host:5432/database.');
    final options = uri.queryParameters;
    for (final name in options.keys) {
      if (name != 'sslmode' && name != 'sslrootcert') {
        throw BrokerConfigException('$variable has an option this broker does not know: $name. It knows sslmode and sslrootcert.');
      }
    }
    final sslMode = switch (options['sslmode']) {
      null || 'verify-full' => SslMode.verifyFull,
      'require' => SslMode.require,
      'disable' => SslMode.disable,
      _ => throw BrokerConfigException('$variable has an sslmode this broker does not use. Use verify-full, require or disable.'),
    };
    final rootCert = options['sslrootcert'];
    if (rootCert != null) {
      if (sslMode != SslMode.verifyFull) throw BrokerConfigException('$variable sets sslrootcert, which only sslmode=verify-full uses.');
      if (!File(rootCert).isAbsolute) throw BrokerConfigException('$variable must give sslrootcert as an absolute path.');
    }
    return PostgresLocation(
      user: Uri.decodeComponent(uri.userInfo),
      host: uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: Uri.decodeComponent(database.single),
      sslMode: sslMode,
      sslRootCert: rootCert,
    );
  }
}

/// How the broker secures its connection to Postgres (D-121).
enum SslMode {
  /// TLS, with the certificate checked against trusted roots and the host.
  verifyFull,

  /// TLS without checking the certificate.
  require,

  /// No TLS, for a database on a private network.
  disable,
}

/// The store in one SQLite file.
final class SqliteLocation extends StoreLocation {
  const SqliteLocation(this.path);

  final String path;
}

/// The store in a Postgres database.
final class PostgresLocation extends StoreLocation {
  const PostgresLocation({
    required this.user,
    required this.host,
    required this.port,
    required this.database,
    this.sslMode = SslMode.verifyFull,
    this.sslRootCert,
  });

  final String user;
  final String host;
  final int port;
  final String database;
  final SslMode sslMode;

  /// A PEM file of the certificate authorities to trust instead of the
  /// system's, for a server behind a private CA.
  final String? sslRootCert;

  /// The password from [environment], or null when none is set.
  String? password(Map<String, String> environment, {String Function(String path)? readFile}) =>
      secretFromEnvironment(environment, StoreLocation.passwordVariable, readFile: readFile);
}
