/// What `clide_broker serve` needs, read and checked once at start. The
/// broker refuses to run on anything less (D-118), and names every missing or
/// bad setting at once, so one attempt shows all there is to fix.
library;

import 'environment.dart';
import 'settings.dart';
import 'store/broker_store.dart';

/// How browsers sign in (D-118).
enum SigninMode { token, oidc }

final class ServeConfig {
  const ServeConfig({required this.publicOrigin, required this.mode, required this.sessionLifetime});

  /// The origin browsers reach the install at, such as
  /// `https://clide.example.com`. Every `POST` and every session WebSocket
  /// must come from it.
  final String publicOrigin;
  final SigninMode mode;
  final Duration sessionLifetime;

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
    if (mode == 'oidc') problems.add('This broker cannot sign in with OIDC yet. Set signin.mode to token.');
    if (mode == 'token' && await store.tokenHash(0) == null) {
      problems.add('No access token has been issued. Run `clide_broker token rotate`, which prints the sign-in link.');
    }
    if (problems.isNotEmpty) throw BrokerConfigException(['The broker will not start:', for (final p in problems) '  - $p'].join('\n'));
    return ServeConfig(
      publicOrigin: Uri.parse(origin!).origin,
      mode: mode == 'oidc' ? SigninMode.oidc : SigninMode.token,
      sessionLifetime: Duration(hours: int.parse(hours!)),
    );
  }
}
