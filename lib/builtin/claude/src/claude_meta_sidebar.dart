/// Claude meta sidebar (T-141): an always-pickable left-panel tab showing
/// Claude *activity* (from `~/.claude/stats-cache.json`, polled) and, when a
/// tmux agent team is running, a roster of its members (from the
/// TeamObserver's join/left events — not re-tailed here).
///
/// The account/team token budget is intentionally absent: it isn't
/// programmatically exposed under subscription auth (see project memory /
/// GitHub anthropics/claude-code#44328). Live per-member status (mode /
/// context) is a follow-up that needs the teammate status stream on the bus.
library;

import 'dart:async';
import 'dart:io';

import 'package:clide/builtin/claude/src/claude_stats.dart';
import 'package:clide/builtin/claude/src/claude_status.dart' show shortModelLabel;
import 'package:clide/builtin/claude/src/team_panel_host.dart' show teamColor;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

class ClaudeMetaSidebar extends StatefulWidget {
  const ClaudeMetaSidebar({super.key, this.statsLoader, this.pollInterval = const Duration(seconds: 20)});

  /// Loads the activity stats; defaults to reading `~/.claude/stats-cache.json`.
  /// Injected in tests so they don't touch the real filesystem.
  final Future<ClaudeStats> Function()? statsLoader;

  /// How often to reload the stats. `Duration.zero` disables polling
  /// (initial load only) — used by tests to avoid a pending timer.
  final Duration pollInterval;

  @override
  State<ClaudeMetaSidebar> createState() => _ClaudeMetaSidebarState();
}

class _ClaudeMetaSidebarState extends State<ClaudeMetaSidebar> {
  ClaudeStats _stats = const ClaudeStats();
  final List<TeamMemberJoined> _members = [];
  StreamSubscription<TeamMemberJoined>? _joinSub;
  StreamSubscription<TeamMemberLeft>? _leftSub;
  Timer? _timer;
  late final Future<ClaudeStats> Function() _load;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _load = widget.statsLoader ?? _fileLoader();
    unawaited(_refreshStats());
    if (widget.pollInterval > Duration.zero) {
      _timer = Timer.periodic(widget.pollInterval, (_) => unawaited(_refreshStats()));
    }
  }

  static Future<ClaudeStats> Function() _fileLoader() {
    final home = Platform.environment['HOME'];
    final file = home == null ? null : File('$home/.claude/stats-cache.json');
    return () async {
      if (file == null || !await file.exists()) return const ClaudeStats();
      try {
        return parseClaudeStats(await file.readAsString());
      } catch (_) {
        return const ClaudeStats();
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    _subscribed = true;
    final events = ClideKernel.of(context).events;
    _joinSub = events.on<TeamMemberJoined>().listen((m) {
      if (_members.any((x) => x.agentId == m.agentId)) return;
      setState(() => _members.add(m));
    });
    _leftSub = events.on<TeamMemberLeft>().listen((m) {
      setState(() => _members.removeWhere((x) => x.agentId == m.agentId));
    });
  }

  Future<void> _refreshStats() async {
    final stats = await _load();
    if (mounted) setState(() => _stats = stats);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _joinSub?.cancel();
    _leftSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader(tokens, 'Activity'),
        _activity(tokens),
        const SizedBox(height: 16),
        _sectionHeader(tokens, 'Team${_members.isEmpty ? '' : '  ·  ${_members.length}'}'),
        _roster(tokens),
      ],
    );
  }

  Widget _sectionHeader(SurfaceTokens tokens, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClideText(label, fontSize: clideFontSmall, color: tokens.globalTextMuted),
      );

  Widget _activity(SurfaceTokens tokens) {
    final latest = _stats.latest;
    if (latest == null) {
      return ClideText('No activity recorded yet.', muted: true, fontSize: clideFontSmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClideText(latest.date, fontSize: clideFontSmall, color: tokens.globalForeground),
        const SizedBox(height: 2),
        ClideText(
          '${latest.messageCount} msgs  ·  ${latest.sessionCount} sessions  ·  ${latest.toolCallCount} tools',
          muted: true,
          fontSize: clideFontSmall,
        ),
        const SizedBox(height: 6),
        ClideText(
          'Lifetime: ${_stats.lifetimeMessages} msgs over ${_stats.activeDays} days',
          muted: true,
          fontSize: clideFontSmall,
        ),
      ],
    );
  }

  Widget _roster(SurfaceTokens tokens) {
    if (_members.isEmpty) {
      return ClideText('No team active.', muted: true, fontSize: clideFontSmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final m in _members) _memberRow(tokens, m)],
    );
  }

  Widget _memberRow(SurfaceTokens tokens, TeamMemberJoined m) {
    final color = teamColor(m.color, fallback: tokens.globalForeground);
    final sub = [m.agentType, if (m.model != null) shortModelLabel(m.model!)].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClideText(m.name, fontSize: clideFontSmall, color: tokens.globalForeground, maxLines: 1, overflow: TextOverflow.ellipsis),
                ClideText(sub, muted: true, fontSize: clideFontSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
