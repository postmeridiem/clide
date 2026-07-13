/// Registers the `env path …` verbs — the CLI half of the per-workspace PATH
/// preset (D-106, T-511; D-6 CLI parity with the Tools settings section).
///
///   `clide env path list`
///   `clide env path set <dir> [<dir> …]`
///   `clide env path add <dir> [<dir> …]`
///   `clide env path remove <dir> [<dir> …]`
///   `clide env path clear`
///   `clide env path capture`
///
/// The argv grammar splits the first two tokens as `subsystem.verb`, so the
/// command id is `env.path` and the sub-verb arrives as the first positional;
/// the trailing `dirs` positional is variadic. Preset reads/writes go through
/// an injected [PathPresetStore] port and mutations are published on
/// [envPathChannel] — keeping this handler Flutter-free so it runs under
/// `dart test`.
///
/// Preset dirs deliberately live OUTSIDE the workspace (`~/.nvm/…`, linuxbrew),
/// so there is no workspace-confinement check here — the guards are absolute
/// paths only (after `~/` expansion) and the T-104 leading-dash rejection.
/// Nonexistent dirs warn (in the `missing` field), never error: a preset may
/// predate the dir it names.
library;

import 'dart:io' show Directory, Platform;

import '../env/path_preset.dart';
import '../env/shell_env.dart' show loginShellPathOrNull, resolvedToolPath;
import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';
import 'ui_command.dart' show MessagePublisher;

/// The MessageBus channel preset mutations publish on; UI surfaces subscribe
/// to reflect a CLI edit (the settings control also re-reads off the store
/// notifier, so this is the event-contract half of D-6).
const envPathChannel = 'env.path';

/// Flutter-free port over the (foundation-bound) SettingsStore, injected so
/// this command runs under `dart test`. main.dart adapts the real store to it.
abstract class PathPresetStore {
  /// The preset for the workspace at [cwd], resolved to its repo identity
  /// ([presetRootFor]) — a worktree reads its main repo's preset.
  List<String> dirsFor(String cwd);

  /// Replace the preset for [cwd]'s repo. An empty [dirs] removes the key.
  Future<void> setFor(String cwd, List<String> dirs);
}

/// Register `env.path`. [store] / [publisher] / [workspaceCwd] are late-bound
/// closures (captured post-boot in main.dart); each may be null in a headless
/// context, in which case the verb degrades to a clear error. [home] /
/// [dirExists] / [loginPath] / [processPath] are test seams over the real
/// environment.
void registerEnvPathCommands(
  DaemonDispatcher d,
  PathPresetStore? Function() store, {
  MessagePublisher? Function()? publisher,
  String? Function()? workspaceCwd,
  String? Function()? home,
  bool Function(String dir)? dirExists,
  String? Function()? loginPath,
  String Function()? processPath,
}) {
  d.register(
    'env.path',
    (req) async => _dispatch(
      req,
      store(),
      publisher?.call(),
      workspaceCwd?.call(),
      home: home ?? () => Platform.environment['HOME'],
      dirExists: dirExists ?? (dir) => Directory(dir).existsSync(),
      loginPath: loginPath ?? loginShellPathOrNull,
      processPath: processPath ?? () => Platform.environment['PATH'] ?? '',
    ),
    schema: const CommandSchema(
      positional: ['action', 'dirs'],
      args: {
        'action': ArgSpec(required: true, rejectLeadingDash: true),
        'dirs': ArgSpec(type: ArgType.stringList, rejectLeadingDash: true, maxItems: 64),
      },
    ),
  );
}

Future<IpcResponse> _dispatch(
  IpcRequest req,
  PathPresetStore? store,
  MessagePublisher? publish,
  String? cwd, {
  required String? Function() home,
  required bool Function(String dir) dirExists,
  required String? Function() loginPath,
  required String Function() processPath,
}) async {
  if (store == null) return _err(req.id, 'settings unavailable in this context');
  if (cwd == null) return _err(req.id, 'no workspace open');
  final action = (req.args['action'] as String?)?.trim();
  final rawDirs = (req.args['dirs'] as List?)?.cast<String>() ?? const <String>[];
  final root = presetRootFor(cwd);

  Future<IpcResponse> mutate(List<String> dirs) async {
    await store.setFor(cwd, dirs);
    publish?.call('cli', envPathChannel, {'action': action, 'root': root, 'dirs': dirs});
    return _ok(req.id, {'root': root, 'dirs': dirs, 'missing': _missing(dirs, dirExists)});
  }

  switch (action) {
    case 'list':
      final dirs = store.dirsFor(cwd);
      return _ok(req.id, {'root': root, 'dirs': dirs, 'missing': _missing(dirs, dirExists), 'effectivePath': applyPathPreset(resolvedToolPath(), dirs)});

    case 'set':
      if (rawDirs.isEmpty) return _err(req.id, 'set requires at least one <dir>', hint: 'to empty the preset use: clide env path clear');
      final (dirs, bad) = _expandAll(rawDirs, home());
      if (bad != null) return _err(req.id, bad, hint: 'preset entries must be absolute paths (or ~/…)');
      return mutate(_dedupe(dirs));

    case 'add':
      if (rawDirs.isEmpty) return _err(req.id, 'add requires at least one <dir>');
      final (dirs, bad) = _expandAll(rawDirs, home());
      if (bad != null) return _err(req.id, bad, hint: 'preset entries must be absolute paths (or ~/…)');
      return mutate(_dedupe([...store.dirsFor(cwd), ...dirs]));

    case 'remove':
      if (rawDirs.isEmpty) return _err(req.id, 'remove requires at least one <dir>');
      final (dirs, bad) = _expandAll(rawDirs, home());
      if (bad != null) return _err(req.id, bad, hint: 'pass the entry exactly as `env path list` shows it');
      final current = store.dirsFor(cwd);
      final drop = dirs.toSet();
      final kept = current.where((d) => !drop.contains(d)).toList();
      if (kept.length == current.length) {
        return _err(req.id, 'no preset entry matches ${dirs.join(", ")}', hint: 'clide env path list');
      }
      return mutate(kept);

    case 'clear':
      return mutate(const []);

    case 'capture':
      final dirs = store.dirsFor(cwd);
      final login = loginPath();
      final proc = processPath();
      final suggested = missingLoginShellDirs(loginPath: login, processPath: proc).where((d) => !dirs.contains(d)).toList();
      return _ok(req.id, {
        'root': root,
        'suggested': suggested,
        'loginShellPath': login,
        'processPath': proc,
        if (login == null) 'note': 'login-shell PATH probe unavailable; nothing to diff',
      });

    default:
      return _err(
        req.id,
        'unknown env path action: ${action == null || action.isEmpty ? '(none)' : action}',
        hint: 'use: list | set | add | remove | clear | capture',
      );
  }
}

/// Expand a leading `~/` against [home] and require absolute results. Returns
/// the expanded list, or an error message on the first bad entry.
(List<String>, String?) _expandAll(List<String> dirs, String? home) {
  final out = <String>[];
  for (final raw in dirs) {
    var d = raw.trim();
    if (d.isEmpty) return (out, 'empty preset entry');
    if (d == '~' || d.startsWith('~/')) {
      if (home == null || home.isEmpty) return (out, 'cannot expand "~" (no HOME)');
      d = d == '~' ? home : '$home${d.substring(1)}';
    }
    final absolute = d.startsWith('/') || RegExp(r'^[A-Za-z]:[/\\]').hasMatch(d);
    if (!absolute) return (out, 'not an absolute path: $raw');
    // One dir per entry: an embedded PATH separator would expand into extra
    // tokens at join time — and a stray trailing ':' yields an EMPTY token,
    // which POSIX shells resolve as CWD (the classic dot-in-PATH hazard).
    final body = RegExp(r'^[A-Za-z]:').hasMatch(d) ? d.substring(2) : d;
    if (body.contains(':') || body.contains(';')) return (out, 'entry contains a PATH separator: $raw');
    while (d.length > 1 && d.endsWith('/')) {
      d = d.substring(0, d.length - 1);
    }
    out.add(d);
  }
  return (out, null);
}

List<String> _dedupe(List<String> dirs) {
  final out = <String>[];
  for (final d in dirs) {
    if (!out.contains(d)) out.add(d);
  }
  return out;
}

List<String> _missing(List<String> dirs, bool Function(String) dirExists) => [
  for (final d in dirs)
    if (!dirExists(d)) d,
];

IpcResponse _ok(String id, Map<String, Object?> data) => IpcResponse.ok(id: id, data: data);

IpcResponse _err(String id, String message, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
);
