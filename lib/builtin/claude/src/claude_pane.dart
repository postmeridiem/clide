import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/xterm.dart';

import 'session_naming.dart';

/// Claude pane. Opinionated per D-041:
///
///   - [isPrimary]=true: the session name is stable per repo
///     (`clide-claude-<hash>`) so reopening the app re-attaches to a
///     running `claude` under tmux. No close button rendered —
///     close-gestures (tab × on the header) minimise, not kill.
///   - [isPrimary]=false: session name includes a `-N` suffix for
///     this clide run. Closes normally; `pane.close` kills the tmux
///     session.
///
/// Requires `tmux` on the daemon's PATH. If it isn't there, the pane
/// falls back to spawning `claude` directly and loses persistence —
/// an explicit state message lands in the header subtitle.
class ClaudePane extends StatefulWidget {
  const ClaudePane({
    super.key,
    this.isPrimary = true,
    this.secondaryIndex,
    this.showChrome = true,
  }) : assert(isPrimary || secondaryIndex != null,
            'secondary panes need an index');

  final bool isPrimary;
  final bool showChrome;

  /// 1-based secondary-session index. Ignored when [isPrimary].
  final int? secondaryIndex;

  @override
  State<ClaudePane> createState() => _ClaudePaneState();
}

class _ClaudePaneState extends State<ClaudePane> {
  static const _maxLines = 5000;

  late final Terminal _terminal;
  StreamSubscription<DaemonEvent>? _eventSub;
  String? _paneId;
  String? _error;
  String _statusLine = 'attaching…';

  @override
  bool _spawned = false;

  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: _maxLines);
    _terminal.onOutput = _onOutput;
    _terminal.onResize = _onResize;
    // Don't spawn here — wait for the first onResize from TerminalView
    // so the PTY gets real dimensions, not 80x24 defaults.
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    _eventSub?.cancel();
    _eventSub = null;
    final id = _paneId;
    _paneId = null;
    if (id != null && !widget.isPrimary) {
      // Secondary: killing the pane kills the tmux session too —
      // that's the D-041 policy ("closing a secondary pops back to
      // primary"). The daemon's pane.close is idempotent.
      unawaited(_ipc()?.request('pane.close', args: {'id': id}));
    }
    // Primary: don't close on dispose. The next time this pane is
    // rebuilt (next app launch, or tab reopen), tmux new-session -A
    // re-attaches to the same running claude.
    super.dispose();
  }

  Future<void> _spawnWhenReady() async {
    if (!mounted) return;
    final kernel = ClideKernel.of(context);
    if (!kernel.project.isOpen) {
      // Wait for a project to open before spawning.
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
      setState(() => _error = 'Daemon not connected. Start `clide --daemon`.');
      return;
    }

    // Resolve repo root via files.root. If that fails (no daemon, no
    // git root), fall back to cwd — the session name will just be
    // based on wherever the daemon is running.
    String repoRoot = Directory.current.path;
    final rootResp = await ipc.request('files.root');
    if (rootResp.ok) {
      repoRoot = (rootResp.data['path'] as String?) ?? repoRoot;
    }

    final sessionName = widget.isPrimary
        ? primarySessionName(repoRoot)
        : secondarySessionName(repoRoot, widget.secondaryIndex!);

    // Try tmux-wrapped first (persistence). Fall back to direct claude
    // if tmux spawn errors.
    var argv = <String>[
      'tmux',
      'new-session',
      '-A',
      '-s',
      sessionName,
      '--',
      'claude',
    ];
    var resp = await ipc.request('pane.spawn', args: {
      'argv': argv,
      'kind': PaneKind.claude.wire,
      'cwd': repoRoot,
      'cols': _terminal.viewWidth,
      'rows': _terminal.viewHeight,
      'title': sessionName,
    });

    if (!resp.ok) {
      // tmux probably missing — try bare claude so the pane still
      // works, at the cost of persistence.
      argv = ['claude'];
      resp = await ipc.request('pane.spawn', args: {
        'argv': argv,
        'kind': PaneKind.claude.wire,
        'cwd': repoRoot,
        'cols': _terminal.viewWidth,
        'rows': _terminal.viewHeight,
        'title': sessionName,
      });
      if (!resp.ok) {
        setState(() {
          _error = resp.error?.message ?? 'spawn failed';
        });
        return;
      }
      setState(() => _statusLine = 'no-tmux · fresh every launch');
    } else {
      setState(() => _statusLine = 'tmux · $sessionName');
    }

    if (!mounted) return;
    _paneId = resp.data['id'] as String?;
    // PID available in resp.data['pid'] if needed for debugging.
    _subscribe();
    setState(() {});
  }

  void _subscribe() {
    final kernel = _kernel();
    if (kernel == null) return;
    _eventSub = kernel.events.on<DaemonEvent>().listen((e) {
      if (e.subsystem != 'pane' || e.data['id'] != _paneId) return;
      switch (e.kind) {
        case 'pane.output':
          final b64 = e.data['bytes_b64'];
          if (b64 is String) {
            _terminal.write(utf8.decode(base64Decode(b64), allowMalformed: true));
          }
        case 'pane.exit':
          if (widget.isPrimary) {
            // Primary exiting is unusual — tmux sessions survive
            // normal disconnects. Surface it but don't auto-respawn;
            // the user decides.
            setState(() => _statusLine = 'session exited — restart clide to retry');
          } else {
            setState(() => _statusLine = 'session exited');
          }
        case 'pane.closed':
          _paneId = null;
      }
    });
  }

  void _onOutput(String text) {
    final id = _paneId;
    if (id == null) return;
    _ipc()?.request('pane.write', args: {'id': id, 'text': text});
  }

  Timer? _resizeTimer;

  void _onResize(int cols, int rows, int _, int __) {
    if (!_spawned) {
      // First resize — TerminalView has real dimensions now.
      _spawned = true;
      _spawnWhenReady();
      return;
    }
    // Debounce resize — rapid SIGWINCH during window drag corrupts
    // the terminal rendering. Wait for the resize to settle.
    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 150), () {
      final id = _paneId;
      if (id == null) return;
      _ipc()?.request('pane.resize', args: {'id': id, 'cols': cols, 'rows': rows});
    });
  }

  DaemonClient? _ipc() => _kernel()?.ipc;

  KernelServices? _kernel() {
    try {
      return ClideKernel.of(context);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isPrimary
        ? 'claude — primary'
        : 'claude — secondary ${widget.secondaryIndex}';
    final body = _error != null
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: ClideText(_error!, muted: true),
          )
        : ClidePtyView(terminal: _terminal, label: title);

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
