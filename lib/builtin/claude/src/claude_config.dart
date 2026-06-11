/// ClaudeConfig (T-151, D-76): builtin-owned, app-wide source of truth for
/// Claude Code's environment — skills, custom slash commands, settings, and
/// permission rules — read from the GLOBAL (`~/.claude`) and LOCAL (`.claude`)
/// scopes and layered local-over-global.
///
/// Built-in slash commands aren't on disk; they come from a one-shot
/// stream-json `init` probe of the `claude` CLI. The probe costs one minimal
/// turn, so its result is cached in clide's OWN global dir keyed on the
/// resolved claude version — it runs at most once per claude version per
/// machine, shared across every clide instance (the data is claude-locked,
/// not workspace-locked). We read Claude's config but never write into
/// `~/.claude` (same boundary as pql's data, D-3).
///
/// Consumers (composer typeahead, status pane) read from here; none re-scan
/// the filesystem or re-derive the command list.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/src/files/ignore.dart';
import 'package:clide/src/files/watcher.dart';
import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';

/// The live, app-wide instance once the Claude extension has activated
/// (builtin-owned singleton, D-76). Null before activation and in tests that
/// don't wire it. Consumers should accept an injected [ClaudeConfig] for
/// testability and fall back to this in production.
ClaudeConfig? activeClaudeConfig;

enum ConfigScope { global, local }

@immutable
class ClaudeSkill {
  const ClaudeSkill({required this.name, this.description, required this.scope, this.path});
  final String name;
  final String? description;
  final ConfigScope scope;

  /// Absolute path to the SKILL.md file, or null if the skill isn't file-backed
  /// (e.g. sourced from the probe cache only).
  final String? path;
}

@immutable
class ClaudeCommand {
  const ClaudeCommand({required this.name, required this.scope, this.path});
  final String name;
  final ConfigScope scope;

  /// Absolute path to the command's .md file, used for click-to-open (T-183).
  final String? path;
}

/// A Claude agent — a sub-agent definition from `<scope>/agents/*.md`.
@immutable
class ClaudeAgent {
  const ClaudeAgent({required this.name, required this.scope, this.path});
  final String name;
  final ConfigScope scope;

  /// Absolute path to the agent's .md file, used for click-to-open (T-183).
  final String? path;
}

/// One hook entry — a named group of commands from `settings['hooks']`.
@immutable
class ClaudeHook {
  const ClaudeHook({required this.event, required this.commands});
  final String event;
  final List<String> commands;
}

/// A named MCP server entry from `settings['mcpServers']`.
@immutable
class ClaudeMcpServer {
  const ClaudeMcpServer({required this.name});
  final String name;
}

@immutable
class ClaudePermissions {
  const ClaudePermissions({this.allow = const [], this.deny = const [], this.ask = const []});
  final List<String> allow;
  final List<String> deny;
  final List<String> ask;
  bool get isEmpty => allow.isEmpty && deny.isEmpty && ask.isEmpty;
}

/// The slice of session metadata the stream-json `init` event carries that
/// isn't derivable from disk: the full slash-command list (built-ins + custom
/// + plugin + MCP), the skill names, the default model and permission mode.
@immutable
class ClaudeProbe {
  const ClaudeProbe({required this.version, required this.slashCommands, required this.skills, this.model, this.permissionMode});

  final String version;
  final List<String> slashCommands;
  final List<String> skills;
  final String? model;
  final String? permissionMode;

  Map<String, Object?> toJson() => {
    'version': version,
    'slash_commands': slashCommands,
    'skills': skills,
    if (model != null) 'model': model,
    if (permissionMode != null) 'permission_mode': permissionMode,
  };

  /// Build from a stream-json `init` event object. Returns null if it doesn't
  /// look like an init event (no version field).
  static ClaudeProbe? fromInitEvent(Map<String, Object?> j, {required String version}) {
    if (j['slash_commands'] == null && j['claude_code_version'] == null) return null;
    return ClaudeProbe(
      version: version,
      slashCommands: _stringList(j['slash_commands']),
      skills: _stringList(j['skills']),
      model: j['model'] as String?,
      permissionMode: j['permissionMode'] as String?,
    );
  }

  static ClaudeProbe fromCache(Map<String, Object?> j) => ClaudeProbe(
    version: (j['version'] as String?) ?? '',
    slashCommands: _stringList(j['slash_commands']),
    skills: _stringList(j['skills']),
    model: j['model'] as String?,
    permissionMode: j['permission_mode'] as String?,
  );
}

List<String> _stringList(Object? v) => v is List ? v.whereType<String>().toList(growable: false) : const [];

/// Resolves the installed claude version string (e.g. "2.1.150 (Claude
/// Code)"), or null if `claude` can't be run.
typedef ClaudeVersionRunner = Future<String?> Function();

/// Runs the one-shot init probe and returns its raw stream-json stdout, or
/// null on failure.
typedef ClaudeInitProbe = Future<String?> Function();

/// Returns a change stream for [dir] (fires on any file event under it).
typedef ClaudeConfigWatch = Stream<void> Function(Directory dir);

/// Modest version-agnostic fallback used when the probe is unavailable, so
/// the typeahead still offers the common built-ins.
const List<String> kFallbackSlashCommands = [
  'add-dir',
  'agents',
  'clear',
  'compact',
  'config',
  'context',
  'cost',
  'doctor',
  'exit',
  'help',
  'init',
  'mcp',
  'memory',
  'model',
  'permissions',
  'resume',
  'review',
  'status',
  'usage',
];

class ClaudeConfig extends ChangeNotifier {
  ClaudeConfig({
    required Directory globalDir,
    required Directory cacheDir,
    Directory? projectDir,
    ClaudeVersionRunner? versionRunner,
    ClaudeInitProbe? initProbe,
    ClaudeConfigWatch? watch,
    Duration debounce = const Duration(milliseconds: 150),
  }) : _globalDir = globalDir,
       _cacheDir = cacheDir,
       _projectDir = projectDir,
       _versionRunner = versionRunner ?? _defaultVersionRunner,
       _initProbe = initProbe ?? _defaultInitProbe,
       _watch = watch,
       _debounceFor = debounce;

  final Directory _globalDir;
  final Directory _cacheDir;
  Directory? _projectDir;
  final ClaudeVersionRunner _versionRunner;
  final ClaudeInitProbe _initProbe;
  final ClaudeConfigWatch? _watch;
  final Duration _debounceFor;

  String? _version;
  ClaudeProbe? _probe;
  bool _probing = false;
  List<ClaudeSkill> _skills = const [];
  List<ClaudeCommand> _commands = const [];
  List<ClaudeAgent> _agents = const [];
  List<ClaudeHook> _hooks = const [];
  List<ClaudeMcpServer> _mcpServers = const [];
  Map<String, Object?> _settings = const {};
  ClaudePermissions _permissions = const ClaudePermissions();
  String? _error;

  final List<FileWatcher> _watchers = [];
  final List<StreamSubscription<void>> _subs = [];
  Timer? _debounce;

  // ---- Public, listenable views -------------------------------------------

  /// Resolved claude version (e.g. "2.1.150"), or null if claude is missing.
  String? get version => _version;

  /// True once a claude version resolved — the healthcheck signal.
  bool get ready => _version != null;

  /// Last error encountered resolving the environment, if any.
  String? get error => _error;

  ClaudeProbe? get probe => _probe;

  /// All slash commands for the typeahead — the probe's authoritative list
  /// (built-ins + custom + plugin + MCP), or the static fallback.
  List<String> get slashCommands => _probe?.slashCommands ?? kFallbackSlashCommands;

  List<ClaudeSkill> get skills => _skills;
  List<ClaudeCommand> get commands => _commands;

  /// Agent definitions scanned from `<scope>/agents/*.md` (T-183, D-76).
  List<ClaudeAgent> get agents => _agents;

  /// Hook entries parsed from `settings['hooks']` (T-183).
  List<ClaudeHook> get hooks => _hooks;

  /// MCP server names from `settings['mcpServers']` (T-183).
  List<ClaudeMcpServer> get mcpServers => _mcpServers;

  Map<String, Object?> get settings => Map.unmodifiable(_settings);
  ClaudePermissions get permissions => _permissions;

  // ---- Lifecycle ----------------------------------------------------------

  /// Full load — cheap and side-effect-light: resolve the version (`claude
  /// --version`, no model turn), read the version-keyed probe cache if it
  /// already exists, read the layered disk config, and start watching. Never
  /// runs the paid probe — call [ensureProbe] for that.
  Future<void> load() async {
    _error = null;
    _version = _parseVersion(await _guard(_versionRunner));
    await _readProbeCache();
    await _loadDiskConfig();
    _startWatchers();
    notifyListeners();
  }

  /// Run the one-turn init probe if we don't already have its data (cache
  /// miss / first use after a claude upgrade), then cache it. Idempotent and
  /// safe to call repeatedly; consumers (the slash typeahead) call it lazily
  /// on first need so app-init and tests never pay for a model turn.
  Future<void> ensureProbe() async {
    if (_probe != null || _probing) return;
    final v = _version;
    if (v == null) return;
    _probing = true;
    try {
      final probe = _parseInitProbe(await _guard(_initProbe), v);
      if (probe == null) return; // stay on the static fallback
      _probe = probe;
      await _writeProbeCache(probe);
      notifyListeners();
    } finally {
      _probing = false;
    }
  }

  /// Re-read the on-disk config (skills/commands/settings/permissions). The
  /// watcher calls this on change; callers can force it. Version + probe are
  /// not re-resolved (the binary doesn't change under us at runtime).
  Future<void> refresh() async {
    await _loadDiskConfig();
    notifyListeners();
  }

  /// Point the local scope at a different workspace (on project switch). Keeps
  /// the same instance — and its listeners — re-reading disk and re-watching
  /// for the new repo. The global scope and probe are unaffected.
  Future<void> setProjectDir(Directory? dir) async {
    _stopWatching();
    _projectDir = dir;
    await _loadDiskConfig();
    _startWatchers();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopWatching();
    super.dispose();
  }

  void _stopWatching() {
    _debounce?.cancel();
    _debounce = null;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    for (final w in _watchers) {
      unawaited(w.stop());
    }
    _watchers.clear();
  }

  // ---- Probe (version-keyed cache in clide's own dir) ---------------------

  File get _cacheFile => File('${_cacheDir.path}/init-$_version.json');

  /// Read the version-keyed cache if present. Read-only; no shell-out.
  Future<void> _readProbeCache() async {
    _probe = null;
    if (_version == null) return;
    final file = _cacheFile;
    if (!await file.exists()) return;
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final cached = ClaudeProbe.fromCache(j);
      if (cached.version == _version) _probe = cached;
    } catch (_) {
      // Corrupt cache — leave null; ensureProbe will re-probe on demand.
    }
  }

  Future<void> _writeProbeCache(ClaudeProbe probe) async {
    try {
      await _cacheDir.create(recursive: true);
      await _cacheFile.writeAsString(jsonEncode(probe.toJson()));
    } catch (_) {
      // A non-writable cache dir is non-fatal; we just re-probe next launch.
    }
  }

  ClaudeProbe? _parseInitProbe(String? raw, String version) {
    if (raw == null) return null;
    for (final line in const LineSplitter().convert(raw)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
      Map<String, Object?> j;
      try {
        j = jsonDecode(trimmed) as Map<String, Object?>;
      } catch (_) {
        continue;
      }
      if (j['type'] == 'system' && j['subtype'] == 'init') {
        return ClaudeProbe.fromInitEvent(j, version: version);
      }
    }
    return null;
  }

  // ---- Disk config (layered global -> local) ------------------------------

  Future<void> _loadDiskConfig() async {
    final skills = <ClaudeSkill>[];
    final commands = <ClaudeCommand>[];
    final agents = <ClaudeAgent>[];
    final settings = <String, Object?>{};
    final allow = <String>[], deny = <String>[], ask = <String>[];

    for (final (scope, dir) in _scopeDirs()) {
      skills.addAll(await _loadSkills(dir, scope));
      commands.addAll(await _loadCommands(dir, scope));
      agents.addAll(await _loadAgents(dir, scope));
      final s = await _loadSettings(dir);
      settings.addAll(s); // local overrides global per top-level key
      final p = _permissionsOf(s);
      allow.addAll(p.allow);
      deny.addAll(p.deny);
      ask.addAll(p.ask);
    }

    _skills = _dedupeByName(skills, (s) => s.name);
    _commands = _dedupeByName(commands, (c) => c.name);
    _agents = _dedupeByName(agents, (a) => a.name);
    _settings = settings;
    _permissions = ClaudePermissions(allow: _uniq(allow), deny: _uniq(deny), ask: _uniq(ask));
    _hooks = _parseHooks(settings['hooks']);
    _mcpServers = _parseMcpServers(settings['mcpServers']);
  }

  /// Global first so that local entries, added later, win on collisions.
  List<(ConfigScope, Directory)> _scopeDirs() {
    final pd = _projectDir;
    return [(ConfigScope.global, _globalDir), if (pd != null) (ConfigScope.local, Directory('${pd.path}/.claude'))];
  }

  Future<List<ClaudeSkill>> _loadSkills(Directory scopeDir, ConfigScope scope) async {
    final dir = Directory('${scopeDir.path}/skills');
    if (!await dir.exists()) return const [];
    final out = <ClaudeSkill>[];
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final manifest = File('${entry.path}/SKILL.md');
      if (!await manifest.exists()) continue;
      final fm = _parseFrontmatter(await manifest.readAsString());
      out.add(ClaudeSkill(name: fm.name ?? _basename(entry.path), description: fm.description, scope: scope, path: manifest.path));
    }
    return out;
  }

  Future<List<ClaudeCommand>> _loadCommands(Directory scopeDir, ConfigScope scope) async {
    final dir = Directory('${scopeDir.path}/commands');
    if (!await dir.exists()) return const [];
    final out = <ClaudeCommand>[];
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.md')) continue;
      final base = _basename(entry.path);
      out.add(ClaudeCommand(name: base.substring(0, base.length - 3), scope: scope, path: entry.path));
    }
    return out;
  }

  /// Scans `<scopeDir>/agents/*.md` for agent definitions (T-183, D-76).
  Future<List<ClaudeAgent>> _loadAgents(Directory scopeDir, ConfigScope scope) async {
    final dir = Directory('${scopeDir.path}/agents');
    if (!await dir.exists()) return const [];
    final out = <ClaudeAgent>[];
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.md')) continue;
      final base = _basename(entry.path);
      out.add(ClaudeAgent(name: base.substring(0, base.length - 3), scope: scope, path: entry.path));
    }
    return out;
  }

  Future<Map<String, Object?>> _loadSettings(Directory scopeDir) async {
    final file = File('${scopeDir.path}/settings.json');
    if (!await file.exists()) return const {};
    try {
      final j = jsonDecode(await file.readAsString());
      return j is Map ? j.map((k, v) => MapEntry('$k', v)) : const {};
    } catch (_) {
      return const {}; // a malformed settings file shouldn't sink the load
    }
  }

  ClaudePermissions _permissionsOf(Map<String, Object?> settings) {
    final p = settings['permissions'];
    if (p is! Map) return const ClaudePermissions();
    return ClaudePermissions(allow: _stringList(p['allow']), deny: _stringList(p['deny']), ask: _stringList(p['ask']));
  }

  // ---- Watching -----------------------------------------------------------

  void _startWatchers() {
    final source = _watch ?? _defaultWatch;
    for (final (_, dir) in _scopeDirs()) {
      if (!dir.existsSync()) continue;
      _subs.add(source(dir).listen((_) => _onChange()));
    }
  }

  Stream<void> _defaultWatch(Directory dir) {
    final w = FileWatcher(root: dir, ignore: IgnoreSet.parse(const []));
    _watchers.add(w);
    unawaited(w.start());
    return w.stream.map((_) {});
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(_debounceFor, () => unawaited(refresh()));
  }

  // ---- Helpers ------------------------------------------------------------

  Future<String?> _guard(Future<String?> Function() f) async {
    try {
      return await f();
    } catch (e) {
      _error = '$e';
      return null;
    }
  }

  static String? _parseVersion(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(raw);
    return m?.group(1);
  }

  static String _basename(String path) => path.split(Platform.pathSeparator).last;

  ({String? name, String? description}) _parseFrontmatter(String content) {
    final body = content.replaceFirst('\r\n', '\n');
    if (!body.startsWith('---')) return (name: null, description: null);
    final end = body.indexOf('\n---', 3);
    if (end < 0) return (name: null, description: null);
    try {
      final y = loadYaml(body.substring(3, end));
      if (y is Map) {
        return (name: y['name'] as String?, description: y['description'] as String?);
      }
    } catch (_) {
      // Unparseable frontmatter — caller falls back to the dir name.
    }
    return (name: null, description: null);
  }

  /// Parse `settings['hooks']` into typed [ClaudeHook] entries.
  ///
  /// Claude's hooks are a `Map<String, List<{hooks: [{command: String}]}>>`
  /// keyed on event name (e.g. `"PreToolUse"`). We flatten each event's
  /// command list into a single [ClaudeHook].
  static List<ClaudeHook> _parseHooks(Object? raw) {
    if (raw is! Map) return const [];
    final out = <ClaudeHook>[];
    for (final entry in raw.entries) {
      final event = '${entry.key}';
      final cmds = <String>[];
      // Each value is a list of hook groups; each group has a `hooks` list.
      if (entry.value is List) {
        for (final group in entry.value as List) {
          if (group is Map) {
            final hooksList = group['hooks'];
            if (hooksList is List) {
              for (final h in hooksList) {
                if (h is Map) {
                  final cmd = h['command'];
                  if (cmd is String && cmd.isNotEmpty) cmds.add(cmd);
                }
              }
            }
          }
        }
      }
      if (cmds.isNotEmpty) out.add(ClaudeHook(event: event, commands: cmds));
    }
    return out;
  }

  /// Parse `settings['mcpServers']` into [ClaudeMcpServer] entries.
  ///
  /// Claude's `mcpServers` is a `Map<String, {...config}>` keyed on server name.
  static List<ClaudeMcpServer> _parseMcpServers(Object? raw) {
    if (raw is! Map) return const [];
    return [for (final key in raw.keys) ClaudeMcpServer(name: '$key')];
  }

  static List<T> _dedupeByName<T>(List<T> all, String Function(T) nameOf) {
    final byName = <String, T>{};
    for (final item in all) {
      byName[nameOf(item)] = item; // later (local) scope wins
    }
    final out = byName.values.toList();
    out.sort((a, b) => nameOf(a).compareTo(nameOf(b)));
    return out;
  }

  static List<String> _uniq(List<String> xs) {
    final seen = <String>{};
    return [
      for (final x in xs)
        if (seen.add(x)) x,
    ];
  }
}

Future<String?> _defaultVersionRunner() async {
  try {
    final r = await Process.run('claude', ['--version']);
    return r.stdout as String?;
  } catch (_) {
    return null;
  }
}

Future<String?> _defaultInitProbe() async {
  try {
    final r = await Process.run('claude', ['-p', '.', '--no-session-persistence', '--output-format', 'stream-json', '--verbose']);
    return r.stdout as String?;
  } catch (_) {
    return null;
  }
}
