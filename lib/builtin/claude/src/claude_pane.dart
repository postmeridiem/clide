import 'dart:async';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import 'claude_composer.dart';
import 'clipboard_paste.dart';
import 'conversation_controller.dart';
import 'conversation_view.dart';
import 'session_naming.dart';
import 'tmux_session.dart' as tmux;
import 'transcript_publisher.dart';
import 'transcript_reader.dart';

class ClaudePane extends StatefulWidget {
  const ClaudePane({
    super.key,
    this.isPrimary = true,
    this.secondaryIndex,
    this.showChrome = true,
  }) : assert(isPrimary || secondaryIndex != null, 'secondary panes need an index');

  final bool isPrimary;
  final bool showChrome;
  final int? secondaryIndex;

  @override
  State<ClaudePane> createState() => _ClaudePaneState();
}

class _ClaudePaneState extends State<ClaudePane> {
  // Fixed tmux window size — Claude's TUI is no longer rendered (we read
  // its transcript instead, T-137/D-75), so a sane default is enough to
  // keep claude's layout happy inside the headless tmux session.
  static const _cols = 120;
  static const _rows = 40;
  static String? _tmuxConfPath;

  StreamSubscription<DaemonEvent>? _eventSub;
  ConversationController? _conversation;
  TranscriptPublisher? _feed;
  String? _paneId;
  String? _sessionName;
  String? _sessionId;
  String? _error;
  String _statusLine = 'attaching…';

  bool _spawned = false;
  bool _usingTmux = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Spawn once, after the kernel is available. The conversation renders
    // from the transcript, so we no longer wait on a terminal resize.
    if (!_spawned) {
      _spawned = true;
      unawaited(_spawnWhenReady());
    }
  }

  @override
  void dispose() {
    _conversation?.dispose();
    _conversation = null;
    unawaited(_feed?.dispose());
    _feed = null;
    _eventSub?.cancel();
    _eventSub = null;
    final id = _paneId;
    final sessionName = _sessionName;
    _paneId = null;
    // Secondary panes own their tmux session — close on dispose.
    // Primary panes leave the tmux session alive so the next launch
    // re-attaches via `tmux new-session -A` (D-41).
    //
    // pane.close kills the PTY-spawned tmux *client*; the tmux server
    // keeps the session alive. We need an explicit kill-session for
    // secondaries to actually disappear (D-41 close semantics).
    if (id != null && !widget.isPrimary) {
      unawaited(_ipc()?.request('pane.close', args: {'id': id}));
      if (sessionName != null) {
        unawaited(tmux.killSession(sessionName));
      }
    }
    super.dispose();
  }

  // -- tmux config extraction -----------------------------------------------

  static Future<String?> _ensureTmuxConf() async {
    if (_tmuxConfPath != null) return _tmuxConfPath;
    try {
      final content = await rootBundle.loadString('assets/clide.tmux.conf');
      final dir = Directory(
        '${Platform.environment['HOME'] ?? '/tmp'}/.config/clide',
      );
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/tmux.conf');
      file.writeAsStringSync(content);
      _tmuxConfPath = file.path;
      return _tmuxConfPath;
    } catch (_) {
      return null;
    }
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

    _sessionName = widget.isPrimary ? primarySessionName(repoRoot) : secondarySessionName(repoRoot, widget.secondaryIndex!);
    // Bind this pane to a specific Claude session id so concurrent
    // sessions in one workspace don't collide on the newest transcript
    // (T-146). Primary: deterministic → resumes across restarts.
    // Secondary: fresh → always a clean session.
    _sessionId ??= widget.isPrimary ? primarySessionId(repoRoot) : freshSessionId();

    final tmuxConf = await _ensureTmuxConf();
    const cols = _cols;
    const rows = _rows;

    var argv = <String>[
      'tmux',
      '-L',
      'clide',
      if (tmuxConf != null) ...['-f', tmuxConf],
      'new-session',
      '-A',
      '-s',
      _sessionName!,
      '-x',
      '$cols',
      '-y',
      '$rows',
      'claude',
      '--session-id',
      _sessionId!,
    ];

    // CLAUDE_CODE_NO_FLICKER=1 enables claude's fullscreen TUI mode:
    // input box pinned to the bottom of the alt-screen, claude owns
    // its own scrollback. Removes the need for tmux scroll forwarding.
    final env = {'CLAUDE_CODE_NO_FLICKER': '1'};

    var resp = await ipc.request('pane.spawn', args: {
      'argv': argv,
      'kind': PaneKind.claude.wire,
      'cwd': repoRoot,
      'cols': cols,
      'rows': rows,
      'title': _sessionName,
      'env': env,
    });

    if (!resp.ok) {
      argv = ['claude', '--session-id', _sessionId!];
      resp = await ipc.request('pane.spawn', args: {
        'argv': argv,
        'kind': PaneKind.claude.wire,
        'cwd': repoRoot,
        'cols': cols,
        'rows': rows,
        'title': _sessionName,
        'env': env,
      });
      if (!resp.ok) {
        setState(() => _error = resp.error?.message ?? 'spawn failed');
        return;
      }
      _usingTmux = false;
      setState(() => _statusLine = 'no-tmux · fresh every launch');
    } else {
      _usingTmux = true;
      setState(() => _statusLine = 'tmux · $_sessionName');
    }

    if (!mounted) return;
    _paneId = resp.data['id'] as String?;
    // Render the conversation natively from the transcript (T-137/D-75)
    // rather than the PTY's TUI output. claude runs in tmux; a reader
    // tails its transcript JSONL and a publisher fans the items onto the
    // kernel MessageBus, which the view's controller subscribes to. The
    // subscription is wired before the reader's first poll so the initial
    // tail is never missed.
    // Tail this session's own transcript (<munged-cwd>/<sessionId>.jsonl),
    // not just the newest in the workspace — that's what kept secondaries
    // showing the primary's conversation (T-146). Each pane gets its own
    // bus channel so their controllers don't cross-talk.
    final messages = _kernel()!.messages;
    final home = Platform.environment['HOME'] ?? '';
    final transcriptFile = '$home/.claude/projects/${repoRoot.replaceAll('/', '-')}/$_sessionId.jsonl';
    final channel = ClaudeConversation.sessionChannel(_sessionId!);
    _feed = TranscriptPublisher(
      messages: messages,
      reader: TranscriptReader(repoRoot, file: transcriptFile),
      channel: channel,
    );
    _conversation = ConversationController.fromBus(messages: messages, channel: channel);
    _subscribe();
    setState(() {});
  }

  // Send composed text to Claude. On the tmux path, submit via the tmux
  // server (paste-buffer + Enter) — it reaches Claude even with no client
  // attached, unlike pane.write to the (now-detached) spawned client PTY.
  // The no-tmux fallback runs claude directly in our PTY, where pane.write
  // does reach it.
  void _send(String text) {
    if (_usingTmux) {
      final session = _sessionName;
      if (session != null) unawaited(tmux.sendMessage(session, text));
      return;
    }
    final id = _paneId;
    final ipc = _ipc();
    if (id == null || ipc == null) return;
    unawaited(ipc.request('pane.write', args: {'id': id, 'text': encodeClaudeInput(text)}));
  }

  void _subscribe() {
    final kernel = _kernel();
    if (kernel == null) return;
    // Lifecycle only — content comes from the transcript, not pane.output.
    _eventSub = kernel.events.on<DaemonEvent>().listen((e) {
      if (e.subsystem != 'pane' || e.data['id'] != _paneId) return;
      switch (e.kind) {
        case 'pane.exit':
          setState(() => _statusLine = widget.isPrimary ? 'session exited — restart clide to retry' : 'session exited');
        case 'pane.closed':
          _paneId = null;
      }
    });
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

    final Widget body;
    if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: ClideText(_error!, muted: true),
      );
    } else if (_conversation != null) {
      body = Column(
        children: [
          Expanded(child: ConversationView(controller: _conversation!)),
          ClaudeComposer(
            enabled: _paneId != null,
            onSubmit: _send,
            pasteResolver: () => resolveClipboardAttachment(const NativeClipboard()),
          ),
        ],
      );
    } else {
      body = const Center(child: ClideText('attaching…', muted: true));
    }

    if (!widget.showChrome) return body;

    return ClidePaneChrome(
      title: title,
      subtitle: _error ?? _statusLine,
      onClose: widget.isPrimary
          ? null
          : () {
              final id = _paneId;
              if (id != null) {
                unawaited(_ipc()?.request('pane.close', args: {'id': id}));
              }
            },
      child: body,
    );
  }
}
