import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:clide/src/terminal/terminal.dart';

import 'session_naming.dart';
import 'tmux_session.dart' as tmux;

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
  static const _maxLines = 50000;
  static String? _tmuxConfPath;

  late final Terminal _terminal;
  StreamSubscription<DaemonEvent>? _eventSub;
  String? _paneId;
  String? _sessionName;
  String? _error;
  String _statusLine = 'attaching…';

  bool _spawned = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: _maxLines);
    _terminal.onOutput = _onTerminalOutput;
    _terminal.onResize = _onTerminalResize;
    // Don't spawn here — wait for the first onResize from TerminalView
    // so the PTY gets real dimensions, not 80x24 defaults.
  }

  @override
  void dispose() {
    _resizeTimer?.cancel();
    _flushTimer?.cancel();
    _eventSub?.cancel();
    _eventSub = null;
    final id = _paneId;
    final sessionName = _sessionName;
    _paneId = null;
    // Secondary panes own their tmux session — close on dispose.
    // Primary panes leave the tmux session alive so the next launch
    // re-attaches via `tmux new-session -A` (D-41).
    //
    // pane.close kills the ptyc-spawned tmux *client*; the tmux server
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

    _sessionName = widget.isPrimary
        ? primarySessionName(repoRoot)
        : secondarySessionName(repoRoot, widget.secondaryIndex!);

    final tmuxConf = await _ensureTmuxConf();
    final cols = _terminal.viewWidth;
    final rows = _terminal.viewHeight;

    var argv = <String>[
      'tmux',
      '-L', 'clide',
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
      argv = ['claude'];
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
      setState(() => _statusLine = 'no-tmux · fresh every launch');
    } else {
      setState(() => _statusLine = 'tmux · $_sessionName');
    }

    if (!mounted) return;
    _paneId = resp.data['id'] as String?;
    _subscribe();
    setState(() {});
  }

  // -- output batching ------------------------------------------------------

  final _outputBuf = StringBuffer();
  Timer? _flushTimer;

  void _flushOutput() {
    _flushTimer = null;
    if (_outputBuf.isEmpty) return;
    _terminal.write(_outputBuf.toString());
    _outputBuf.clear();
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
            _outputBuf.write(utf8.decode(base64Decode(b64), allowMalformed: true));
            if (_flushTimer == null) {
              _flushTimer = Timer(Duration.zero, _flushOutput);
            }
          }
        case 'pane.exit':
          setState(() => _statusLine = widget.isPrimary
              ? 'session exited — restart clide to retry'
              : 'session exited');
        case 'pane.closed':
          _paneId = null;
      }
    });
  }

  // -- terminal callbacks ---------------------------------------------------

  void _onTerminalOutput(String text) {
    final id = _paneId;
    if (id == null) return;
    _ipc()?.request('pane.write', args: {'id': id, 'text': text});
  }

  Timer? _resizeTimer;

  void _onTerminalResize(int cols, int rows, int _, int __) {
    if (!_spawned) {
      _spawned = true;
      _spawnWhenReady();
      return;
    }
    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 150), () {
      final id = _paneId;
      if (id == null) return;
      _ipc()?.request('pane.resize', args: {'id': id, 'cols': cols, 'rows': rows});
      if (_sessionName != null) {
        Process.run('tmux', [
          '-L', 'clide', 'resize-window',
          '-t', _sessionName!,
          '-x', '$cols',
          '-y', '$rows',
        ]);
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
    final title = widget.isPrimary
        ? 'claude — primary'
        : 'claude — secondary ${widget.secondaryIndex}';

    final body = _error != null
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: ClideText(_error!, muted: true),
          )
        : ClidePtyView(terminal: _terminal, label: title, autofocus: true);

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
