/// `clide_broker`, the web broker's command line (D-117, D-118, D-121). Run
/// it inside the container, where the store's environment is set.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'auth/secrets.dart';
import 'environment.dart';
import 'http/server.dart';
import 'serve_config.dart';
import 'settings.dart';
import 'store/broker_store.dart';
import 'store/location.dart';
import 'supervise/caddy.dart';
import 'supervise/hosts.dart';
import 'workspaces.dart';

const _usage =
    '''
Usage: clide_broker <command>

  serve --socket <path> [--caddy <caddy> --caddy-config <Caddyfile>]
        [--users <dir>] [--host <host>]
                             Answer Caddy on a unix socket until stopped.
                             With --caddy, also run Caddy, and start it again
                             whenever it exits. With --host, start a
                             workspace's host when a session first needs it.
                             Workspaces are the folders in <dir>/<N>/projects
                             ($defaultUsersRoot by default).
  workspaces [--users <dir>] List user 0's workspaces, and the folders skipped.
  token rotate               Issue a new access token, end every session it
                             had, and print the sign-in link.
  signin-link                Print a sign-in link that works once, for ten
                             minutes: OIDC mode's way in when the provider is
                             down.
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

/// How long a single-use sign-in link works (D-118).
const signinLinkLifetime = Duration(minutes: 10);

/// Runs one command and answers its exit code. [environment] stands in for
/// the process environment, and [out] and [err] for its output streams.
/// `serve` runs until [stop] completes, or until SIGTERM or SIGINT when it
/// is null. [caddyStartupGrace] is how long Caddy must stay up at first.
Future<int> runBrokerCli(
  List<String> args, {
  required Map<String, String> environment,
  required StringSink out,
  required StringSink err,
  Future<void>? stop,
  DateTime Function()? clock,
  Duration caddyStartupGrace = const Duration(seconds: 5),
}) async {
  if (args.isEmpty) {
    err.writeln(_usage);
    return exitUsage;
  }
  final now = clock ?? DateTime.now;
  switch (args) {
    case ['help' || '--help' || '-h']:
      out.writeln(_usage);
      return 0;
    case ['settings', ...final rest]:
      return _settings(rest, environment, out, err);
    case ['serve', ...final rest]:
      final options = _serveOptions(rest);
      if (options == null) {
        err.writeln(_usage);
        return exitUsage;
      }
      final caddy = switch (options.caddy) {
        (final executable, final caddyfile) => CaddySupervisor(executable: executable, config: caddyfile, log: err.writeln, startupGrace: caddyStartupGrace),
        null => null,
      };
      return _withStore(environment, err, (store) => _serve(options, caddy, store, environment, err, stop, now));
    case ['workspaces']:
      return _workspaces(const WorkspaceRegistry(defaultUsersRoot), out, err);
    case ['workspaces', '--users', final root] when root.startsWith('/'):
      return _workspaces(WorkspaceRegistry(root), out, err);
    case ['token', 'rotate']:
      return _withStore(environment, err, (store) => _rotateToken(store, environment, out, err));
    case ['signin-link']:
      return _withStore(environment, err, (store) => _signinLink(store, environment, out, err, now));
    default:
      err.writeln('Unknown command "${args.join(' ')}".\n\n$_usage');
      return exitUsage;
  }
}

/// Opens the store from [environment], runs [body], and closes the store.
Future<int> _withStore(Map<String, String> environment, StringSink err, Future<int> Function(BrokerStore store) body) async {
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
    return await body(store);
  } on BrokerConfigException catch (e) {
    err.writeln(e.message);
    return exitConfig;
  } finally {
    await store.close();
  }
}

typedef _ServeOptions = ({String socket, (String, String)? caddy, String users, String? host});

/// `serve`'s options, or null when they are incomplete: each flag at most
/// once with its value, `--caddy` and `--caddy-config` together, and every
/// path absolute.
_ServeOptions? _serveOptions(List<String> args) {
  const flags = {'--socket', '--caddy', '--caddy-config', '--users', '--host'};
  final values = <String, String>{};
  for (var i = 0; i < args.length; i += 2) {
    if (!flags.contains(args[i]) || i + 1 >= args.length || values.containsKey(args[i])) return null;
    values[args[i]] = args[i + 1];
  }
  final socket = values['--socket'];
  final caddy = values['--caddy'];
  final caddyfile = values['--caddy-config'];
  if (socket == null || (caddy == null) != (caddyfile == null)) return null;
  if (values.values.any((path) => !path.startsWith('/'))) return null;
  return (socket: socket, caddy: caddy == null ? null : (caddy, caddyfile!), users: values['--users'] ?? defaultUsersRoot, host: values['--host']);
}

/// Serves on the options' socket and, given [caddy], runs Caddy once the
/// socket is up (D-120). On the way out Caddy stops first, so nothing new
/// arrives, then the open sessions end, then the hosts stop.
Future<int> _serve(
  _ServeOptions options,
  CaddySupervisor? caddy,
  BrokerStore store,
  Map<String, String> environment,
  StringSink err,
  Future<void>? stop,
  DateTime Function() now,
) async {
  void log(String line) => err.writeln('clide_broker: $line');
  final config = await ServeConfig.resolve(BrokerSettings(store, environment), store);
  final workspaces = WorkspaceRegistry(options.users);
  _reportWorkspaces(workspaces, log);
  final hosts = switch (options.host) {
    final host? => HostManager(executable: host, runtimeDirectory: File(options.socket).parent.path, environment: environment, log: log),
    null => null,
  };
  if (hosts == null) log('no --host was given, so sessions cannot open');
  final server = await BrokerServer.bind(options.socket, store: store, config: config, workspaces: workspaces, hosts: hosts, clock: now, log: log);
  if (caddy != null) {
    try {
      await caddy.start();
    } on Exception catch (e) {
      await server.close();
      log(e is ProcessException ? 'Caddy could not be started: ${e.message}' : '$e');
      return exitConfig;
    }
  }
  log('serving ${config.publicOrigin} on ${options.socket}${caddy == null ? '' : ', behind Caddy'}');
  await (stop ?? _terminated());
  await caddy?.stop();
  await server.close();
  await hosts?.stop();
  log('stopped');
  return 0;
}

/// Names what the registry finds for user 0, and each folder it skips.
void _reportWorkspaces(WorkspaceRegistry workspaces, void Function(String line) log) {
  try {
    final scan = workspaces.scan(0);
    final count = scan.slugs.length;
    log('$count ${count == 1 ? 'workspace' : 'workspaces'} in ${workspaces.projects(0)}');
    for (final folder in scan.skipped) {
      log('skipped the folder ${jsonEncode(folder.name)}: ${folder.reason}');
    }
  } on BrokerConfigException catch (e) {
    log(e.message);
  }
}

/// `clide_broker workspaces`: user 0's workspaces on [out], one per line, and
/// the folders skipped on [err], with why.
int _workspaces(WorkspaceRegistry workspaces, StringSink out, StringSink err) {
  final ({List<String> slugs, List<SkippedFolder> skipped}) scan;
  try {
    scan = workspaces.scan(0);
  } on BrokerConfigException catch (e) {
    err.writeln(e.message);
    return exitConfig;
  }
  scan.slugs.forEach(out.writeln);
  for (final folder in scan.skipped) {
    err.writeln('Skipped the folder ${jsonEncode(folder.name)}: ${folder.reason}.');
  }
  return 0;
}

Future<int> _rotateToken(BrokerStore store, Map<String, String> environment, StringSink out, StringSink err) async {
  final origin = (await BrokerSettings(store, environment).get('public_origin')).value;
  final token = randomSecret();
  await store.rotateToken(0, secretHash(token));
  out.writeln(origin == null ? token : '${Uri.parse(origin).origin}/auth/login#token=$token');
  err.writeln('Issued a new access token for user 0 and ended every session it had.');
  if (origin == null) err.writeln('Set public_origin to have the whole sign-in link printed.');
  return 0;
}

Future<int> _signinLink(BrokerStore store, Map<String, String> environment, StringSink out, StringSink err, DateTime Function() now) async {
  final settings = BrokerSettings(store, environment);
  if ((await settings.get('signin.mode')).value != 'oidc') {
    err.writeln('A single-use sign-in link is for OIDC mode. In token mode, sign in with the access token; `clide_broker token rotate` issues a new one.');
    return exitUsage;
  }
  final origin = (await settings.get('public_origin')).value;
  if (origin == null) throw BrokerConfigException('public_origin is not set, so there is no link to print.');
  final link = randomSecret();
  final expires = now().add(signinLinkLifetime);
  await store.putSigninLink(secretHash(link), 0, expires);
  out.writeln('${Uri.parse(origin).origin}/auth/login#link=$link');
  err.writeln('The link signs in user 0 once, until ${expires.toUtc().toIso8601String()}.');
  return 0;
}

/// Completes on the first SIGTERM or SIGINT.
Future<void> _terminated() => firstEvent([ProcessSignal.sigterm.watch(), ProcessSignal.sigint.watch()]);

/// Completes on the first event of any of [streams], then stops listening
/// to all of them.
Future<void> firstEvent(List<Stream<Object?>> streams) {
  final done = Completer<void>();
  final subscriptions = <StreamSubscription<Object?>>[];
  for (final stream in streams) {
    subscriptions.add(
      stream.listen((_) {
        for (final s in subscriptions) {
          unawaited(s.cancel());
        }
        if (!done.isCompleted) done.complete();
      }),
    );
  }
  return done.future;
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

  return _withStore(environment, err, (store) async {
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
  });
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
