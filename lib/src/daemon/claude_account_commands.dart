/// Registers the `claude account …` verbs — the CLI half of the per-repo
/// Claude account feature (T-480, epic T-476; D-6 CLI parity). UI tickets
/// (T-481/T-482) call these verbs only; nothing else writes the registry.
///
///   `clide claude account add <name> [--dir <path>]`
///   `clide claude account list`
///   `clide claude account login <name>`
///   `clide claude account set <name>`
///   `clide claude account unset`
///   `clide claude account remove <name> [--purge]`
///
/// The argv grammar splits the first two tokens as `subsystem.verb`, so the
/// command id is `claude.account` and the sub-verb arrives as the first
/// positional. Registry reads/writes go through an injected [AccountStore] port
/// and side-effects (respawn on set/unset, the login terminal pane, --purge rm)
/// are published on [accountActionChannel] for the Claude extension to perform —
/// keeping this handler Flutter-free so it runs under `dart test`.
library;

import '../ipc/command_schema.dart';
import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import 'dispatcher.dart';
import 'ui_command.dart' show MessagePublisher;

/// The MessageBus channel account actions publish on; the Claude extension
/// subscribes to the same literal to perform the side-effects.
const accountActionChannel = 'claude.account';

/// Flutter-free port over the (foundation-bound) AccountRegistry, injected so
/// this command runs under `dart test`. main.dart adapts the real registry +
/// bootstrap probe to it.
abstract class AccountStore {
  /// Registered accounts as `(name, dir)` records, in stored order.
  List<({String name, String dir})> get accounts;

  /// The account name bound to [cwd], or null.
  String? boundAccountName(String cwd);

  /// Every account name some workspace is bound to (for the in-use check).
  Set<String> boundAccountNames();

  /// Default config dir for a new account [name] (e.g. `~/.claude-<name>`).
  String defaultDirFor(String name);

  /// Unregistered `~/.claude-*` dirs the bootstrap probe found (adoption hints).
  List<String> detectedDirs();

  Future<void> add(String name, String dir);
  Future<void> remove(String name);
  Future<void> bind(String cwd, String name);
  Future<void> unbind(String cwd);
}

/// Register `claude.account`. [store] / [publisher] / [workspaceCwd] are
/// late-bound closures (captured post-boot in main.dart); each may be null in
/// a headless context, in which case the verb degrades to a clear error.
void registerClaudeAccountCommands(
  DaemonDispatcher d,
  AccountStore? Function() store, {
  MessagePublisher? Function()? publisher,
  String? Function()? workspaceCwd,
}) {
  d.register(
    'claude.account',
    (req) async => _dispatch(req, store(), publisher?.call(), workspaceCwd?.call()),
    schema: const CommandSchema(
      positional: ['action', 'name'],
      args: {
        'action': ArgSpec(required: true, rejectLeadingDash: true),
        'name': ArgSpec(rejectLeadingDash: true),
        'dir': ArgSpec(),
        'purge': ArgSpec(type: ArgType.boolean),
      },
    ),
  );
}

({String name, String dir})? _byName(AccountStore store, String name) {
  for (final a in store.accounts) {
    if (a.name == name) return a;
  }
  return null;
}

Future<IpcResponse> _dispatch(IpcRequest req, AccountStore? store, MessagePublisher? publish, String? cwd) async {
  if (store == null) return _err(req.id, 'account registry unavailable in this context');
  final action = (req.args['action'] as String?)?.trim();
  final name = (req.args['name'] as String?)?.trim();
  final dir = (req.args['dir'] as String?)?.trim();
  final purge = req.args['purge'] == true;

  switch (action) {
    case 'list':
      return _ok(req.id, {
        'accounts': [
          for (final a in store.accounts) {'name': a.name, 'dir': a.dir},
        ],
        'boundAccount': cwd == null ? null : store.boundAccountName(cwd),
        'detected': store.detectedDirs(),
      });

    case 'add':
      if (name == null || name.isEmpty) return _err(req.id, 'account add requires a <name>');
      final target = (dir == null || dir.isEmpty) ? store.defaultDirFor(name) : dir;
      final existing = _byName(store, name);
      if (existing != null) {
        // Idempotent: same dir is a no-op; a conflicting --dir is a userError.
        if (existing.dir == target) return _ok(req.id, {'name': name, 'dir': target, 'created': false});
        return _err(req.id, 'account "$name" already exists at ${existing.dir}', hint: 'remove it first, or omit --dir to keep it');
      }
      await store.add(name, target);
      return _ok(req.id, {'name': name, 'dir': target, 'created': true});

    case 'remove':
      if (name == null || name.isEmpty) return _err(req.id, 'account remove requires a <name>');
      final removing = _byName(store, name);
      if (removing == null) return _err(req.id, 'no such account: "$name"');
      if (store.boundAccountNames().contains(name)) {
        return _err(req.id, 'account "$name" is bound to a workspace', hint: 'clide claude account unset (in that workspace) first');
      }
      await store.remove(name);
      // The dir delete is IO the extension owns (this handler is Flutter-free).
      // Carry the dir in the payload — the account is gone from the registry now.
      if (purge) publish?.call('cli', accountActionChannel, {'action': 'purge', 'name': name, 'dir': removing.dir});
      return _ok(req.id, {'removed': name, 'purge': purge});

    case 'set':
      if (name == null || name.isEmpty) return _err(req.id, 'account set requires a <name>');
      if (cwd == null) return _err(req.id, 'no workspace to bind');
      if (_byName(store, name) == null) return _err(req.id, 'no such account: "$name"', hint: 'clide claude account add $name');
      await store.bind(cwd, name);
      // The extension respawns the active pane(s) on the new account.
      publish?.call('cli', accountActionChannel, {'action': 'set', 'name': name, 'cwd': cwd});
      return _ok(req.id, {'bound': name, 'cwd': cwd});

    case 'unset':
      if (cwd == null) return _err(req.id, 'no workspace to unbind');
      final prev = store.boundAccountName(cwd);
      await store.unbind(cwd);
      publish?.call('cli', accountActionChannel, {'action': 'unset', 'cwd': cwd, 'previous': prev});
      return _ok(req.id, {'unbound': prev, 'cwd': cwd});

    case 'login':
      if (name == null || name.isEmpty) return _err(req.id, 'account login requires a <name>');
      final acct = _byName(store, name);
      if (acct == null) return _err(req.id, 'no such account: "$name"', hint: 'clide claude account add $name');
      // The extension spawns `CLAUDE_CONFIG_DIR=<dir> claude login` in a pane.
      publish?.call('cli', accountActionChannel, {'action': 'login', 'name': name, 'dir': acct.dir});
      return _ok(req.id, {'login': name, 'dir': acct.dir});

    default:
      return _err(
        req.id,
        'unknown account action: ${action == null || action.isEmpty ? '(none)' : action}',
        hint: 'use: add | list | login | set | unset | remove',
      );
  }
}

IpcResponse _ok(String id, Map<String, Object?> data) => IpcResponse.ok(id: id, data: data);

IpcResponse _err(String id, String message, {String? hint}) => IpcResponse.err(
  id: id,
  error: IpcError(code: IpcExitCode.userError, kind: IpcErrorKind.userError, message: message, hint: hint),
);
