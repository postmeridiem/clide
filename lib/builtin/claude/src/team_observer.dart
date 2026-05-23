/// tmux agent-team observer (epic T-132, T-139, D-75).
///
/// THE single drift-containment point for Claude Code's experimental tmux
/// team mode. Everything that reads CC's undocumented team artifacts lives
/// here so a CC change only breaks one file.
///
/// # What's reliable vs. fragile
/// - **Reliable — lifecycle + identity (config-driven).** A team writes
///   `~/.claude/teams/<team>/config.json` listing each member with its
///   `tmuxPaneId` (`%N`, empty for the lead), `name`, `agentType`, `model`,
///   `color`, `cwd`, `joinedAt`. Polling `tmux -L clide list-panes -a` and
///   correlating live pane ids with `tmuxPaneId` gives a dependable
///   joined/left signal and full identity — no transcript needed.
/// - **Fragile — per-teammate transcript join.** A teammate's transcript is
///   a subagent file `<munged-cwd>/<leadSessionId>/subagents/agent-<hex>.jsonl`
///   whose only ids are a random hex (the filename) and a `slug`; it carries
///   no `name`/`agentType`. The config's `agentId` is `<name>@<team>` — a
///   different namespace — so there is no shared key. We join via a sibling
///   `agent-<hex>.meta.json` (`{agentType}`) when present, else fall back to
///   zipping members-by-`joinedAt` against files-by-mtime. This is the part
///   most likely to drift; it needs validation against a live team run.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/transcript_publisher.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/events/bus.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:clide/kernel/src/events/types.dart';

/// One member of a team config.
class TeamMember {
  const TeamMember({
    required this.agentId,
    required this.name,
    required this.agentType,
    required this.tmuxPaneId,
    this.model,
    this.color,
    this.cwd,
    this.joinedAt,
  });

  /// Config agent id, `<name>@<team>`.
  final String agentId;
  final String name;
  final String agentType;

  /// tmux pane id (`%N`); empty for the lead.
  final String tmuxPaneId;
  final String? model;
  final String? color;
  final String? cwd;
  final int? joinedAt;

  bool get isLead => tmuxPaneId.isEmpty || agentType == 'team-lead';
}

/// Parsed `~/.claude/teams/<team>/config.json`.
class TeamConfig {
  const TeamConfig({
    required this.team,
    required this.leadSessionId,
    required this.members,
    required this.createdAt,
  });

  final String team;
  final String leadSessionId;
  final List<TeamMember> members;
  final int createdAt;

  /// Non-lead members (the panes we surface).
  List<TeamMember> get teammates => members.where((m) => !m.isLead).toList();

  /// Parse a config; returns null on malformed JSON.
  static TeamConfig? parse(String teamDirName, String jsonStr) {
    Map<String, dynamic> d;
    try {
      d = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final members = <TeamMember>[];
    for (final m in (d['members'] as List? ?? const [])) {
      if (m is! Map) continue;
      members.add(TeamMember(
        agentId: m['agentId'] as String? ?? '',
        name: m['name'] as String? ?? '',
        agentType: m['agentType'] as String? ?? '',
        tmuxPaneId: m['tmuxPaneId'] as String? ?? '',
        model: m['model'] as String?,
        color: m['color'] as String?,
        cwd: m['cwd'] as String?,
        joinedAt: (m['joinedAt'] as num?)?.toInt(),
      ));
    }
    return TeamConfig(
      team: (d['name'] as String?) ?? teamDirName,
      leadSessionId: d['leadSessionId'] as String? ?? '',
      members: members,
      createdAt: (d['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Discover the active team config for [workspacePath]: the team (under
/// [teamsBase]) any of whose members runs in [workspacePath], newest by
/// `createdAt` when several match. Null if none.
Future<TeamConfig?> discoverTeam(String workspacePath, {required String teamsBase}) async {
  final dir = Directory(teamsBase);
  if (!await dir.exists()) return null;
  TeamConfig? best;
  await for (final entity in dir.list()) {
    if (entity is! Directory) continue;
    final cfgFile = File('${entity.path}/config.json');
    if (!await cfgFile.exists()) continue;
    final cfg = TeamConfig.parse(entity.path.split('/').last, await cfgFile.readAsString());
    if (cfg == null) continue;
    if (!cfg.members.any((m) => m.cwd == workspacePath)) continue;
    if (best == null || cfg.createdAt > best.createdAt) best = cfg;
  }
  return best;
}

/// Returns the set of live tmux pane ids on the `clide` socket. Injectable
/// so tests don't shell out.
typedef PaneLister = Future<Set<String>> Function();

class _LiveMember {
  _LiveMember(this.member, this.team, this.publisher, this.statusSub);
  final TeamMember member;
  final String team;
  final TranscriptPublisher? publisher;

  /// Forwards the member's status onto [ClaudeConversation.memberStatusChannel]
  /// (T-157); cancelled when the member leaves.
  final StreamSubscription<SessionStatus>? statusSub;
}

/// Watches a workspace's tmux team and emits [TeamMemberJoined] /
/// [TeamMemberLeft] as panes appear/disappear, publishing each teammate's
/// transcript onto the [MessageBus] under its per-agent channel.
class TeamObserver {
  TeamObserver({
    required this.workspacePath,
    required DaemonBus events,
    required MessageBus messages,
    String? teamsBase,
    String? projectsBase,
    PaneLister? paneLister,
    Duration pollInterval = const Duration(seconds: 2),
  })  : _events = events,
        _messages = messages,
        _teamsBase = teamsBase ?? _defaultTeamsBase(),
        _projectsBase = projectsBase ?? _defaultProjectsBase(),
        _paneLister = paneLister ?? _tmuxPaneLister,
        _pollInterval = pollInterval;

  final String workspacePath;
  final DaemonBus _events;
  final MessageBus _messages;
  final String _teamsBase;
  final String _projectsBase;
  final PaneLister _paneLister;
  final Duration _pollInterval;

  Timer? _timer;
  bool _disposed = false;
  final Map<String, _LiveMember> _live = {};

  static String _defaultTeamsBase() {
    final home = Platform.environment['HOME'] ?? '';
    return home.isNotEmpty ? '$home/.claude/teams' : '.claude/teams';
  }

  static String _defaultProjectsBase() {
    final home = Platform.environment['HOME'] ?? '';
    return home.isNotEmpty ? '$home/.claude/projects' : '.claude/projects';
  }

  static Future<Set<String>> _tmuxPaneLister() async {
    try {
      final r = await Process.run('tmux', ['-L', 'clide', 'list-panes', '-a', '-F', '#{pane_id}']);
      if (r.exitCode != 0) return const {};
      return (r.stdout as String).split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Begin polling.
  void start() => _scheduleNext();

  void _scheduleNext() {
    _timer = Timer(_pollInterval, () async {
      if (_disposed) return;
      await tick();
      if (!_disposed) _scheduleNext();
    });
  }

  /// One poll cycle (public for tests). Diffs the config roster against the
  /// live panes and emits joined/left.
  Future<void> tick() async {
    final config = await discoverTeam(workspacePath, teamsBase: _teamsBase);
    if (config == null) {
      await _killAll();
      return;
    }
    final livePanes = await _paneLister();
    final configIds = <String>{};

    for (final m in config.teammates) {
      configIds.add(m.agentId);
      final paneLive = livePanes.contains(m.tmuxPaneId);
      final tracked = _live.containsKey(m.agentId);
      if (paneLive && !tracked) {
        await _joined(config, m);
      } else if (!paneLive && tracked) {
        await _left(m.agentId);
      }
    }

    // A member dropped from the config (team reshaped) also counts as left.
    for (final id in _live.keys.toList()) {
      if (!configIds.contains(id)) await _left(id);
    }
  }

  Future<void> _joined(TeamConfig config, TeamMember m) async {
    final path = await _resolveTranscript(config, m);
    TranscriptPublisher? pub;
    StreamSubscription<SessionStatus>? statusSub;
    if (path != null) {
      pub = TranscriptPublisher(
        messages: _messages,
        reader: TranscriptReader(m.cwd ?? workspacePath, file: path, projectsBase: _projectsBase),
        channel: ClaudeConversation.teammateChannel(m.agentId),
      );
      // Forward this member's status onto the shared status channel so the
      // team sidebar can show its mode + context without re-tailing (T-157).
      statusSub = pub.statusStream.listen((s) => _messages.publish(
            ClaudeConversation.publisher,
            ClaudeConversation.memberStatusChannel,
            ClaudeConversation.memberStatusData(m.agentId, s),
          ));
    }
    _live[m.agentId] = _LiveMember(m, config.team, pub, statusSub);
    _events.emit(TeamMemberJoined(
      team: config.team,
      agentId: m.agentId,
      name: m.name,
      agentType: m.agentType,
      paneId: m.tmuxPaneId,
      model: m.model,
      color: m.color,
      cwd: m.cwd,
      transcriptPath: path,
    ));
  }

  Future<void> _left(String agentId) async {
    final live = _live.remove(agentId);
    if (live == null) return;
    await live.statusSub?.cancel();
    await live.publisher?.dispose();
    _events.emit(TeamMemberLeft(team: live.team, agentId: agentId, paneId: live.member.tmuxPaneId));
  }

  Future<void> _killAll() async {
    for (final id in _live.keys.toList()) {
      await _left(id);
    }
  }

  /// Best-effort join of [member] to its subagent transcript file. See the
  /// library doc — this is the drift-prone part. Returns null if no
  /// transcript can be resolved.
  Future<String?> _resolveTranscript(TeamConfig config, TeamMember member) async {
    final cwd = member.cwd;
    if (cwd == null || config.leadSessionId.isEmpty) return null;
    final munged = cwd.replaceAll('/', '-');
    final subDir = Directory('$_projectsBase/$munged/${config.leadSessionId}/subagents');
    if (!await subDir.exists()) return null;

    final files = <File>[];
    await for (final e in subDir.list()) {
      if (e is File && e.path.endsWith('.jsonl') && !e.path.contains('compact')) {
        files.add(e);
      }
    }
    if (files.isEmpty) return null;

    // Clean join: a sibling `.meta.json` whose agentType matches.
    for (final f in files) {
      final metaPath = '${f.path.substring(0, f.path.length - '.jsonl'.length)}.meta.json';
      final meta = File(metaPath);
      if (!await meta.exists()) continue;
      try {
        final m = jsonDecode(await meta.readAsString());
        if (m is Map && m['agentType'] == member.agentType) return f.path;
      } catch (_) {
        // ignore malformed meta
      }
    }

    // Fallback: zip teammates-by-joinedAt against files-by-mtime.
    final teammates = [...config.teammates]..sort((a, b) => (a.joinedAt ?? 0).compareTo(b.joinedAt ?? 0));
    final idx = teammates.indexWhere((m) => m.agentId == member.agentId);
    if (idx < 0) return null;
    final stats = <(File, DateTime)>[];
    for (final f in files) {
      stats.add((f, (await f.stat()).modified));
    }
    stats.sort((a, b) => a.$2.compareTo(b.$2));
    return idx < stats.length ? stats[idx].$1.path : null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _killAll();
  }
}
