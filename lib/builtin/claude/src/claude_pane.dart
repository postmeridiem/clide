import 'dart:async';
import 'dart:io';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'claude_banner.dart';
import 'claude_composer.dart';
import 'claude_config.dart';
import 'claude_status.dart';
import 'clipboard_paste.dart';
import 'conversation_controller.dart';
import 'conversation_view.dart';
import 'prompt_card.dart';
import 'session_index.dart';
import 'session_naming.dart';
import 'session_orchestrator.dart';
import 'session_picker.dart';
import 'slash_commands.dart';
import 'stream_json_session.dart';
import 'transcript_reader.dart';

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
  StreamSubscription<SessionStatus>? _statusSub;
  ConversationController? _conversation;
  StreamJsonSession? _session;
  SessionStatus _status = const SessionStatus();
  String? _sessionId;
  String? _repoRoot;
  String? _error;
  String _statusLine = 'starting…';

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

    Widget text(String t) => ClideText(t, fontSize: clideFontSmall, fontFamily: clideMonoFamily, color: tokens.statusBarForeground, maxLines: 1);

    final children = <Widget>[];
    void add(Widget w) {
      if (children.isNotEmpty) {
        children.add(ClideText('  ·  ', fontSize: clideFontSmall, fontFamily: clideMonoFamily, color: tokens.globalTextMuted, maxLines: 1));
      }
      children.add(w);
    }

    if (seg.leading != null) add(text(seg.leading!));
    // The permission-mode segment is an interactive badge — click or
    // Enter/Space (when focused) cycles it (T-226).
    if (mode != null) {
      add(_ModeBadge(label: permissionModeLabel(mode), tokens: tokens, onCycle: _session != null ? _cycleMode : null));
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
    // Spawn once, after the kernel is available.
    if (!_spawned) {
      _spawned = true;
      unawaited(_spawnWhenReady());
      // Warm the slash-command list in the background (lazy, idempotent) so
      // custom commands are recognised by the time the user types one (T-153).
      unawaited(activeClaudeConfig?.ensureProbe());
      // Reflect skills/config changes in the status line (T-154).
      activeClaudeConfig?.addListener(_onConfigChanged);
    }
  }

  @override
  void dispose() {
    activeClaudeConfig?.removeListener(_onConfigChanged);
    _statusSub?.cancel();
    _statusSub = null;
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
      await c.future.timeout(const Duration(seconds: 10), onTimeout: () {
        sub.cancel();
      });
      if (!mounted) return;
    }
    return _spawn();
  }

  Future<void> _spawn() async {
    if (!mounted) return;
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
    final forkSource = widget.forkSourceId;
    if (forkSource != null) {
      // Fork pane: branch source session into a new clide-managed session.
      // The clide-internal id is a fresh UUID; the real claude session id is
      // assigned by `--fork-session` and arrives in the init event (T-172).
      _sessionId ??= freshSessionId();
      try {
        managed = await orch.spawn(SpawnSpec(
          id: _orchId,
          role: 'fork ${widget.secondaryIndex}',
          sessionId: _sessionId!,
          cwd: repoRoot,
          forkSourceSessionId: forkSource,
        ));
      } catch (e) {
        if (mounted) setState(() => _error = 'Could not start fork: $e');
        return;
      }
      if (!mounted) return;
      setState(() => _statusLine = 'fork of $forkSource');
    } else {
      // Bind this pane to a specific session id (T-146). Primary: deterministic
      // → resumes across restarts. Secondary: fresh → a clean session.
      _sessionId ??= widget.isPrimary ? primarySessionId(repoRoot) : freshSessionId();

      // A transcript already on disk means the session existed before, so resume
      // it; `claude --session-id <id>` refuses an existing id (T-161/D-77).
      final home = Platform.environment['HOME'] ?? '';
      final transcriptFile = '$home/.claude/projects/${repoRoot.replaceAll('/', '-')}/$_sessionId.jsonl';
      final resume = await File(transcriptFile).exists();

      try {
        managed = await orch.spawn(SpawnSpec(
          id: _orchId,
          role: widget.isPrimary ? 'primary' : 'session ${widget.secondaryIndex}',
          sessionId: _sessionId!,
          cwd: repoRoot,
          resume: resume,
          transcriptPath: resume ? transcriptFile : null,
        ));
      } catch (e) {
        if (mounted) setState(() => _error = 'Could not start claude: $e');
        return;
      }
      if (!mounted) return;
      setState(() => _statusLine = resume ? 'resumed · $_sessionId' : 'new session · $_sessionId');
    }

    _session = managed.session;
    _conversation = managed.conversation;
    _statusSub = managed.session.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
    });
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
    }
    _session?.send(text);
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
  /// control channel (T-226). bypassPermissions is not reachable here — it
  /// stays behind the explicit confirmed path in the cockpit roster (T-181).
  void _cycleMode() {
    final s = _session;
    if (s == null) return;
    s.setPermissionMode(nextSafePermissionMode(_status.permissionMode ?? 'default'));
  }

  /// Focus the composer when the user taps empty conversation area (T-227).
  /// No-op while a prompt occupies the interaction zone (D-78) — a
  /// background tap must never pull focus from (or resurrect) the composer
  /// over an open prompt.
  void _focusComposerOnTap() {
    if (_session?.pendingPrompt != null) return;
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

  /// clide-owned `/clear` (T-156): respawn on a brand-new, empty session.
  Future<void> _clearSession() async {
    if (mounted) setState(() => _statusLine = 'clearing…');
    await _respawnWithSession(freshSessionId());
  }

  /// clide-owned `/resume` (T-156): pick a past session for this workspace and
  /// re-bind the pane to it.
  Future<void> _resumeFlow() async {
    final root = _repoRoot;
    final dialog = _kernel()?.dialog;
    if (root == null || dialog == null) return;
    final home = Platform.environment['HOME'] ?? '';
    final dir = Directory('$home/.claude/projects/${root.replaceAll('/', '-')}');
    final sessions = await listSessions(dir);
    if (!mounted) return;
    final picked = await dialog.show<String>(
      (ctx, dismiss) => SessionPickerDialog(
        sessions: sessions,
        onPick: (id) => dismiss(id),
        onCancel: dismiss,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _statusLine = 'resuming…');
    await _respawnWithSession(picked);
  }

  /// Tear the current session down and respawn bound to [sessionId]. The old
  /// process is killed via the orchestrator; its transcript stays on disk.
  Future<void> _respawnWithSession(String sessionId) async {
    _statusSub?.cancel();
    _statusSub = null;
    await activeSessionOrchestrator?.close(_orchId); // kills the old session
    _conversation = null;
    _session = null;
    _sessionId = sessionId;
    if (mounted) setState(() => _status = const SessionStatus());
    await _spawn();
  }

  // -- helpers --------------------------------------------------------------

  DaemonClient? _ipc() => _kernel()?.ipc;

  KernelServices? _kernel() {
    try {
      return ClideKernel.of(context);
    } catch (_) {
      return null;
    }
  }

  // -- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final title = widget.isPrimary ? 'claude — primary' : 'claude — secondary ${widget.secondaryIndex}';
    final tokens = ClideTheme.of(context).surface;

    final Widget body;
    if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: ClideText(_error!, muted: true),
      );
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
                    hiddenToolUseIds: _session?.promptedToolUseIds ?? const <String>{},
                    toolUseOutcomes: _session?.toolUseOutcomes ?? const <String, bool>{},
                    emptyState: ClaudeBanner(
                      role: widget.isPrimary ? 'primary' : 'session ${widget.secondaryIndex}',
                      workspace: _repoRoot,
                      statusLine: _statusLine,
                    ),
                  ),
                ),
              ),
              // An open prompt takes the composer's space and hides the text
              // input until it's answered, so interaction stays out of the
              // conversation stream (D-78).
              if (prompt != null && _session != null)
                ToolPromptCard(prompt: prompt, onResolve: _session!.resolvePrompt)
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
      body = const Center(child: ClideText('starting…', muted: true));
    }

    final content = widget.showChrome
        ? ClidePaneChrome(
            title: title,
            subtitle: _error ?? _statusLine,
            child: body,
          )
        : body;

    // Surface this pane's status to the bottom status-bar slot while it's
    // the focused pane (T-150).
    return ClidePane(
      contributionId: widget.contributionId,
      active: widget.active,
      statusWidget: _statusWidget(tokens),
      child: content,
    );
  }
}

/// Interactive permission-mode badge in the status line (T-226). Click, or
/// focus + Enter/Space, cycles the safe trio (ClideTappable handles the
/// ActivateIntent). A null [onCycle] (no live session) renders it inert.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.label, required this.tokens, required this.onCycle});

  final String label;
  final SurfaceTokens tokens;
  final VoidCallback? onCycle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onCycle != null,
      label: 'permission mode: $label. Activate to cycle.',
      excludeSemantics: true,
      child: ClideTappable(
        onTap: onCycle,
        tooltip: 'Permission mode — click or Ctrl/Cmd+M to cycle (default · accept-edits · plan)',
        builder: (context, hovered, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: hovered ? tokens.listItemHoverBackground : null,
            border: Border.all(color: hovered && onCycle != null ? tokens.globalFocus : tokens.globalBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClideText(label, fontSize: clideFontSmall, fontFamily: clideMonoFamily, color: tokens.statusBarForeground, maxLines: 1),
        ),
      ),
    );
  }
}
