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
/// The account budget surfaces from a forwarded `/usage` (T-415): the Activity
/// tab renders it next to its refresh control. It is NOT duplicated on the Team
/// tab — usage is per-account (one `~/.claude` login), so it can't be split per
/// member; one place to see it is enough (T-158).
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
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/team_broker.dart' show TeamBroker, TeamTask;
import 'package:clide/builtin/claude/src/claude_status.dart' show ClaudeUsage, parseUsageText;
import 'package:clide/builtin/claude/src/transcript_publisher.dart' show ClaudeConversation;
import 'package:clide/builtin/claude/src/transcript_reader.dart' show AssistantTextMessage, ConversationItem, SessionStatus;
import 'package:clide/builtin/claude/src/workflow_run.dart' show WorkflowRun;
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
  StreamSubscription<ConversationItem>? _primaryItemsSub;
  StreamSubscription<Map<String, WorkflowRun>>? _primaryWorkflowsSub;
  ClaudeUsage? _usage;
  Map<String, WorkflowRun> _workflows = const {};
  StreamSubscription<void>? _brokerChangeSub;
  Timer? _timer;
  late final Future<ClaudeStats> Function() _load;
  bool _subscribed = false;

  late SidebarTab _tab = widget.initialTab;
  ClaudeConfig? _config;
  ClaudeSessionOrchestrator? _orchestrator;

  /// Follows the primary session across respawns so this class never has to
  /// (T-552). The roster still watches the orchestrator directly — that is a
  /// different question, about every session rather than one.
  late final SessionReader _reader;

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
    // Assigned before `start()`, deliberately: start binds synchronously and
    // notifies, and a cascade would re-enter `_onPrimaryBindingChanged` while
    // `_reader` was still uninitialised.
    _reader = SessionReader.primary(orchestrator: _orchestrator);
    _bindPrimary();
    _reader
      ..addListener(_onPrimaryBindingChanged)
      ..start();
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
  ///
  /// The **roster** still needs this: the orchestrator notifies on any session
  /// change (spawn/close, and the visible/muted toggles the cockpit controls
  /// drive), and the roster rows are drawn from the whole session set, not from
  /// the primary. Binding to the primary is no longer this method's job — the
  /// [SessionReader] owns that (T-552) — so all that remains here is the
  /// rebuild.
  void _onOrchestratorChange() {
    if (mounted) setState(() {});
  }

  /// The primary's binding changed: attached, detached, or swapped for a new
  /// process. Only the *binding* — the reader does not notify per event, so
  /// this does not fire on every status tick.
  void _onPrimaryBindingChanged() {
    if (!mounted) return;
    // Absence is reported, not interpreted (T-551), so clearing is the
    // sidebar's decision to make: an unbound primary has no status and no
    // workflows, and stale ones would read as a live session.
    if (!_reader.attached && (_primaryStatus != null || _workflows.isNotEmpty)) {
      setState(() {
        _primaryStatus = null;
        _workflows = const {};
      });
      return;
    }
    setState(() {});
  }

  /// Subscribe once. The reader re-subscribes underneath across respawns, so
  /// these three outlive any number of session swaps — which is what removed
  /// the cancel/rebind/seed dance this class used to own.
  void _bindPrimary() {
    _primarySub = _reader.status.listen((s) {
      if (mounted) setState(() => _primaryStatus = s);
    });
    // The Activity tab's WORKFLOWS section tracks the primary session's live
    // workflow runs (T-416).
    _primaryWorkflowsSub = _reader.workflows.listen((w) {
      if (mounted) setState(() => _workflows = w);
    });
    // Watch for /usage responses: CLI-local output arrives as synthetic
    // assistant text; when it parses as usage, the Activity block updates
    // (T-415). Driven by the refresh control publishing '/usage'.
    _primaryItemsSub = _reader.items.listen((item) {
      if (item is! AssistantTextMessage || !item.synthetic) return;
      final parsed = parseUsageText(item.text);
      if (parsed != null && mounted) setState(() => _usage = parsed);
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
    _primaryItemsSub?.cancel();
    _primaryWorkflowsSub?.cancel();
    _brokerChangeSub?.cancel();
    _injectCtl.dispose();
    _config?.removeListener(_onConfigChange);
    _orchestrator?.removeListener(_onOrchestratorChange);
    _reader
      ..removeListener(_onPrimaryBindingChanged)
      ..dispose();
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
            SidebarTab.activity => ActivityTabView(stats: _stats, primaryStatus: _primaryStatus, config: _config, usage: _usage, workflows: _workflows),
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
              status: _primaryStatus,
              models: _orchestrator?.byId('primary')?.session.availableModels,
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
