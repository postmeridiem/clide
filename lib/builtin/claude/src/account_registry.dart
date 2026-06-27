/// Per-repo Claude account registry (T-483, epic T-476) — the user-scope
/// persistence + typed reader/writer every other child of the epic consumes.
///
/// Two durable concerns, both in the app (user) settings layer so they are
/// PER-USER, never committed to a repo:
///
/// - **Account registry** `app.claude.accounts` — a list of `{name, dir}`
///   pairs: the Claude accounts this user set up. `dir` is the
///   `CLAUDE_CONFIG_DIR` Claude Code reads from for that account.
/// - **Workspace binding** `app.claude.account.<workspace-hash>` → account
///   name. The hash is the SAME FNV-1a 64-bit hex D-70 uses for the socket
///   path ([fnv1a64Hex]/[canonicalWorkspaceKey]), so a workspace's account and
///   its socket agree. Unset = use Claude's default (no injection).
///
/// Flutter-free (foundation only, via SettingsStore); no process spawning, no
/// UI, no CLI — those are downstream tickets (T-484/T-480/T-481/T-482).
library;

import 'dart:io';

import 'package:clide/kernel/src/settings.dart';
import 'package:clide/src/ipc/paths.dart' show canonicalWorkspaceKey, fnv1a64Hex;

/// One configured Claude account: a user-chosen [name] (`personal`, `work`,
/// `client-acme`) and the [dir] Claude Code reads as `CLAUDE_CONFIG_DIR`.
class Account {
  const Account({required this.name, required this.dir});

  final String name;
  final String dir;

  Map<String, String> toJson() => {'name': name, 'dir': dir};

  @override
  bool operator ==(Object other) => other is Account && other.name == name && other.dir == dir;

  @override
  int get hashCode => Object.hash(name, dir);

  @override
  String toString() => 'Account($name → $dir)';
}

/// A `~/.claude-*` directory the bootstrap probe found that looks like a Claude
/// config dir — an adoption candidate. [name] is the suggested account name
/// (the suffix after `.claude-`); registering it is welcome-view UX (T-481).
class DetectedAccount {
  const DetectedAccount({required this.name, required this.dir});

  final String name;
  final String dir;

  @override
  bool operator ==(Object other) => other is DetectedAccount && other.name == name && other.dir == dir;

  @override
  int get hashCode => Object.hash(name, dir);
}

class AccountRegistry {
  AccountRegistry(this._store);

  final SettingsStore _store;

  /// Key holding the `{name, dir}` account list (app/user scope).
  static const accountsKey = 'app.claude.accounts';

  /// Per-workspace binding key: account name keyed by workspace hash.
  static String bindingKey(String cwd) => 'app.claude.account.${workspaceHash(cwd)}';

  /// FNV-1a 64-bit hex of the canonicalised workspace root — the SAME hash D-70
  /// derives for the socket path, so a workspace's binding and its socket
  /// agree. Trailing separators are stripped so `/repo` and `/repo/` map alike.
  static String workspaceHash(String cwd) => fnv1a64Hex(canonicalWorkspaceKey(_stripTrailingSep(cwd)));

  static String _stripTrailingSep(String p) {
    var s = p;
    while (s.length > 1 && (s.endsWith('/') || s.endsWith(r'\'))) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// The configured accounts, in stored order. Tolerant of a malformed or
  /// partially-written entry (skips anything missing a string name + dir).
  List<Account> get accounts {
    final raw = _store.get<List>(accountsKey);
    if (raw == null) return const [];
    final out = <Account>[];
    for (final e in raw) {
      if (e is Map && e['name'] is String && e['dir'] is String) {
        out.add(Account(name: e['name'] as String, dir: e['dir'] as String));
      }
    }
    return out;
  }

  Account? accountByName(String name) {
    for (final a in accounts) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// The account bound to [cwd], or null when unbound (or bound to a name that
  /// no longer exists — treated as unbound, so a removed account degrades to
  /// Claude's default rather than erroring).
  Account? accountForWorkspace(String cwd) {
    final name = _store.get<String>(bindingKey(cwd));
    return name == null ? null : accountByName(name);
  }

  /// The raw account NAME bound to [cwd] — independent of whether that account
  /// still exists in the registry — or null when unbound. (`accountForWorkspace`
  /// resolves to the Account and is null for a dangling binding; this is the
  /// stored name, for list/unset reporting.)
  String? boundName(String cwd) => _store.get<String>(bindingKey(cwd));

  /// Every account name some workspace is bound to — for "is this account in
  /// use" checks before removal (T-480). Scans the `app.claude.account.<hash>`
  /// binding keys (NOT the `app.claude.accounts` list, a different key).
  Set<String> boundAccountNames() {
    const prefix = 'app.claude.account.';
    final out = <String>{};
    for (final key in _store.keysAt(SettingsScope.app)) {
      if (!key.startsWith(prefix)) continue;
      final v = _store.get<String>(key);
      if (v != null) out.add(v);
    }
    return out;
  }

  /// Add (or replace, by name) an account. New default dir is the caller's
  /// concern (T-480); the registry stores whatever [dir] it's given.
  Future<void> registerAccount(String name, String dir) async {
    await _writeAccounts([...accounts.where((a) => a.name != name), Account(name: name, dir: dir)]);
  }

  Future<void> removeAccount(String name) async {
    await _writeAccounts(accounts.where((a) => a.name != name).toList());
  }

  Future<void> bindWorkspace(String cwd, String name) async {
    await _store.setAt(SettingsScope.app, bindingKey(cwd), name);
  }

  Future<void> unbindWorkspace(String cwd) async {
    await _store.removeAt(SettingsScope.app, bindingKey(cwd));
  }

  Future<void> _writeAccounts(List<Account> list) async {
    await _store.setAt(SettingsScope.app, accountsKey, [for (final a in list) a.toJson()]);
  }
}

/// Best-effort, read-only check of whether an account config dir holds live
/// credentials (T-482) — for the "signed in / not signed in" indicator. True
/// when the dir has a `.credentials.json` (Linux/Windows) or its `.claude.json`
/// carries an `oauthAccount` marker. Never mutates; under-reports on macOS,
/// where Claude Code keeps credentials in the system keychain rather than a file.
bool accountIsSignedIn(String dir) {
  if (File('$dir/.credentials.json').existsSync()) return true;
  final cfg = File('$dir/.claude.json');
  if (!cfg.existsSync()) return false;
  try {
    return cfg.readAsStringSync().contains('"oauthAccount"');
  } catch (_) {
    return false;
  }
}

/// Whether [dir] is safe to `rm -rf` as a purged account config dir
/// (`remove --purge`, T-480): it must be a `~/.claude-*` directory that is a
/// DIRECT child of [home]. Anything else — an absolute path elsewhere, a nested
/// path, the real `~/.claude` — is rejected even though the path came from our
/// own registry. A wrong recursive delete is unrecoverable, so the predicate
/// is deliberately strict.
bool isPurgeableAccountDir(String dir, String home) {
  if (home.isEmpty) return false;
  final base = dir.split('/').last;
  return dir == '$home/$base' && base.startsWith('.claude-');
}

/// Bootstrap probe (T-483): existing `~/.claude-*` directories that look like a
/// Claude config dir (have a `.claude.json` file or a `sessions/` dir), as
/// adoption candidates. Pure read — mutates nothing; the welcome view (T-481)
/// decides whether to register them. Sorted by suggested name.
List<DetectedAccount> probeExistingAccountDirs(String home) {
  final out = <DetectedAccount>[];
  final dir = Directory(home);
  if (!dir.existsSync()) return out;
  for (final entry in dir.listSync(followLinks: false)) {
    if (entry is! Directory) continue;
    final base = entry.path.split(Platform.pathSeparator).last;
    if (!base.startsWith('.claude-')) continue;
    final looksLikeConfig = File('${entry.path}/.claude.json').existsSync() || Directory('${entry.path}/sessions').existsSync();
    if (!looksLikeConfig) continue;
    out.add(DetectedAccount(name: base.substring('.claude-'.length), dir: entry.path));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}
