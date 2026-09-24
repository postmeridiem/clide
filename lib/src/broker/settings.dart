/// The broker's settings (D-121). A plain setting lives in the store, and an
/// environment variable named for it overrides it without writing it. A
/// secret never enters the store: it comes from its own variable, or from
/// the file that variable's `_FILE` variant names.
library;

import 'environment.dart';
import 'store/broker_store.dart';

/// One setting: its key, what it means, and what a valid value is.
final class SettingSpec {
  const SettingSpec(this.key, this.help, {this.secret = false, this.fallback, this.check});

  final String key;
  final String help;

  /// Read from the environment only, and never printed.
  final bool secret;

  /// The value when nothing sets one.
  final String? fallback;

  /// Answers what is wrong with a value, or null when it is fine.
  final String? Function(String value)? check;

  /// The environment variable that sets or overrides this setting.
  String get variable => 'CLIDE_BROKER_${key.toUpperCase().replaceAll('.', '_')}';
}

/// Where a setting's value came from.
enum SettingSource { environment, store, fallback, unset }

/// A setting's value, resolved.
final class Setting {
  const Setting(this.spec, this.value, this.source, {this.problem});

  final SettingSpec spec;

  /// The value, or null when it is unset or invalid.
  final String? value;
  final SettingSource source;

  /// Why the value that was found is not usable, when it isn't.
  final String? problem;

  /// The value as it may be shown. A secret never is.
  String get shown {
    if (problem != null) return '(invalid)';
    if (spec.secret) return value == null ? '(unset)' : '(set)';
    return value ?? '(unset)';
  }
}

/// Every setting the broker reads.
const brokerSettings = <SettingSpec>[
  SettingSpec('public_origin', 'The origin browsers reach this install at, such as https://clide.example.com.', check: _httpsOrigin),
  SettingSpec('signin.mode', 'How browsers sign in: token or oidc (D-118).', check: _signinMode),
  SettingSpec('session.lifetime_hours', 'How long a session lasts before the browser signs in again.', fallback: '336', check: _hours),
  SettingSpec('oidc.issuer', "The OIDC provider's issuer URL.", check: _httpsUrl),
  SettingSpec('oidc.client_id', 'The client id registered at the provider.'),
  SettingSpec('oidc.client_secret', 'The client secret, for a confidential client.', secret: true),
  SettingSpec('oidc.scopes', 'The scopes to request, separated by spaces.', fallback: 'openid profile email', check: _scopes),
  SettingSpec('oidc.allow.subjects', 'Subjects allowed to sign in, separated by commas.'),
  SettingSpec('oidc.allow.emails', 'Verified email addresses allowed to sign in, separated by commas.'),
  SettingSpec('oidc.allow.groups', 'Groups whose members may sign in, separated by commas.'),
  SettingSpec('oidc.groups_claim', 'The ID-token claim that lists the groups.', fallback: 'groups'),
  SettingSpec('oidc.ca_file', 'A PEM file of extra certificate authorities for reaching the provider.', check: _absolutePath),
];

/// The broker's settings, from its store and its environment.
final class BrokerSettings {
  BrokerSettings(this._store, this._environment, {String Function(String path)? readFile}) : _readFile = readFile;

  final BrokerStore _store;
  final Map<String, String> _environment;
  final String Function(String path)? _readFile;

  /// The spec for [key]; throws when no setting has that key.
  static SettingSpec spec(String key) {
    for (final s in brokerSettings) {
      if (s.key == key) return s;
    }
    throw BrokerConfigException('There is no setting "$key". `clide_broker settings list` shows them all.');
  }

  /// Every setting, resolved.
  Future<List<Setting>> all() async {
    final stored = await _store.settings();
    return [for (final spec in brokerSettings) _resolve(spec, stored)];
  }

  /// One setting, resolved.
  Future<Setting> get(String key) async {
    final s = spec(key);
    return _resolve(s, await _store.settings());
  }

  /// Stores [value] for [key]. Answers the environment variable that
  /// overrides the stored value, when one is set, since the value only takes
  /// effect once that variable is gone.
  Future<String?> set(String key, String value) async {
    final s = _storable(key);
    final problem = s.check?.call(value);
    if (problem != null) throw BrokerConfigException('$key: $problem');
    await _store.putSetting(key, value);
    return _environmentValue(s) == null ? null : s.variable;
  }

  /// Removes [key]'s stored value and answers whether there was one.
  Future<bool> unset(String key) async => _store.deleteSetting(_storable(key).key);

  SettingSpec _storable(String key) {
    final s = spec(key);
    if (s.secret) {
      throw BrokerConfigException(
        '$key is a secret, so it is never stored. Set ${s.variable}, or ${s.variable}_FILE naming a file that holds it, where the container runs.',
      );
    }
    return s;
  }

  Setting _resolve(SettingSpec spec, Map<String, String> stored) {
    try {
      if (spec.secret) {
        final value = secretFromEnvironment(_environment, spec.variable, readFile: _readFile);
        return Setting(spec, value, value == null ? SettingSource.unset : SettingSource.environment);
      }
      final fromEnvironment = _environmentValue(spec);
      if (fromEnvironment != null) return _checked(spec, fromEnvironment, SettingSource.environment);
      final fromStore = stored[spec.key];
      if (fromStore != null) return _checked(spec, fromStore, SettingSource.store);
      if (spec.fallback != null) return Setting(spec, spec.fallback, SettingSource.fallback);
      return Setting(spec, null, SettingSource.unset);
    } on BrokerConfigException catch (e) {
      return Setting(spec, null, SettingSource.environment, problem: e.message);
    }
  }

  String? _environmentValue(SettingSpec spec) {
    final value = _environment[spec.variable] ?? '';
    return value.isEmpty ? null : value;
  }

  static Setting _checked(SettingSpec spec, String value, SettingSource source) {
    final problem = spec.check?.call(value);
    return problem == null ? Setting(spec, value, source) : Setting(spec, null, source, problem: problem);
  }
}

String? _httpsOrigin(String value) {
  final uri = Uri.tryParse(value);
  final ok =
      uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment;
  return ok ? null : 'must be an https origin, such as https://clide.example.com';
}

String? _httpsUrl(String value) {
  final uri = Uri.tryParse(value);
  final ok = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty && !uri.hasQuery && !uri.hasFragment;
  return ok ? null : 'must be an https URL with no query or fragment';
}

String? _signinMode(String value) => value == 'token' || value == 'oidc' ? null : 'must be token or oidc';

String? _hours(String value) {
  final hours = int.tryParse(value);
  return hours != null && hours >= 1 && hours <= 8760 ? null : 'must be a whole number of hours from 1 to 8760';
}

String? _scopes(String value) => value.split(' ').contains('openid') ? null : 'must include openid';

String? _absolutePath(String value) => value.startsWith('/') ? null : 'must be an absolute path';
