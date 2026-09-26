/// What `clide_broker serve` needs, read and checked once at start. The
/// broker refuses to run on anything less (D-118), and names every missing or
/// bad setting at once, so one attempt shows all there is to fix.
library;

import 'dart:io';

import 'auth/oidc.dart';
import 'environment.dart';
import 'settings.dart';
import 'store/broker_store.dart';

/// How browsers sign in (D-118).
enum SigninMode { token, oidc }

final class ServeConfig {
  const ServeConfig({required this.publicOrigin, required this.mode, required this.sessionLifetime, this.oidc});

  /// The origin browsers reach the install at, such as
  /// `https://clide.example.com`. Every `POST` and every session WebSocket
  /// must come from it.
  final String publicOrigin;
  final SigninMode mode;
  final Duration sessionLifetime;

  /// The provider and who may sign in through it, in OIDC mode.
  final OidcSettings? oidc;

  /// Reads the settings [serve] needs, or throws a `BrokerConfigException`
  /// listing everything that stops the broker starting.
  static Future<ServeConfig> resolve(BrokerSettings settings, BrokerStore store) async {
    final all = {for (final s in await settings.all()) s.spec.key: s};
    final problems = <String>[];

    String? read(String key, {bool required = false}) {
      final setting = all[key]!;
      if (setting.problem != null) {
        problems.add('$key: ${setting.problem}');
        return null;
      }
      if (setting.value == null && required) {
        problems.add('$key is not set. Set it with `clide_broker settings set $key …`, or with ${setting.spec.variable} where the container runs.');
      }
      return setting.value;
    }

    final origin = read('public_origin', required: true);
    final mode = read('signin.mode', required: true);
    final hours = read('session.lifetime_hours');
    if (mode == 'token' && await store.tokenHash(0) == null) {
      problems.add('No access token has been issued. Run `clide_broker token rotate`, which prints the sign-in link.');
    }
    OidcSettings? oidc;
    if (mode == 'oidc') {
      final issuer = read('oidc.issuer', required: true);
      final clientId = read('oidc.client_id', required: true);
      final subjects = _list(read('oidc.allow.subjects'));
      final emails = {for (final email in _list(read('oidc.allow.emails'))) email.toLowerCase()};
      final groups = _list(read('oidc.allow.groups'));
      final caFile = read('oidc.ca_file');
      // Signing in at the provider is not enough: without an allowlist,
      // anyone with an account there would be in (D-118).
      if (subjects.isEmpty && emails.isEmpty && groups.isEmpty) {
        problems.add('OIDC mode needs an allowlist: set oidc.allow.subjects, oidc.allow.emails or oidc.allow.groups.');
      }
      if (caFile != null && !File(caFile).existsSync()) problems.add('oidc.ca_file: there is no file at $caFile.');
      oidc = OidcSettings(
        issuer: issuer ?? '',
        clientId: clientId ?? '',
        clientSecret: read('oidc.client_secret'),
        scopes: _list(read('oidc.scopes'), separator: ' ').toList(),
        subjects: subjects,
        emails: emails,
        groups: groups,
        groupsClaim: read('oidc.groups_claim') ?? 'groups',
        caFile: caFile,
      );
    }
    if (problems.isNotEmpty) throw BrokerConfigException(['The broker will not start:', for (final p in problems) '  - $p'].join('\n'));
    return ServeConfig(
      publicOrigin: Uri.parse(origin!).origin,
      mode: mode == 'oidc' ? SigninMode.oidc : SigninMode.token,
      sessionLifetime: Duration(hours: int.parse(hours!)),
      oidc: oidc,
    );
  }

  /// The items of a setting that lists them, without blanks.
  static Set<String> _list(String? value, {String separator = ','}) => {
    for (final item in (value ?? '').split(separator))
      if (item.trim().isNotEmpty) item.trim(),
  };
}
