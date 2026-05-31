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
import 'package:clide/builtin/claude/src/team_broker.dart' show TeamBroker, TeamTask;
import 'package:clide/builtin/claude/src/team_chat_sidebar.dart' show TeamChatSidebar;
import 'package:clide/builtin/claude/src/team_panel_host.dart' show teamColor;
import 'package:clide/builtin/claude/src/transcript_publisher.dart' show ClaudeConversation;
import 'package:clide/builtin/claude/src/transcript_reader.dart' show SessionStatus;
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
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
  StreamSubscription<void>? _brokerChangeSub;
  Timer? _timer;
  late final Future<ClaudeStats> Function() _load;
  bool _subscribed = false;

  late SidebarTab _tab = widget.initialTab;
  ClaudeConfig? _config;
  ClaudeSessionOrchestrator? _orchestrator;
  SessionStatus? _primaryStatus;

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
    unawaited(orch.spawn(SpawnSpec(
      id: forkId,
      role: 'fork of $memberName',
      // sessionId is a placeholder; real claude session id arrives via init.
      sessionId: forkId,
      cwd: managed.cwd,
      forkSourceSessionId: managed.sessionId,
    )));
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
    _brokerChangeSub?.cancel();
    _injectCtl.dispose();
    _config?.removeListener(_onConfigChange);
    _orchestrator?.removeListener(_onOrchestratorChange);
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
    final children = <Widget>[
      for (final m in _members)
        _AgentRosterRow(
          key: ValueKey(m.agentId),
          member: m,
          status: _memberStatus[m.agentId],
          orchestrator: _orchestrator,
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
          onFork: (name) => _forkMember(name),
        ),
    ];

    if (_tasks.isNotEmpty) {
      children.add(const SizedBox(height: 12));
      children.add(_taskSection(tokens));
    }

    // MESSAGES section (T-180): live broker chat feed + quick-post composer.
    final chatModel = _orchestrator?.chatModel;
    final broker = _orchestrator?.broker;
    if (chatModel != null && broker != null) {
      children.add(const SizedBox(height: 12));
      children.add(TeamChatSidebar(
        model: chatModel,
        broker: broker,
        onPopOut: _openChatPane,
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: children,
    );
  }

  Widget _taskSection(SurfaceTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClideText('TASKS', fontSize: clideFontSmall, color: tokens.globalTextMuted),
        const SizedBox(height: 4),
        for (final t in _tasks) _TaskRow(task: t, members: _members, broker: _orchestrator?.broker),
      ],
    );
  }

  /// Open the full team chat pane in the workspace (T-180).
  void _openChatPane() {
    ClideKernel.of(context).panels.activateTab(Slots.workspace, 'claude.team-chat');
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

// ---------------------------------------------------------------------------
// Reusable roster-row widget (T-171)
//
// Extract point for future siblings:
//   - T-181 adds a permission-mode badge to the trailing region.
//   - T-172 adds a fork button next to the close/mute icons.
// Extend _AgentRosterRow or compose it from a shared _RosterRowBase to avoid
// forking the layout. The trailing region is the explicit seam: the control
// icons column may grow with new additions.
// ---------------------------------------------------------------------------

/// A single agent roster row: color dot + name + status sub-text + controls.
///
/// Controls (trailing region):
/// - permission-mode badge (T-181) — D/A/P cycles the safe trio; shift-click
///   reaches bypassPermissions behind a confirm
/// - eye / eye-slash — show / hide the session pane
/// - speaker / speaker-slash — mute / unmute broker delivery
/// - inject (chat icon) — expand the inline message input
/// - fork (git-branch icon) — open a new pane branching from this session (T-172)
/// - close (×) — kill the session
class _AgentRosterRow extends StatefulWidget {
  const _AgentRosterRow({
    super.key,
    required this.member,
    required this.status,
    required this.orchestrator,
    required this.injectingAgentId,
    required this.injectController,
    required this.onToggleInject,
    required this.onInjectSubmit,
    required this.onClose,
    required this.onSetPermissionMode,
    required this.onFork,
  });

  final TeamMemberJoined member;
  final SessionStatus? status;
  final ClaudeSessionOrchestrator? orchestrator;

  /// The member name currently in inject mode (null = none).
  final String? injectingAgentId;

  /// Shared text controller for the inject field (cleared on submit/cancel).
  final TextEditingController injectController;

  final void Function(String memberName) onToggleInject;
  final void Function(String memberName, String text) onInjectSubmit;
  final void Function(String memberName) onClose;

  /// Called when the badge cycles to a new [mode] string for this member.
  /// Handles both safe-trio clicks and confirmed bypass. The parent sends
  /// the mode to the session via [StreamJsonSession.setPermissionMode].
  final void Function(String memberName, String mode) onSetPermissionMode;

  /// Called when the fork button is tapped (T-172). The session id of the
  /// member's managed session is passed so the host can open a fork pane.
  final void Function(String memberName) onFork;

  @override
  State<_AgentRosterRow> createState() => _AgentRosterRowState();
}

class _AgentRosterRowState extends State<_AgentRosterRow> {
  /// Whether the bypass-confirm inline prompt is showing.
  bool _confirmingBypass = false;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final managed = widget.orchestrator?.byMemberName(widget.member.name);
    final color = teamColor(widget.member.color, fallback: tokens.globalForeground);
    final st = widget.status;
    final model = st?.model ?? widget.member.model;
    final sub = [
      widget.member.agentType,
      if (model != null) shortModelLabel(model),
      if (st?.permissionMode != null) permissionModeLabel(st!.permissionMode!),
      if (st?.contextTokens != null) '${formatTokenCount(st!.contextTokens!)} ctx',
    ].join('  ·  ');

    final isVisible = managed?.visible ?? true;
    final isMuted = managed?.muted ?? false;
    final isInjecting = widget.injectingAgentId == widget.member.name;
    final currentMode = st?.permissionMode ?? 'default';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Color dot
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ),
              const SizedBox(width: 8),
              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClideText(widget.member.name, fontSize: clideFontSmall, color: tokens.globalForeground, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (sub.isNotEmpty) ClideText(sub, muted: true, fontSize: clideFontSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    // T-181: permission-mode badge (inline below the status sub-text).
                    if (managed != null)
                      _PermissionModeBadge(
                        mode: currentMode,
                        tokens: tokens,
                        onCycle: () {
                          final next = _nextSafeMode(currentMode);
                          widget.onSetPermissionMode(widget.member.name, next);
                        },
                        onBypass: () => setState(() => _confirmingBypass = true),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Trailing controls (T-171).
              // T-172 seam: append a fork icon button to this row.
              if (managed != null) _buildControls(context, tokens, managed, isVisible, isMuted, isInjecting),
            ],
          ),
          // Bypass confirm: replaces inject field area when active.
          if (_confirmingBypass) _buildBypassConfirm(tokens),
          // Inline inject-message field — visible only when toggled.
          if (isInjecting && !_confirmingBypass) _buildInjectField(context, tokens),
        ],
      ),
    );
  }

  /// Safe-mode cycle: default → acceptEdits → plan → default (T-181).
  static String _nextSafeMode(String current) {
    const cycle = ['default', 'acceptEdits', 'plan'];
    final idx = cycle.indexOf(current);
    return cycle[(idx + 1) % cycle.length];
  }

  Widget _buildBypassConfirm(SurfaceTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Row(
        children: [
          Expanded(
            child: ClideText(
              'Enable bypassPermissions? All tool calls will be auto-allowed.',
              fontSize: clideFontSmall,
              color: tokens.globalTextMuted,
            ),
          ),
          const SizedBox(width: 4),
          // Confirm
          Semantics(
            button: true,
            label: 'Confirm bypass',
            excludeSemantics: true,
            onTap: () {
              setState(() => _confirmingBypass = false);
              widget.onSetPermissionMode(widget.member.name, 'bypassPermissions');
            },
            child: ClideTappable(
              tooltip: 'Confirm',
              onTap: () {
                setState(() => _confirmingBypass = false);
                widget.onSetPermissionMode(widget.member.name, 'bypassPermissions');
              },
              builder: (ctx, hovered, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: ClideText('OK', fontSize: clideFontSmall, color: hovered ? tokens.globalForeground : tokens.globalFocus),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Cancel
          Semantics(
            button: true,
            label: 'Cancel bypass',
            excludeSemantics: true,
            onTap: () => setState(() => _confirmingBypass = false),
            child: ClideTappable(
              tooltip: 'Cancel',
              onTap: () => setState(() => _confirmingBypass = false),
              builder: (ctx, hovered, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                child: ClideText('Cancel', fontSize: clideFontSmall, color: hovered ? tokens.globalForeground : tokens.globalTextMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    SurfaceTokens tokens,
    ManagedSession managed,
    bool isVisible,
    bool isMuted,
    bool isInjecting,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show / hide
        _IconButton(
          painter: isVisible ? PhosphorIcons.eye : PhosphorIcons.eyeSlash,
          tooltip: isVisible ? 'Hide pane' : 'Show pane',
          color: tokens.globalTextMuted,
          onTap: () => isVisible ? widget.orchestrator!.hide(managed.id) : widget.orchestrator!.show(managed.id),
        ),
        // Mute / unmute
        _IconButton(
          painter: isMuted ? PhosphorIcons.eyeSlash : PhosphorIcons.eye,
          // NOTE: We use eye/eyeSlash as stand-ins until a dedicated speaker
          // icon is added to PhosphorIcons (no speaker codepoint yet).
          // The semantic tooltip still says mute/unmute so AT users are clear.
          tooltip: isMuted ? 'Unmute messages' : 'Mute messages',
          color: isMuted ? tokens.globalFocus : tokens.globalTextMuted,
          onTap: () => isMuted ? widget.orchestrator!.unmute(managed.id) : widget.orchestrator!.mute(managed.id),
        ),
        // Inject message
        _IconButton(
          painter: PhosphorIcons.chatCircle,
          tooltip: 'Inject message',
          color: isInjecting ? tokens.globalFocus : tokens.globalTextMuted,
          onTap: () => widget.onToggleInject(widget.member.name),
        ),
        // Fork session (T-172): branch into a new pane without touching the original.
        _IconButton(
          painter: PhosphorIcons.gitBranch,
          tooltip: 'Fork session',
          color: tokens.globalTextMuted,
          onTap: () => widget.onFork(widget.member.name),
        ),
        // Close session
        _IconButton(
          painter: PhosphorIcons.xMark,
          tooltip: 'Close session',
          color: tokens.globalTextMuted,
          onTap: () => widget.onClose(widget.member.name),
        ),
      ],
    );
  }

  Widget _buildInjectField(BuildContext context, SurfaceTokens tokens) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Row(
        children: [
          Expanded(
            child: _InjectTextField(
              controller: widget.injectController,
              tokens: tokens,
              onSubmit: (text) {
                if (text.trim().isNotEmpty) widget.onInjectSubmit(widget.member.name, text.trim());
              },
            ),
          ),
          const SizedBox(width: 4),
          _IconButton(
            painter: PhosphorIcons.xMark,
            tooltip: 'Cancel',
            color: tokens.globalTextMuted,
            onTap: () => widget.onToggleInject(widget.member.name),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Permission-mode badge (T-181)
// ---------------------------------------------------------------------------

/// Maps a permission-mode string to a single-letter badge label.
String _permissionModeBadge(String mode) => switch (mode) {
      'acceptEdits' => 'A',
      'plan' => 'P',
      'bypassPermissions' => 'B',
      _ => 'D', // default
    };

/// Clickable permission-mode badge shown in each roster row (T-181).
///
/// - Plain click → cycles the safe trio: default → acceptEdits → plan → default.
/// - Shift-click → shows the bypass confirm inline in the parent row.
///
/// The badge reflects the LIVE mode from [SessionStatus.permissionMode] (T-157).
/// It is a custom painted label (no Material), consistent with the rendering
/// stack rules (D-7, CLAUDE.md guardrails).
class _PermissionModeBadge extends StatelessWidget {
  const _PermissionModeBadge({
    required this.mode,
    required this.tokens,
    required this.onCycle,
    required this.onBypass,
  });

  final String mode;
  final SurfaceTokens tokens;

  /// Called on a plain click — the parent cycles to the next safe mode.
  final VoidCallback onCycle;

  /// Called on a shift-click — the parent shows the bypass confirm.
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    final label = _permissionModeBadge(mode);
    final isBypass = mode == 'bypassPermissions';
    final badgeColor = isBypass ? const Color(0xFFF06C6F) : tokens.globalFocus;

    final tooltip = 'Permission mode: ${permissionModeLabel(mode)}. '
        'Click to cycle default/acceptEdits/plan; Shift-click for bypassPermissions.';

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Semantics(
        button: true,
        label: 'Permission mode: $label',
        excludeSemantics: true,
        onTap: () {
          if (HardwareKeyboard.instance.isShiftPressed) {
            onBypass();
          } else {
            onCycle();
          }
        },
        child: ClideTappable(
          tooltip: tooltip,
          onTap: () {
            if (HardwareKeyboard.instance.isShiftPressed) {
              onBypass();
            } else {
              onCycle();
            }
          },
          builder: (ctx, hovered, _) => Container(
            width: 16,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(hovered ? 51 : 26),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: badgeColor.withAlpha(hovered ? 180 : 100), width: 1),
            ),
            child: ClideText(
              label,
              fontSize: 9,
              color: badgeColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single icon-button used in the roster row controls.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.painter,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final ClideIconPainter painter;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Icon-only button: expose the tooltip text as the Semantics button label
    // so AT (and widget tests) can find and activate it by name.
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      onTap: onTap,
      child: ClideTappable(
        tooltip: tooltip,
        onTap: onTap,
        builder: (ctx, hovered, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: ClideIcon(painter, size: 12, color: hovered ? ClideTheme.of(ctx).surface.globalForeground : color),
        ),
      ),
    );
  }
}

/// Inline text input for injecting a message into a session (T-171).
/// Submits on Enter; Cancel is handled by the parent via [_IconButton].
class _InjectTextField extends StatelessWidget {
  const _InjectTextField({
    required this.controller,
    required this.tokens,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final SurfaceTokens tokens;
  final void Function(String text) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        border: Border.all(color: tokens.panelBorder),
        borderRadius: BorderRadius.circular(3),
      ),
      child: EditableText(
        controller: controller,
        focusNode: FocusNode(debugLabel: 'inject-${controller.hashCode}')..requestFocus(),
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: clideFontSmall,
          color: tokens.globalForeground,
          height: 1.4,
        ),
        cursorColor: tokens.globalFocus,
        backgroundCursorColor: tokens.globalTextMuted,
        onSubmitted: onSubmit,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task row (T-171)
// ---------------------------------------------------------------------------

/// One row in the TASKS section: status marker + title + owner + reassign.
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.members,
    required this.broker,
  });

  final TeamTask task;
  final List<TeamMemberJoined> members;
  final TeamBroker? broker;

  @override
  Widget build(BuildContext context) {
    final tokens = ClideTheme.of(context).surface;
    final marker = switch (task.status) {
      'done' => '✓',
      'claimed' => '◈',
      _ => '○',
    };
    final markerColor = switch (task.status) {
      'done' => tokens.globalTextMuted,
      'claimed' => tokens.globalFocus,
      _ => tokens.globalForeground,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          ClideText(marker, fontSize: clideFontSmall, color: markerColor),
          const SizedBox(width: 6),
          Expanded(
            child: ClideText(
              task.title,
              fontSize: clideFontSmall,
              color: task.status == 'done' ? tokens.globalTextMuted : tokens.globalForeground,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (task.owner != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ClideText(task.owner!, fontSize: clideFontSmall, color: tokens.globalFocus),
            ),
          // Reassign: cycle to the next roster member.
          if (broker != null && broker!.members.length > 1)
            _IconButton(
              painter: PhosphorIcons.arrowClockwise,
              tooltip: 'Reassign task',
              color: tokens.globalTextMuted,
              onTap: () => _reassign(context),
            ),
        ],
      ),
    );
  }

  void _reassign(BuildContext context) {
    final b = broker;
    if (b == null || members.isEmpty) return;
    final brokerMembers = b.members;
    if (brokerMembers.isEmpty) return;
    // Cycle to the next member after the current owner.
    final currentIndex = brokerMembers.indexWhere((m) => m.name == task.owner);
    final nextIndex = (currentIndex + 1) % brokerMembers.length;
    b.reassignTask(task.id, brokerMembers[nextIndex].id);
  }
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
