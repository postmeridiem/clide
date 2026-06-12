/// Claude meta sidebar (T-141, T-157, T-171, T-182): a left-panel tab split
/// into a sub-tab strip — Activity / Team / Config.
///
/// - **Activity** — Claude usage stats (from `~/.claude/stats-cache.json`,
///   polled) plus the primary session's live runtime (model / mode / context /
///   skills).
/// - **Team** — the roster cockpit (T-171): live per-member status (T-157) plus
///   per-row controls (show/hide, mute, close, inject-message) and a TASKS
///   section that renders [TeamBroker.tasks] live, with per-task owner and a
///   reassign control.  Auto-fronted when a team spawns (T-182); mostly empty
///   when solo.
/// - **Config** — the Claude environment settings table (model / output style /
///   permission mode / source) over [ClaudeConfig]. The expandable
///   skills/agents/commands/permissions/MCP browser is T-183.
///
/// This root file owns the LIFECYCLE — stats polling, team membership
/// streams, primary-session binding, broker subscription, inject state,
/// accordion state — and switches between the stateless tab views under
/// `meta_sidebar/` (T-395 split). Activity and Config render on the same
/// table geometry (`buildMetaTable`) so switching tabs doesn't visually jump.
///
/// The account/team token budget is intentionally absent: it isn't
/// programmatically exposed under subscription auth (see project memory /
/// GitHub anthropics/claude-code#44328).
library;

import 'dart:async';
import 'dart:io';

import 'package:clide/builtin/claude/src/claude_config.dart';
import 'package:clide/builtin/claude/src/claude_stats.dart';
import 'package:clide/builtin/claude/src/meta_sidebar/activity_tab.dart';
import 'package:clide/builtin/claude/src/meta_sidebar/config_tab.dart';
import 'package:clide/builtin/claude/src/meta_sidebar/models.dart';
import 'package:clide/builtin/claude/src/meta_sidebar/tab_strip.dart';
import 'package:clide/builtin/claude/src/meta_sidebar/team_tab.dart';
import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/team_broker.dart' show TeamBroker, TeamTask;
import 'package:clide/builtin/claude/src/transcript_publisher.dart' show ClaudeConversation;
import 'package:clide/builtin/claude/src/transcript_reader.dart' show SessionStatus;
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';

export 'package:clide/builtin/claude/src/meta_sidebar/models.dart' show SidebarTab;

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
  StreamSubscription<Message>? _tabSub;
  StreamSubscription<SessionStatus>? _primarySub;
  StreamSubscription<void>? _brokerChangeSub;
  Timer? _timer;
  late final Future<ClaudeStats> Function() _load;
  bool _subscribed = false;

  late SidebarTab _tab = widget.initialTab;
  ClaudeConfig? _config;
  ClaudeSessionOrchestrator? _orchestrator;
  SessionStatus? _primaryStatus;

  // T-183: Config accordion expansion state — each section starts collapsed.
  // Owned here (not in the tab view) so it survives tab switches.
  final Set<ConfigSection> _expanded = {};

  /// agentId currently in "inject message" mode (shows the text field).
  String? _injectingAgentId;
  final _injectCtl = TextEditingController();
  List<TeamTask> _tasks = const [];

  @override
  void initState() {
    super.initState();
    _load = widget.statsLoader ?? _fileLoader();
    _config = widget.config ?? activeClaudeConfig;
    _orchestrator = widget.orchestrator ?? activeSessionOrchestrator;
    _config?.addListener(_onConfigChange);
    _orchestrator?.addListener(_onOrchestratorChange);
    _bindPrimary();
    _subscribeBroker();
    unawaited(_refreshStats());
    if (widget.pollInterval > Duration.zero) {
      _timer = Timer.periodic(widget.pollInterval, (_) => unawaited(_refreshStats()));
    }
  }

  void _subscribeBroker() {
    _brokerChangeSub?.cancel();
    final broker = _orchestrator?.broker;
    if (broker == null) return;
    _tasks = List.of(broker.tasks);
    _brokerChangeSub = broker.changes.listen((_) {
      if (mounted) setState(() => _tasks = List.of(broker.tasks));
    });
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
    // Slash-command navigation (T-413): /status, /config, /mcp, … publish a
    // meta.tab message; switch the sub-tab to match.
    _tabSub = kernel.messages.subscribe(publisher: 'builtin.claude', channel: 'meta.tab').listen((msg) {
      final name = msg.data['tab'] as String?;
      final tab = SidebarTab.values.where((t) => t.name == name).firstOrNull;
      if (tab != null && mounted) setState(() => _tab = tab);
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
  /// The orchestrator notifies on any session change (spawn/close, and the
  /// visible/muted toggles the cockpit controls drive). Re-bind the primary
  /// status stream and rebuild so the roster rows reflect the new state.
  void _onOrchestratorChange() {
    _bindPrimary();
    if (mounted) setState(() {});
  }

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

  /// Fork the team session identified by [memberName] (T-172, roster button).
  ///
  /// Resolves the managed session, then spawns a new fork session via the
  /// orchestrator. The fork appears in the roster (it's a team session, visible
  /// by default) and is independent from the source — the original is unaffected.
  void _forkMember(String memberName) {
    final orch = _orchestrator;
    if (orch == null) return;
    final managed = orch.byMemberName(memberName);
    if (managed == null) return;
    final forkId = 'fork:$memberName-${DateTime.now().millisecondsSinceEpoch}';
    unawaited(
      orch.spawn(
        SpawnSpec(
          id: forkId,
          role: 'fork of $memberName',
          // sessionId is a placeholder; real claude session id arrives via init.
          sessionId: forkId,
          cwd: managed.cwd,
          forkSourceSessionId: managed.sessionId,
        ),
      ),
    );
  }

  Future<void> _refreshStats() async {
    final stats = await _load();
    if (mounted) setState(() => _stats = stats);
  }

  /// Open the full team chat pane in the workspace (T-180).
  void _openChatPane() {
    ClideKernel.of(context).panels.activateTab(Slots.workspace, 'claude.team-chat');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _joinSub?.cancel();
    _leftSub?.cancel();
    _statusSub?.cancel();
    _tabSub?.cancel();
    _primarySub?.cancel();
    _brokerChangeSub?.cancel();
    _injectCtl.dispose();
    _config?.removeListener(_onConfigChange);
    _orchestrator?.removeListener(_onOrchestratorChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SidebarTabStrip(current: _tab, memberCount: _members.length, onPick: (t) => setState(() => _tab = t)),
        Expanded(
          child: switch (_tab) {
            SidebarTab.activity => ActivityTabView(stats: _stats, primaryStatus: _primaryStatus, config: _config),
            SidebarTab.team => TeamTabView(
              members: _members,
              memberStatus: _memberStatus,
              orchestrator: _orchestrator,
              tasks: _tasks,
              injectingAgentId: _injectingAgentId,
              injectController: _injectCtl,
              onToggleInject: (name) => setState(() {
                if (_injectingAgentId == name) {
                  _injectingAgentId = null;
                  _injectCtl.clear();
                } else {
                  _injectingAgentId = name;
                  _injectCtl.clear();
                }
              }),
              onInjectSubmit: (name, text) {
                final managed = _orchestrator?.byMemberName(name);
                if (managed != null) {
                  _orchestrator!.injectMessage(managed.id, text);
                }
                setState(() {
                  _injectingAgentId = null;
                  _injectCtl.clear();
                });
              },
              onClose: (name) {
                final managed = _orchestrator?.byMemberName(name);
                if (managed != null) _orchestrator!.close(managed.id);
              },
              onSetPermissionMode: (name, mode) {
                final managed = _orchestrator?.byMemberName(name);
                managed?.session.setPermissionMode(mode);
              },
              onFork: _forkMember,
              onOpenChatPane: _openChatPane,
            ),
            SidebarTab.config => ConfigTabView(
              config: _config,
              expanded: _expanded,
              onToggleSection: (section) => setState(() {
                if (_expanded.contains(section)) {
                  _expanded.remove(section);
                } else {
                  _expanded.add(section);
                }
              }),
            ),
          },
        ),
      ],
    );
  }
}
