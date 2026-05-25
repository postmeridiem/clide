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
    this.showChrome = true,
    this.active = true,
    this.contributionId = 'claude.primary',
  }) : assert(isPrimary || secondaryIndex != null, 'secondary panes need an index');

  final bool isPrimary;
  final bool showChrome;
  final int? secondaryIndex;

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

  // The status line surfaced to the bottom status bar via ClidePane — the
  // live session fields (model/mode/context, T-150) plus the configured
  // skills count from ClaudeConfig (T-154). Null when there's nothing yet.
  Widget? _statusWidget(SurfaceTokens tokens) {
    final skills = formatSkillsLabel(activeClaudeConfig?.skills.length ?? 0);
    final parts = [
      if (!_status.isEmpty) formatStatusLine(_status),
      if (skills != null) skills,
    ];
    if (parts.isEmpty) return null;
    return ClideText(
      parts.join('  ·  '),
      fontSize: clideFontSmall,
      fontFamily: clideMonoFamily,
      color: tokens.statusBarForeground,
      maxLines: 1,
    );
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
    // The controller's onDispose kills the session (process + streams).
    _conversation?.dispose();
    _conversation = null;
    _session = null;
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

    // Bind this pane to a specific session id (T-146). Primary: deterministic
    // → resumes across restarts. Secondary: fresh → a clean session.
    _sessionId ??= widget.isPrimary ? primarySessionId(repoRoot) : freshSessionId();

    // A transcript already on disk means the session existed before, so resume
    // it; `claude --session-id <id>` refuses an existing id (T-161/D-77).
    final home = Platform.environment['HOME'] ?? '';
    final transcriptFile = '$home/.claude/projects/${repoRoot.replaceAll('/', '-')}/$_sessionId.jsonl';
    final resume = await File(transcriptFile).exists();
    final sessionArgs = claudeLaunchArgs(_sessionId!, resume: resume);

    final StreamJsonSession session;
    try {
      final proc = await ClaudeStreamJsonProcess.start(sessionArgs: sessionArgs, cwd: repoRoot);
      session = StreamJsonSession(proc)..start();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start claude: $e');
      return;
    }
    if (!mounted) {
      await session.dispose();
      return;
    }

    _session = session;
    _conversation = ConversationController(stream: session.items, onDispose: session.dispose);
    _statusSub = session.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
    });
    setState(() => _statusLine = resume ? 'resumed · $_sessionId' : 'new session · $_sessionId');
  }

  // Send composed text to Claude over the stream-json channel. Commands clide
  // owns (T-156) are handled here, never forwarded — /clear and /resume fork
  // the session to a new id, so clide drives them: /clear starts fresh,
  // /resume picks a past session and re-binds to it.
  void _send(String text) {
    switch (clideOwnedCommand(text)) {
      case 'clear':
        unawaited(_clearSession());
        return;
      case 'resume':
        unawaited(_resumeFlow());
        return;
    }
    _session?.send(text);
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
  /// process is killed; its transcript stays on disk (history preserved).
  Future<void> _respawnWithSession(String sessionId) async {
    _statusSub?.cancel();
    _statusSub = null;
    _conversation?.dispose(); // onDispose kills the old session
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
              // An open prompt takes the composer's space and hides the text
              // input until it's answered, so interaction stays out of the
              // conversation stream (D-78).
              if (prompt != null && _session != null)
                ToolPromptCard(prompt: prompt, onResolve: _session!.resolvePrompt)
              else
                ClaudeComposer(
                  enabled: _session != null,
                  onSubmit: _send,
                  pasteResolver: () => resolveClipboardAttachment(const NativeClipboard()),
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
