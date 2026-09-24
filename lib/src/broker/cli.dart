/// `clide_broker`, the web broker's command line (D-117, D-121). Run it
/// inside the container, where the store's environment is set.
library;

import 'dart:convert';

import 'environment.dart';
import 'settings.dart';
import 'store/broker_store.dart';
import 'store/location.dart';

const _usage = '''
Usage: clide_broker <command>

  settings list [--json]     Every setting, its value and where it came from.
                             A secret shows as (set) or (unset), never its value.
  settings get <key>         One setting's value.
  settings set <key> <value> Store a setting.
  settings unset <key>       Remove a stored setting.

The store comes from CLIDE_BROKER_STORE, which the environment must set.''';

/// Exit codes, from sysexits.
const exitUsage = 64;
const exitData = 65;
const exitUnavailable = 69;
const exitConfig = 78;

/// Runs one command and answers its exit code. [environment] stands in for
/// the process environment, and [out] and [err] for its output streams.
Future<int> runBrokerCli(List<String> args, {required Map<String, String> environment, required StringSink out, required StringSink err}) async {
  if (args.isEmpty) {
    err.writeln(_usage);
    return exitUsage;
  }
  if (const {'help', '--help', '-h'}.contains(args.first)) {
    out.writeln(_usage);
    return 0;
  }
  if (args.first != 'settings') {
    err.writeln('Unknown command "${args.first}".\n\n$_usage');
    return exitUsage;
  }
  return _settings(args.sublist(1), environment, out, err);
}

Future<int> _settings(List<String> args, Map<String, String> environment, StringSink out, StringSink err) async {
  final command = args.isEmpty ? null : args.first;
  final expected = switch (command) {
    'list' => args.length == 1 || (args.length == 2 && args[1] == '--json'),
    'get' || 'unset' => args.length == 2,
    'set' => args.length == 3,
    _ => false,
  };
  if (!expected) {
    err.writeln(_usage);
    return exitUsage;
  }
  // Refuse an unknown key before touching the store.
  if (command != 'list') {
    try {
      BrokerSettings.spec(args[1]);
    } on BrokerConfigException catch (e) {
      err.writeln(e.message);
      return exitUsage;
    }
  }

  final BrokerStore store;
  try {
    store = await BrokerStore.open(StoreLocation.fromEnvironment(environment), environment: environment);
  } on BrokerConfigException catch (e) {
    err.writeln(e.message);
    return exitConfig;
  } on StoreSchemaException catch (e) {
    err.writeln(e.message);
    return exitConfig;
  } on StoreUnavailableException catch (e) {
    err.writeln(e.message);
    return exitUnavailable;
  }

  try {
    final settings = BrokerSettings(store, environment);
    switch (command) {
      case 'list':
        final all = await settings.all();
        if (args.length == 2) {
          out.writeln(const JsonEncoder.withIndent('  ').convert([for (final s in all) _json(s)]));
        } else {
          final width = all.map((s) => s.spec.key.length).reduce((a, b) => a > b ? a : b);
          final shownWidth = all.map((s) => s.shown.length).reduce((a, b) => a > b ? a : b);
          for (final s in all) {
            out.writeln('${s.spec.key.padRight(width)}  ${s.shown.padRight(shownWidth)}  ${_source(s)}');
          }
        }
        return 0;
      case 'get':
        final s = await settings.get(args[1]);
        if (s.spec.secret) {
          err.writeln('${s.spec.key} is a secret and is never printed. `clide_broker settings list` shows whether it is set.');
          return exitUsage;
        }
        if (s.problem != null) {
          err.writeln('${s.spec.key} from ${_source(s)}: ${s.problem}');
          return exitConfig;
        }
        if (s.value == null) {
          err.writeln('${s.spec.key} is not set.');
          return 1;
        }
        out.writeln(s.value);
        return 0;
      case 'set':
        final String? overriddenBy;
        try {
          overriddenBy = await settings.set(args[1], args[2]);
        } on BrokerConfigException catch (e) {
          err.writeln(e.message);
          return exitData;
        }
        if (overriddenBy != null) {
          err.writeln('Stored ${args[1]}, but $overriddenBy overrides it while that variable is set.');
        }
        return 0;
      default: // 'unset'
        final bool removed;
        try {
          removed = await settings.unset(args[1]);
        } on BrokerConfigException catch (e) {
          err.writeln(e.message);
          return exitData;
        }
        if (!removed) err.writeln('${args[1]} had no stored value.');
        return 0;
    }
  } finally {
    await store.close();
  }
}

String _source(Setting s) => switch (s.source) {
  SettingSource.environment => 'environment (${s.spec.variable})',
  SettingSource.store => 'store',
  SettingSource.fallback => 'default',
  SettingSource.unset => 'unset',
};

Map<String, Object?> _json(Setting s) => {
  'key': s.spec.key,
  'value': s.spec.secret ? null : s.value,
  'set': s.value != null,
  'secret': s.spec.secret,
  'source': s.source.name,
  'variable': s.spec.variable,
  if (s.problem != null) 'problem': s.problem,
};
