/// Claude meta sidebar (T-141, T-157, T-182): a left-panel tab split into a
/// sub-tab strip — Activity / Team / Config.
///
/// - **Activity** — Claude usage stats (from `~/.claude/stats-cache.json`,
///   polled) plus the primary session's live runtime (model / mode / context /
///   skills).
/// - **Team** — a roster of live members (from the TeamObserver's join/left
///   events + per-member status on the message bus). Auto-fronted when a team
///   spawns; mostly empty when solo.
/// - **Config** — the Claude environment settings table (model / output style /
///   permission mode / source) over [ClaudeConfig]. The expandable
///   skills/agents/commands/permissions/MCP browser is T-183.
///
/// Activity and Config render their key→value rows on the SAME table geometry
/// ([_metaTable]) so switching tabs doesn't visually jump.
///
/// The account/team token budget is intentionally absent: it isn't
/// programmatically exposed under subscription auth (see project memory /
/// GitHub anthropics/claude-code#44328).
library;

import 'dart:async';
import 'dart:io';

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_stats.dart';
import 'package:clide/builtin/claude/src/claude_status.dart' show formatTokenCount, permissionModeLabel, shortModelLabel;
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/team_panel_host.dart' show teamColor;
import 'package:clide/builtin/claude/src/transcript_publisher.dart' show ClaudeConversation;
import 'package:clide/builtin/claude/src/transcript_reader.dart' show SessionStatus;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

/// The shared label-column width + row pitch the Activity and Config tables both
/// use, so toggling between tabs keeps every value at the same x and y.
const double _labelColumnWidth = 110;
const double _rowPitch = 4;

enum SidebarTab { activity, team, config }

class ClaudeMetaSidebar extends StatefulWidget {
  const ClaudeMetaSidebar({
    super.key,
    this.statsLoader,
    this.pollInterval = const Duration(seconds: 20),
    this.config,
    this.orchestrator,
    this.initialTab = SidebarTab.activity,
  });

  /// Loads the activity stats; defaults to reading `~/.claude/stats-cache.json`.
  /// Injected in tests so they don't touch the real filesystem.
  final Future<ClaudeStats> Function()? statsLoader;

  /// How often to reload the stats. `Duration.zero` disables polling
  /// (initial load only) — used by tests to avoid a pending timer.
  final Duration pollInterval;

  /// The Claude environment source for the Config tab; defaults to the app-wide
  /// [activeClaudeConfig]. Injected in tests.
  final ClaudeConfig? config;

  /// The session set whose `primary` drives the Activity runtime row; defaults
  /// to [activeSessionOrchestrator]. Injected in tests.
  final ClaudeSessionOrchestrator? orchestrator;

  /// Starting tab (tests pin this; production defaults to Activity).
  final SidebarTab initialTab;

  @override
  State<ClaudeMetaSidebar> createState() => _ClaudeMetaSidebarState();
}

class _ClaudeMetaSidebarState extends State<ClaudeMetaSidebar> {
  ClaudeStats _stats = const ClaudeStats();
  final List<TeamMemberJoined> _members = [];
  final Map<String, SessionStatus> _memberStatus = {};
  StreamSubscription<TeamMemberJoined>? _joinSub;
  StreamSubscription<TeamMemberLeft>? _leftSub;
  StreamSubscription<Message>? _statusSub;
  StreamSubscription<SessionStatus>? _primarySub;
  Timer? _timer;
  late final Future<ClaudeStats> Function() _load;
  bool _subscribed = false;

  late SidebarTab _tab = widget.initialTab;
  ClaudeConfig? _config;
  ClaudeSessionOrchestrator? _orchestrator;
  SessionStatus? _primaryStatus;

  @override
  void initState() {
    super.initState();
    _load = widget.statsLoader ?? _fileLoader();
    _config = widget.config ?? activeClaudeConfig;
    _orchestrator = widget.orchestrator ?? activeSessionOrchestrator;
    _config?.addListener(_onConfigChange);
    _orchestrator?.addListener(_bindPrimary);
    _bindPrimary();
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
    final kernel = ClideKernel.of(context);
    _joinSub = kernel.events.on<TeamMemberJoined>().listen((m) {
      if (_members.any((x) => x.agentId == m.agentId)) return;
      final wasEmpty = _members.isEmpty;
      setState(() {
        _members.add(m);
        // A team coming to life fronts its tab (T-182).
        if (wasEmpty) _tab = SidebarTab.team;
      });
    });
    _leftSub = kernel.events.on<TeamMemberLeft>().listen((m) {
      setState(() {
        _members.removeWhere((x) => x.agentId == m.agentId);
        _memberStatus.remove(m.agentId);
      });
    });
    // Live per-member status forwarded by the observer (T-157).
    _statusSub = kernel.messages.subscribe(channel: ClaudeConversation.memberStatusChannel).listen((msg) {
      final agentId = msg.data['agentId'] as String?;
      if (agentId == null || !mounted) return;
      setState(() {
        _memberStatus[agentId] = SessionStatus(
          model: msg.data['model'] as String?,
          permissionMode: msg.data['permissionMode'] as String?,
          contextTokens: msg.data['contextTokens'] as int?,
        );
      });
    });
  }

  /// (Re)bind to the primary managed session's status as the orchestrator's set
  /// changes — the Activity runtime row reflects the live session.
  void _bindPrimary() {
    final session = _orchestrator?.byId('primary')?.session;
    _primarySub?.cancel();
    _primarySub = null;
    if (session == null) {
      if (_primaryStatus != null && mounted) setState(() => _primaryStatus = null);
      return;
    }
    final seed = session.status;
    if (mounted) setState(() => _primaryStatus = seed);
    _primarySub = session.statusStream.listen((s) {
      if (mounted) setState(() => _primaryStatus = s);
    });
  }

  void _onConfigChange() {
    if (mounted) setState(() {});
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
    _statusSub?.cancel();
    _primarySub?.cancel();
    _config?.removeListener(_onConfigChange);
    _orchestrator?.removeListener(_bindPrimary);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabStrip(current: _tab, memberCount: _members.length, onPick: (t) => setState(() => _tab = t)),
        Expanded(
          child: switch (_tab) {
            SidebarTab.activity => _activityBody(tokens),
            SidebarTab.team => _teamBody(tokens),
            SidebarTab.config => _configBody(tokens),
          },
        ),
      ],
    );
  }

  // --- Activity -------------------------------------------------------------

  Widget _activityBody(SurfaceTokens tokens) {
    final latest = _stats.latest;
    final sections = <_MetaSection>[
      if (latest != null)
        _MetaSection('TODAY', [
          _MetaRow('messages', '${latest.messageCount}'),
          _MetaRow('sessions', '${latest.sessionCount}'),
          _MetaRow('tool calls', '${latest.toolCallCount}'),
        ]),
      if (latest != null)
        _MetaSection('LIFETIME', [
          _MetaRow('messages', '${_stats.lifetimeMessages}'),
          _MetaRow('sessions', '${_stats.lifetimeSessions}'),
        ]),
      ..._runtimeSection(tokens),
    ];
    if (sections.isEmpty) {
      return _placeholder('No activity recorded yet.');
    }
    return _metaTable(tokens, sections);
  }

  List<_MetaSection> _runtimeSection(SurfaceTokens tokens) {
    final st = _primaryStatus;
    final skills = _config?.skills.length;
    final rows = <_MetaRow>[
      if (st?.model != null) _MetaRow('model', shortModelLabel(st!.model!), valueColor: tokens.globalFocus),
      if (st?.contextTokens != null) _MetaRow('context', '${formatTokenCount(st!.contextTokens!)} ctx'),
      if (st?.permissionMode != null) _MetaRow('mode', permissionModeLabel(st!.permissionMode!)),
      if (skills != null) _MetaRow('skills', '$skills'),
    ];
    return rows.isEmpty ? const [] : [_MetaSection('RUNTIME · primary', rows)];
  }

  // --- Team -----------------------------------------------------------------

  Widget _teamBody(SurfaceTokens tokens) {
    if (_members.isEmpty) {
      return _placeholder('No team active.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [for (final m in _members) _memberRow(tokens, m)],
    );
  }

  Widget _memberRow(SurfaceTokens tokens, TeamMemberJoined m) {
    final color = teamColor(m.color, fallback: tokens.globalForeground);
    final st = _memberStatus[m.agentId];
    final model = st?.model ?? m.model;
    final sub = [
      m.agentType,
      if (model != null) shortModelLabel(model),
      if (st?.permissionMode != null) permissionModeLabel(st!.permissionMode!),
      if (st?.contextTokens != null) '${formatTokenCount(st!.contextTokens!)} ctx',
    ].join('  ·  ');
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

  // --- Config ---------------------------------------------------------------

  Widget _configBody(SurfaceTokens tokens) {
    final config = _config;
    if (config == null) {
      return _placeholder('Claude environment not loaded.');
    }
    final settings = config.settings;
    final model = config.probe?.model ?? settings['model']?.toString() ?? '—';
    final outputStyle = settings['outputStyle']?.toString() ?? 'default';
    final mode = config.probe?.permissionMode ?? settings['permissionMode']?.toString() ?? 'default';
    return _metaTable(tokens, [
      _MetaSection('SETTINGS', [
        _MetaRow('model', model, valueColor: tokens.globalFocus),
        _MetaRow('output style', outputStyle),
        _MetaRow('permission mode', permissionModeLabel(mode)),
        _MetaRow('source', '~/.claude + .claude'),
      ]),
    ]);
  }

  // --- Shared rendering -----------------------------------------------------

  Widget _placeholder(String text) => Padding(
        padding: const EdgeInsets.all(12),
        child: ClideText(text, muted: true, fontSize: clideFontSmall),
      );

  Widget _metaTable(SurfaceTokens tokens, List<_MetaSection> sections) {
    final children = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      children.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 6),
        child: ClideText(s.header, fontSize: clideFontSmall, color: tokens.globalTextMuted),
      ));
      for (final r in s.rows) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: _rowPitch),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _labelColumnWidth,
                child: ClideText(r.label, muted: true, fontSize: clideFontSmall),
              ),
              Expanded(
                child: ClideText(
                  r.value,
                  fontSize: clideFontSmall,
                  color: r.valueColor ?? tokens.globalForeground,
                ),
              ),
            ],
          ),
        ));
      }
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: children,
    );
  }
}

class _MetaSection {
  const _MetaSection(this.header, this.rows);
  final String header;
  final List<_MetaRow> rows;
}

class _MetaRow {
  const _MetaRow(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
}

/// The Activity / Team / Config sub-tab strip — same interaction as the pql
/// panel's view tabs, with an underline under the active tab.
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.current, required this.memberCount, required this.onPick});
  final SidebarTab current;
  final int memberCount;
  final ValueChanged<SidebarTab> onPick;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: Row(
        children: [
          for (final t in SidebarTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => onPick(t),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: t == current ? tokens.globalFocus : const Color(0x00000000),
                          width: 2,
                        ),
                      ),
                    ),
                    child: ClideText(
                      _label(t),
                      fontSize: clideFontSmall,
                      color: t == current ? tokens.globalForeground : tokens.globalTextMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(SidebarTab t) => switch (t) {
        SidebarTab.activity => 'Activity',
        SidebarTab.team => memberCount == 0 ? 'Team' : 'Team · $memberCount',
        SidebarTab.config => 'Config',
      };
}
