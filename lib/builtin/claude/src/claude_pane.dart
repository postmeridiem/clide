import 'dart:async';
import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'account_settings_control.dart';
import 'claude_banner.dart';
import 'claude_composer.dart';
import 'claude_config.dart';
import 'claude_status.dart';
import 'claude_task_dock.dart';
import 'clipboard_paste.dart';
import 'activity_cluster.dart' show foldLevelFromName, kActivityFoldLevelKey;
import 'conversation_controller.dart';
import 'conversation_view.dart';
import 'model_picker_card.dart';
import 'permission_mode_control.dart';
import 'session_defaults.dart';
import 'prompt_card.dart';
import 'session_index.dart';
import 'session_naming.dart';
import 'session_orchestrator.dart';
import 'session_picker.dart';
import 'session_reader.dart';
import 'slash_commands.dart';
import 'stream_json_session.dart';
import 'task_list.dart';
import 'transcript_reader.dart';
import 'workflow_run.dart';

/// The Claude conversation pane. Drives `claude` over the stream-json control
/// protocol (D-77/D-78): a [StreamJsonSession] owns the process, its events
/// feed the [ConversationController], permission / AskUserQuestion prompts come
/// back as [ToolPrompt] cards the user answers, and input is written to the
/// process stdin. No tmux — `--resume` (D-77) provides session continuity.
class ClaudePane extends StatefulWidget {
  const ClaudePane({
    super.key,
    this.isPrimary = true,
    this.secondaryIndex,
    this.forkSourceId,
    this.onFork,
    this.showChrome = true,
    this.active = true,
    this.contributionId = 'claude.primary',
  }) : assert(isPrimary || secondaryIndex != null, 'secondary panes need an index');

  final bool isPrimary;
  final bool showChrome;
  final int? secondaryIndex;

  /// When non-null, spawn this pane as a fork of the given claude session id
  /// using `--resume <forkSourceId> --fork-session` (T-172). Takes precedence
  /// over the normal fresh/resume logic for secondary panes.
  final String? forkSourceId;

  /// Called when the user issues `/fork` to branch this session into a new
  /// pane. The argument is the current pane's claude session id, which the
  /// host (ClaudeSessionHost) uses to open a fork tab (T-172).
  final void Function(String sourceClaudeSessionId)? onFork;

  /// Whether this pane is the visible/focused sub-tab. Only the active
  /// pane publishes its status to the status-bar context slot (T-145).
  final bool active;

  /// Workspace contribution id this pane lives under (the Claude tab —
  /// keep in sync with the extension's TabContribution id). The status
  /// slot shows our message only while this contribution is focused.
  final String contributionId;

  @override
  State<ClaudePane> createState() => _ClaudePaneState();
}

class _ClaudePaneState extends State<ClaudePane> {
  /// Follows this pane's session — `primary` or `secondary-N` — across spawn,
  /// close and workspace switch (T-554). Created in `didChangeDependencies`
  /// alongside the first spawn, because `_orchId` is available from the widget
  /// but the kernel is not available earlier.
  late final SessionReader _reader;

  StreamSubscription<SessionStatus>? _statusSub;
  StreamSubscription<SessionEnd>? _endSub;
  StreamSubscription<ProjectOpened>? _projectSub;
  StreamSubscription<Message>? _commandSub;
  StreamSubscription<String>? _modelErrorSub;
  StreamSubscription<Map<String, WorkflowRun>>? _workflowsSub;
  ConversationController? _conversation;
  StreamJsonSession? _session;
  SessionStatus _status = const SessionStatus();
  String? _sessionId;
  String? _repoRoot;
  String? _error;
  String _statusLine = 'starting…';

  /// One-shot fork source: seeds the first bind, then cleared so /clear,
  /// /resume, and respawns operate on this pane's own session (T-375).
  late String? _forkSource = widget.forkSourceId;

  /// Whether a bare `/model` opened the picker in the interaction zone
  /// (T-408). An open prompt takes precedence; the picker shows once it
  /// resolves.
  bool _modelPickerOpen = false;
  bool _effortPickerOpen = false;
  bool _permissionPickerOpen = false;

  /// Effort level this pane's session runs at (`--effort`, T-412). Null =
  /// the CLI default. Set by /effort; carried by every respawn.
  String? _effort;

  bool _spawned = false;

  /// Per-session composer draft (text + caret), held here so an unsent
  /// message survives the composer being torn down and rebuilt — e.g. a
  /// permission prompt taking the composer's place (D-78) or a session
  /// switch within this pane (T-228). Keyed by claude session id; cleared
  /// when the message is sent.
  final Map<String, TextEditingValue> _drafts = {};

  /// Per-session submitted-prompt history (oldest-first) for Up/Down recall
  /// in the composer (T-163). Keyed by claude session id.
  final Map<String, List<String>> _history = {};

  /// Focus node for the composer, owned here so a tap on empty pane area can
  /// focus the input (T-227). Survives composer remounts (prompt swaps).
  final FocusNode _composerFocus = FocusNode(debugLabel: 'claude-composer');

  /// This pane's stable key in the session orchestrator (T-169).
  String get _orchId => widget.isPrimary ? 'primary' : 'secondary-${widget.secondaryIndex}';

  // The status line surfaced to the bottom status bar via ClidePane — the
  // live session fields (model/mode/context, T-150) plus the configured
  // skills count from ClaudeConfig (T-154). Null when there's nothing yet.
  Widget? _statusWidget(SurfaceTokens tokens) {
    final skills = formatSkillsLabel(activeClaudeConfig?.skills.length ?? 0);
    if (_status.isEmpty && skills == null) return null;

    final seg = statusSegmentsAroundMode(_status);
    final mode = _status.permissionMode;

    Widget text(String t) =>
        ClideText(t, fontSize: clideFontSmall, fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.statusBarForeground, maxLines: 1);

    final children = <Widget>[];
    void add(Widget w) {
      if (children.isNotEmpty) {
        children.add(ClideText('  ·  ', fontSize: clideFontSmall, fontFamily: ClideSettings.fonts.monoOf(context), color: tokens.globalTextMuted, maxLines: 1));
      }
      children.add(w);
    }

    if (seg.leading != null) add(text(seg.leading!));
    // The permission-mode segment is a passive, per-mode-coloured indicator now
    // (T-275); switching lives in the composer's mode control + Ctrl/Cmd+M.
    if (mode != null) {
      add(_ModeBadge(mode: mode, tokens: tokens));
    }
    if (seg.trailing != null) add(text(seg.trailing!));
    if (skills != null) add(text(skills));

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  // Rebuild when the Claude environment changes (e.g. skills load or a
  // watched .claude file changes) so the status line stays current (T-154).
  void _onConfigChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the kernel for dispose() — ancestor lookups there are illegal,
    // and the old lookup-and-swallow leaked the settings listener on every
    // disposed pane (T-366).
    _kernel = ClideKernel.of(context);
    // Spawn once, after the kernel is available.
    if (!_spawned) {
      _spawned = true;
      // Bind once, for the pane's whole life. `_orchId` is derived from
      // immutable widget props, so the reader follows this pane's session
      // through every spawn, close and workspace switch without the pane
      // re-subscribing (T-554). The cancel/rebind that used to live in
      // `_spawn`, `_rebindToActiveProject` and `dispose` is gone with it.
      _reader = SessionReader(sessionId: _orchId)..start();
      _statusSub = _reader.status.listen((s) {
        if (!mounted) return;
        setState(() => _status = s);
      });
      // Workflow runs arrive on out-of-band system events that add no
      // conversation item, so the view won't rebuild on its own — drive a
      // rebuild as the run map changes so the workflow card updates live
      // (T-416).
      _workflowsSub = _reader.workflows.listen((_) {
        if (!mounted) return;
        setState(() {});
      });
      // A rejected /model change (unknown name) rolls back silently in the
      // status — say why out loud (T-408).
      _modelErrorSub = _reader.modelErrors.listen((msg) {
        _kernel?.notify.warn(msg, title: 'model');
      });
      // Surface a dead process instead of letting it look thoughtful (T-361).
      // The reader replays an end that already happened, so the late-binder
      // case this pane used to handle by hand is handled for everyone now.
      _endSub = _reader.ended.listen(_onSessionEnd);
      unawaited(_spawnWhenReady());
      // Warm the slash-command list in the background (lazy, idempotent) so
      // custom commands are recognised by the time the user types one (T-153).
      unawaited(activeClaudeConfig?.ensureProbe());
      // Reflect skills/config changes in the status line (T-154).
      activeClaudeConfig?.addListener(_onConfigChanged);
      // Rebind to the new repo's session when the workspace is switched in
      // place (Open Project/Folder). This pane is built once behind a
      // GlobalKey and spawns once, so without this it would keep the previous
      // repo's session after a switch (T-269).
      _projectSub = ClideKernel.of(context).events.on<ProjectOpened>().listen(_onProjectChanged);
      // Sidebar controls (and any future surface) drive this pane's session by
      // publishing slash-command text on builtin.claude/command (T-414) —
      // executed through the exact _send routing the composer uses, so the
      // control and the typed command are one code path (D-6). Only the
      // primary pane listens: the controls target the primary session, and a
      // second listener would double-execute.
      if (widget.isPrimary) {
        _commandSub = ClideKernel.of(context).messages.subscribe(publisher: 'builtin.claude', channel: 'command').listen((msg) {
          final text = msg.data['text'] as String?;
          if (text != null && text.isNotEmpty) _send(text);
        });
      }
      // Re-fold the conversation when the activity fold-level setting changes
      // (claude.activity.fold-level command, T-235).
      ClideKernel.of(context).settings.addListener(_onSettingsChanged);
    }
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    activeClaudeConfig?.removeListener(_onConfigChanged);
    _kernel?.settings.removeListener(_onSettingsChanged);
    _projectSub?.cancel();
    _commandSub?.cancel();
    _projectSub = null;
    _statusSub?.cancel();
    _statusSub = null;
    _endSub?.cancel();
    _endSub = null;
    _modelErrorSub?.cancel();
    _modelErrorSub = null;
    _workflowsSub?.cancel();
    _workflowsSub = null;
    _reader.dispose();
    // The orchestrator owns the session, so disposing this pane does NOT kill
    // it — that's what lets a hidden/kept-alive pane keep its session (T-169).
    // A secondary tab being *closed* is a real teardown, so close its session;
    // the primary persists (its deterministic id resumes next launch), and the
    // orchestrator disposes everything on extension teardown.
    if (!widget.isPrimary) unawaited(activeSessionOrchestrator?.close(_orchId));
    _conversation = null;
    _session = null;
    _composerFocus.dispose();
    super.dispose();
  }

  // -- spawn ----------------------------------------------------------------

  Future<void> _spawnWhenReady() async {
    if (!mounted) return;
    final kernel = ClideKernel.of(context);
    if (!kernel.project.isOpen) {
      final c = Completer<void>();
      late final StreamSubscription<ProjectOpened> sub;
      sub = kernel.events.on<ProjectOpened>().listen((_) {
        sub.cancel();
        if (!c.isCompleted) c.complete();
      });
      await c.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          sub.cancel();
        },
      );
      if (!mounted) return;
    }
    return _spawn();
  }

  /// Rebind to the active workspace when the project is switched in place
  /// (T-269). Only the primary rebinds — secondaries/forks belong to the old
  /// repo and are dropped by the host. A no-op when the path is unchanged or
  /// the session hasn't resolved its repo yet.
  void _onProjectChanged(ProjectOpened e) {
    if (!mounted || !widget.isPrimary) return;
    if (_repoRoot == null || e.path == _repoRoot) return;
    unawaited(_rebindToActiveProject());
  }

  /// Tear down the current session and respawn against the now-active
  /// workspace: drop the cached session id and repo root so [_spawn]
  /// re-resolves both for the new repo (T-269).
  Future<void> _rebindToActiveProject() async {
    // No subscription juggling here any more: the reader follows `_orchId`
    // through the close and the respawn below (T-554).
    _modelPickerOpen = false;
    _effortPickerOpen = false;
    _permissionPickerOpen = false;
    await activeSessionOrchestrator?.close(_orchId); // kills the old repo's session
    _conversation = null;
    _session = null;
    _sessionId = null;
    _repoRoot = null;
    if (mounted) {
      setState(() {
        _status = const SessionStatus();
        _error = null;
        _statusLine = 'starting…';
      });
    }
    await _spawn();
  }

  Future<void> _spawn() async {
    if (!mounted) return;
    // New sessions inherit the user's Claude defaults (T-457): effort flows
    // through --effort below; model + permission mode are applied post-spawn.
    final settings = ClideKernel.of(context).settings;
    _effort ??= defaultEffortFlag(settings);
    var isNewSession = false;
    final ipc = _ipc();
    if (ipc == null || !ipc.isConnected) {
      setState(() => _error = 'Daemon not connected.');
      return;
    }

    String repoRoot = Directory.current.path;
    final rootResp = await ipc.request('files.root');
    if (rootResp.ok) {
      repoRoot = (rootResp.data['path'] as String?) ?? repoRoot;
    }
    _repoRoot = repoRoot;

    // The orchestrator owns the session (T-169): spawn-or-bind by our pane key,
    // so the session (and its accumulating conversation) outlives this pane.
    final orch = activeSessionOrchestrator;
    if (orch == null) {
      setState(() => _error = 'Session orchestrator unavailable.');
      return;
    }

    final ManagedSession managed;
    final forkSource = _forkSource;
    if (forkSource != null) {
      // Fork pane: branch source session into a new clide-managed session.
      // The clide-internal id is a fresh UUID; the real claude session id is
      // assigned by `--fork-session` and arrives in the init event (T-172).
      _sessionId ??= freshSessionId();
      try {
        managed = await orch.spawn(
          SpawnSpec(
            id: _orchId,
            role: 'fork ${widget.secondaryIndex}',
            sessionId: _sessionId!,
            cwd: repoRoot,
            forkSourceSessionId: forkSource,
            effort: _effort,
          ),
        );
      } catch (e) {
        if (mounted) setState(() => _error = 'Could not start fork: $e');
        return;
      }
      // One-shot: the fork source seeds only the FIRST bind. Leaving it set
      // made /clear re-fork the original conversation instead of clearing —
      // every later respawn must operate on this pane's own session (T-375).
      _forkSource = null;
      if (!mounted) return;
      setState(() => _statusLine = 'fork of $forkSource');
    } else {
      // Bind this pane to a specific session id (T-146). Primary: deterministic
      // → resumes across restarts. Secondary: fresh → a clean session.
      _sessionId ??= widget.isPrimary ? primarySessionId(repoRoot) : freshSessionId();

      // A transcript already on disk means the session existed before, so resume
      // it; `claude --session-id <id>` refuses an existing id (T-161/D-77).
      final transcriptFile = claudeTranscriptPath(repoRoot, _sessionId!);
      final resume = await File(transcriptFile).exists();

      try {
        managed = await orch.spawn(
          SpawnSpec(
            id: _orchId,
            role: widget.isPrimary ? 'primary' : 'session ${widget.secondaryIndex}',
            sessionId: _sessionId!,
            cwd: repoRoot,
            resume: resume,
            transcriptPath: resume ? transcriptFile : null,
            effort: _effort,
          ),
        );
      } catch (e) {
        if (mounted) setState(() => _error = 'Could not start claude: $e');
        return;
      }
      if (!mounted) return;
      isNewSession = !resume;
      setState(() => _statusLine = resume ? 'resumed · $_sessionId' : 'new session · $_sessionId');
    }

    _session = managed.session;
    _conversation = managed.conversation;
    // A brand-new session (not a resume or fork) starts on the user's default
    // model + permission mode (T-457). Sent as control requests; the CLI
    // applies them after init. 'default'/unset values are no-ops.
    if (isNewSession) applySessionDefaults(managed.session, settings);
    // The wire never reports effort — record what this session was spawned
    // with so the status line / sidebar can show it (T-412).
    if (_effort != null) managed.session.noteEffort(_effort!);
    // Diagnostic (T-274 follow-up): record how this pane bound its session —
    // a fresh spawn vs connecting to existing on-disk history (the seed read
    // from the transcript/sidecar). Surfaces the resume path in `make run`.
    final seeded = _conversation?.items.length ?? 0;
    _kernel?.log.info(
      'claude',
      'pane $_orchId bound session ${_sessionId ?? '?'} in $repoRoot — '
          '${seeded > 0 ? 'connected to history ($seeded seeded item(s))' : 'fresh session (no history)'}',
    );
  }

  /// The claude process exited under this pane's live session. Stop looking
  /// busy, say so in the status line, and log the drained stderr tail —
  /// the diagnostics that used to vanish (T-361).
  void _onSessionEnd(SessionEnd end) {
    if (!mounted) return;
    final tail = end.stderrTail.isEmpty ? '' : '; stderr tail:\n${end.stderrTail.join('\n')}';
    _kernel?.log.warn('claude', 'session $_orchId exited (code ${end.exitCode})$tail');
    // Surface the CLI's own reason (e.g. "Session ID … is already in use")
    // instead of an opaque "code 1" (T-437).
    final why = end.reason.isEmpty ? '' : ' — ${end.reason}';
    setState(() => _statusLine = 'claude exited (code ${end.exitCode})$why · /clear to restart');
  }

  // Send composed text to Claude over the stream-json channel. Commands clide
  // owns (T-156) are handled here, never forwarded — /clear and /resume fork
  // the session to a new id, so clide drives them: /clear starts fresh,
  // /resume picks a past session and re-binds to it. /fork branches the
  // conversation into a new pane (T-172).
  void _send(String text) {
    _appendHistory(text);
    switch (clideOwnedCommand(text)) {
      case 'clear':
        unawaited(_clearSession());
        return;
      case 'resume':
        unawaited(_resumeFlow());
        return;
      case 'fork':
        _forkSession();
        return;
      case 'model':
        _modelCommand(slashCommandArg(text) ?? '');
        return;
      case 'effort':
        _effortCommand(slashCommandArg(text) ?? '');
        return;
      case 'permissions':
        _permissionsCommand(slashCommandArg(text) ?? '');
        return;
      case 'status':
        _openMetaTab('activity');
        return;
      case 'config':
      case 'mcp':
      case 'agents':
      case 'hooks':
        _openMetaTab('config');
        return;
      case 'memory':
        _openMemory();
        return;
      case 'help':
        _helpCommand();
        return;
    }
    // Route the rest (T-411): a known TUI-only builtin never reaches the
    // session — forwarded it would error (or, un-advertised, bracket-paste to
    // the model as literal text, burning a turn). It becomes a local notice
    // card pointing at the clide-native way instead.
    final advertised = activeClaudeConfig?.slashCommands ?? kFallbackSlashCommands;
    if (routeSlashCommand(text, advertised: advertised) == SlashRoute.unavailable) {
      _session?.addLocalNotice(tuiOnlyNotice(slashCommandToken(text)!));
      return;
    }
    _session?.send(text);
  }

  /// clide-owned `/model` (T-408): with an argument, set the model directly;
  /// bare, open the picker in the interaction zone (D-78).
  void _modelCommand(String arg) {
    if (_session == null) return;
    if (arg.isNotEmpty) {
      _session!.setModel(arg);
      return;
    }
    setState(() => _modelPickerOpen = true);
  }

  void _pickModel(String value) {
    _session?.setModel(value);
    _closeModelPicker();
  }

  void _closeModelPicker() {
    setState(() => _modelPickerOpen = false);
    _composerFocus.requestFocus();
  }

  /// clide-owned `/effort` (T-412): with a level, respawn-with-resume carrying
  /// `--effort`; bare, open the picker. No set_effort control subtype exists
  /// (probed 2.1.175), so the respawn IS the mechanism — resume keeps the
  /// conversation, only the process restarts.
  void _effortCommand(String arg) {
    if (_session == null) return;
    if (arg.isEmpty) {
      setState(() => _effortPickerOpen = true);
      return;
    }
    if (!kEffortLevels.any((l) => l.value == arg)) {
      _session!.addLocalNotice('unknown effort "$arg" — levels: ${kEffortLevels.map((l) => l.value).join(', ')}');
      return;
    }
    _setEffort(arg);
  }

  void _pickEffort(String value) {
    _closeEffortPicker();
    _setEffort(value);
  }

  void _closeEffortPicker() {
    setState(() => _effortPickerOpen = false);
    _composerFocus.requestFocus();
  }

  void _setEffort(String level) {
    final sid = _sessionId;
    if (sid == null) return;
    _effort = level;
    _kernel?.notify.info('effort $level — restarting the session to apply', title: 'effort');
    unawaited(_respawnWithSession(sid));
  }

  /// clide-owned `/permissions` (T-413): with a mode, set it directly over
  /// set_permission_mode; bare, open a picker — the same interaction-zone
  /// pattern as /model and /effort.
  void _permissionsCommand(String arg) {
    final s = _session;
    if (s == null) return;
    if (arg.isEmpty) {
      setState(() => _permissionPickerOpen = true);
      return;
    }
    if (!kPermissionModes.any((m) => m.value == arg)) {
      s.addLocalNotice('unknown permission mode "$arg" — modes: ${kPermissionModes.map((m) => m.value).join(', ')}');
      return;
    }
    s.setPermissionMode(arg);
  }

  void _pickPermissionMode(String value) {
    _closePermissionPicker();
    _session?.setPermissionMode(value);
  }

  void _closePermissionPicker() {
    setState(() => _permissionPickerOpen = false);
    _composerFocus.requestFocus();
  }

  /// Navigate to the Claude sidebar and select a sub-tab (T-413): the
  /// /status//config//mcp//agents//hooks commands land here.
  void _openMetaTab(String tab) {
    final k = _kernel;
    if (k == null) return;
    k.panels.activateTab(Slots.sidebar, 'claude.meta');
    k.messages.publish('builtin.claude', 'meta.tab', {'tab': tab});
  }

  /// clide-owned `/memory` (T-413): open the workspace CLAUDE.md in the editor.
  void _openMemory() {
    final root = _repoRoot;
    if (root == null) return;
    unawaited(_ipc()?.request('editor.open', args: {'path': '$root/CLAUDE.md'}));
  }

  /// clide-owned `/help` (T-413): a local summary card — never the CLI's TUI
  /// help, which doesn't exist headless.
  void _helpCommand() {
    final advertised = (activeClaudeConfig?.slashCommands ?? kFallbackSlashCommands).where((c) => !kClideOwnedCommands.contains(c)).toList()..sort();
    _session?.addLocalNotice(
      'clide commands: ${(kClideOwnedCommands.toList()..sort()).map((c) => '/$c').join(' ')}\n'
      'claude commands & skills: ${advertised.map((c) => '/$c').join(' ')}',
    );
  }

  /// Record a submitted prompt in the active session's history (T-163),
  /// de-duping immediate repeats. Empty/whitespace prompts are skipped.
  void _appendHistory(String text) {
    final id = _sessionId;
    if (id == null || text.trim().isEmpty) return;
    final list = _history.putIfAbsent(id, () => <String>[]);
    if (list.isEmpty || list.last != text) list.add(text);
  }

  /// Cycle this pane's session through the safe permission-mode trio
  /// (default → acceptEdits → plan → default), sent over the stream-json
  /// control channel (T-226). bypassPermissions is not in the plain chord —
  /// it's in the shift-modified full cycle ([_cycleModeFull], T-510).
  void _cycleMode() {
    final s = _session;
    if (s == null) return;
    s.setPermissionMode(nextSafePermissionMode(_status.permissionMode ?? 'default'));
  }

  /// Cycle through the full mode list including bypassPermissions —
  /// Ctrl/Cmd+Shift+M, where holding shift is the explicit opt-in for the
  /// footgun (T-510).
  void _cycleModeFull() {
    final s = _session;
    if (s == null) return;
    s.setPermissionMode(nextPermissionMode(_status.permissionMode ?? 'default'));
  }

  /// Focus the composer when the user taps empty conversation area (T-227).
  /// No-op while a prompt occupies the interaction zone (D-78) — a
  /// background tap must never pull focus from (or resurrect) the composer
  /// over an open prompt.
  void _focusComposerOnTap() {
    if (_session?.pendingPrompt != null || _modelPickerOpen || _effortPickerOpen || _permissionPickerOpen) return;
    _composerFocus.requestFocus();
  }

  /// Persist (or clear) the composer draft for the active session (T-228).
  /// The composer reports an empty value on submit/clear, which drops the
  /// entry so a sent message doesn't reappear.
  void _onDraftChanged(TextEditingValue value) {
    final id = _sessionId;
    if (id == null) return;
    if (value.text.isEmpty) {
      _drafts.remove(id);
    } else {
      _drafts[id] = value;
    }
  }

  /// clide-owned `/fork` (T-172): branch this conversation into a new pane.
  ///
  /// Delegates to the [onFork] callback supplied by [ClaudeSessionHost] with
  /// the current pane's claude session id. If the session hasn't started yet
  /// or no callback was supplied, the command is silently ignored.
  void _forkSession() {
    final sourceId = _sessionId;
    if (sourceId == null) return;
    widget.onFork?.call(sourceId);
  }

  /// clide-owned `/clear` (T-156).
  ///
  /// The primary pane is anchored to a deterministic session id that resumes
  /// across restarts (D-77/T-146), so clearing it must empty THAT session in
  /// place: delete its transcript and respawn fresh on the SAME id. Spawning a
  /// throwaway random id instead would orphan the cleared state — the next
  /// launch would re-resolve to the deterministic id and resume the pre-clear
  /// conversation, which is exactly the continuity break this fixes (T-268).
  /// Secondary panes are throwaway sessions, so for them a fresh random id is
  /// the clear.
  Future<void> _clearSession() async {
    if (mounted) setState(() => _statusLine = 'clearing…');
    final root = _repoRoot;
    if (widget.isPrimary && root != null) {
      await _respawnWithSession(primarySessionId(root), clearTranscript: true);
      return;
    }
    await _respawnWithSession(freshSessionId());
  }

  /// clide-owned `/resume` (T-156): pick a past session for this workspace and
  /// re-bind the pane to it.
  Future<void> _resumeFlow() async {
    final root = _repoRoot;
    final dialog = _kernel?.dialog;
    if (root == null || dialog == null) return;
    final dir = Directory(claudeProjectDir(root));
    // Companion transcripts are excluded (T-545): clide writes one per run and
    // none of them is a conversation a pane can usefully resume into.
    final sessions = await listSessions(dir, includeCompanions: false);
    if (!mounted) return;
    final picked = await dialog.show<String>((ctx, dismiss) => SessionPickerDialog(sessions: sessions, onPick: (id) => dismiss(id), onCancel: dismiss));
    if (picked == null || !mounted) return;
    setState(() => _statusLine = 'resuming…');
    await _respawnWithSession(picked);
  }

  /// Tear the current session down and respawn bound to [sessionId]. The old
  /// process is killed via the orchestrator; its transcript stays on disk
  /// unless [clearTranscript] is set, in which case [sessionId]'s transcript is
  /// erased after the kill so `--session-id` re-creates it empty (T-268).
  Future<void> _respawnWithSession(String sessionId, {bool clearTranscript = false}) async {
    _statusSub?.cancel();
    _statusSub = null;
    _endSub?.cancel();
    _endSub = null;
    _modelErrorSub?.cancel();
    _modelErrorSub = null;
    _workflowsSub?.cancel();
    _workflowsSub = null;
    _modelPickerOpen = false;
    _effortPickerOpen = false;
    _permissionPickerOpen = false;
    await activeSessionOrchestrator?.close(_orchId); // kills the old session
    // Erase only after the process is dead, so claude isn't mid-write.
    final root = _repoRoot;
    if (clearTranscript && root != null) {
      await clearSessionTranscript(claudeProjectDir(root), sessionId);
    }
    _conversation = null;
    _session = null;
    _sessionId = sessionId;
    if (mounted) setState(() => _status = const SessionStatus());
    await _spawn();
  }

  // -- helpers --------------------------------------------------------------

  DaemonClient? _ipc() => _kernel?.ipc;

  /// Cached in didChangeDependencies (T-366); see note there.
  KernelServices? _kernel;

  // -- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title = widget.isPrimary
        ? ClideSettings.i18n.string(context, 'pane.title.primary', namespace: 'builtin.claude', placeholder: 'claude — primary')
        : ClideSettings.i18n.interpolated(
            context,
            'pane.title.secondary',
            namespace: 'builtin.claude',
            placeholder: 'claude — secondary ${widget.secondaryIndex}',
            replacers: [I18nReplacer(from: '{index}', replace: '${widget.secondaryIndex}')],
          );
    final tokens = ClideSettings.theme.of(context).surface;

    final Widget body;
    if (_error != null) {
      body = Padding(padding: const EdgeInsets.all(16), child: ClideText(_error!, muted: true));
    } else if (_conversation != null) {
      // Rebuild conversation + composer zone together on each prompt change so
      // the view hides a prompted tool-use card the moment its prompt appears
      // (D-78), and the composer zone swaps to the prompt UI.
      body = StreamBuilder<ToolPrompt?>(
        stream: _session?.pendingPromptStream,
        initialData: _session?.pendingPrompt,
        builder: (context, snap) {
          final prompt = snap.data;
          return Column(
            children: [
              Expanded(
                // A tap on empty conversation area focuses the composer
                // (T-227). Translucent so message links, copy buttons, and
                // the SelectableRegion's selection drags win their own
                // gestures; only an unclaimed tap reaches us.
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _focusComposerOnTap,
                  child: ConversationView(
                    controller: _conversation!,
                    foldLevel: foldLevelFromName(_kernel?.settings.get<String>(kActivityFoldLevelKey)),
                    hiddenToolUseIds: _session?.promptedToolUseIds ?? const <String>{},
                    toolUseOutcomes: _session?.toolUseOutcomes ?? const <String, bool>{},
                    quietErrorToolUseIds: _session?.quietErrorToolUseIds ?? const <String>{},
                    workflows: _session?.workflows ?? const <String, WorkflowRun>{},
                    emptyState: ClaudeBanner(
                      role: widget.isPrimary
                          ? ClideSettings.i18n.string(context, 'banner.role.primary', namespace: 'builtin.claude', placeholder: 'primary')
                          : ClideSettings.i18n.interpolated(
                              context,
                              'banner.role.secondary',
                              namespace: 'builtin.claude',
                              placeholder: 'session ${widget.secondaryIndex}',
                              replacers: [I18nReplacer(from: '{index}', replace: '${widget.secondaryIndex}')],
                            ),
                      workspace: _repoRoot,
                      statusLine: _statusLine,
                    ),
                  ),
                ),
              ),
              // Claude's task list, docked above the composer (T-308). Rebuilds
              // with the conversation; renders nothing when there are no tasks.
              ListenableBuilder(
                listenable: _conversation!,
                builder: (_, _) => ClaudeTaskDock(tasks: taskListFrom(_conversation!.items)),
              ),
              // An open prompt takes the composer's space and hides the text
              // input until it's answered, so interaction stays out of the
              // conversation stream (D-78). The /model picker uses the same
              // slot; a prompt outranks it (T-408).
              if (prompt != null && _session != null)
                ToolPromptCard(prompt: prompt, onResolve: _session!.resolvePrompt)
              else if (_modelPickerOpen && _session != null)
                ModelPickerCard(
                  models: _session!.availableModels.isEmpty ? kFallbackModels : _session!.availableModels,
                  currentModel: _status.model,
                  onPick: _pickModel,
                  onCancel: _closeModelPicker,
                )
              else if (_effortPickerOpen && _session != null)
                ModelPickerCard(
                  title: 'effort',
                  models: kEffortLevels,
                  currentModel: _status.effort,
                  // Exact match — containment would mark `high` inside `xhigh`.
                  isCurrent: (o, c) => c != null && o.value == c,
                  onPick: _pickEffort,
                  onCancel: _closeEffortPicker,
                )
              else if (_permissionPickerOpen && _session != null)
                ModelPickerCard(
                  title: 'permissions',
                  models: kPermissionModes,
                  currentModel: _status.permissionMode,
                  isCurrent: (o, c) => c != null && o.value == c,
                  onPick: _pickPermissionMode,
                  onCancel: _closePermissionPicker,
                )
              else
                StreamBuilder<bool>(
                  stream: _session?.busyStream,
                  initialData: _session?.busy ?? false,
                  builder: (context, busySnap) => ClaudeComposer(
                    // Key by session so switching sessions in this pane
                    // remounts the composer with that session's own draft.
                    key: ValueKey('composer-${_sessionId ?? 'pending'}'),
                    enabled: _session != null,
                    busy: busySnap.data ?? false,
                    onInterrupt: _session?.interrupt,
                    onCycleMode: _cycleMode,
                    onCycleModeFull: _cycleModeFull,
                    permissionMode: _status.permissionMode,
                    onSetPermissionMode: _session != null ? (m) => _session!.setPermissionMode(m) : null,
                    onSubmit: _send,
                    pasteResolver: () => resolveClipboardAttachment(const NativeClipboard()),
                    initialValue: _sessionId == null ? null : _drafts[_sessionId],
                    onDraftChanged: _onDraftChanged,
                    history: _sessionId == null ? const [] : (_history[_sessionId] ?? const []),
                    focusNode: _composerFocus,
                  ),
                ),
            ],
          );
        },
      );
    } else {
      body = Center(
        child: ClideText(ClideSettings.i18n.string(context, 'pane.starting', namespace: 'builtin.claude', placeholder: 'starting…'), muted: true),
      );
    }

    final content = widget.showChrome
        ? ClidePaneChrome(
            title: title,
            subtitle: _error ?? _statusLine,
            // Per-repo Claude account badge (T-481): shows + switches the
            // account this workspace is bound to; hidden when none registered.
            trailing: [ClaudeAccountBadge(workspaceRoot: _repoRoot)],
            child: body,
          )
        : body;

    // Surface this pane's status to the bottom status-bar slot while it's
    // the focused pane (T-150).
    return ClidePane(contributionId: widget.contributionId, active: widget.active, statusWidget: _statusWidget(tokens), child: content);
  }
}

/// Passive permission-mode indicator in the status line (T-275). Mode
/// switching now lives in the composer's mode control + Ctrl/Cmd+M (T-226), so
/// this is a plain, per-mode-coloured text mirror — no click, no border.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode, required this.tokens});

  final String mode;
  final SurfaceTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: ClideSettings.i18n.interpolated(
        context,
        'pane.modeBadge.semantics',
        namespace: 'builtin.claude',
        placeholder: 'permission mode: ${permissionModeLabel(mode)}',
        replacers: [I18nReplacer(from: '{mode}', replace: permissionModeLabel(mode))],
      ),
      excludeSemantics: true,
      child: ClideText(
        permissionModeLabel(mode),
        fontSize: clideFontSmall,
        fontFamily: ClideSettings.fonts.monoOf(context),
        color: permissionModeColor(mode, tokens),
        maxLines: 1,
      ),
    );
  }
}
