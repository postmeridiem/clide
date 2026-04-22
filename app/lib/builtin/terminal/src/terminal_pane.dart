import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clide/clide.dart';
import 'package:clide_app/kernel/kernel.dart';
import 'package:clide_app/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/xterm.dart';

/// General-purpose terminal pane. Spawns the user's `$SHELL` under the
/// daemon's PTY (via `pane.spawn`), feeds the `pane.output` event
/// stream into an xterm.dart Terminal, and routes user input back
/// through `pane.write`.
///
/// Deliberately knows nothing about Claude — that's `builtin.claude`'s
/// job. The shared widget layer (ClidePtyView, ClidePaneChrome) keeps
/// the two extensions visually consistent without coupling them.
class TerminalPane extends StatefulWidget {
  const TerminalPane({super.key});

  @override
  State<TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<TerminalPane> {
  static const _maxLines = 2000;

  late final Terminal _terminal;
  StreamSubscription<DaemonEvent>? _eventSub;
  String? _paneId;
  String? _error;
  int _pid = 0;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: _maxLines);
    // Route user input back through IPC once a pane id is known.
    _terminal.onOutput = _onTerminalOutput;
    _terminal.onResize = _onTerminalResize;
    // Spawn asynchronously after the first build so we have access to
    // the kernel via InheritedWidget lookup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _spawn());
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
    final id = _paneId;
    _paneId = null;
    if (id != null) {
      // Fire-and-forget. Daemon-side pane.close is idempotent.
      unawaited(_kernelIpc()?.request('pane.close', args: {'id': id}));
    }
    super.dispose();
  }

  Future<void> _spawn() async {
    if (!mounted) return;
    final ipc = _kernelIpc();
    if (ipc == null || !ipc.isConnected) {
      setState(() => _error = 'Daemon not connected. Start `clide --daemon`.');
      return;
    }

    final shell = Platform.environment['SHELL'] ?? '/bin/bash';
    final cwd = Directory.current.path;

    final response = await ipc.request('pane.spawn', args: {
      'argv': [shell, '-l'],
      'kind': PaneKind.terminal.wire,
      'cwd': cwd,
      'cols': _terminal.viewWidth,
      'rows': _terminal.viewHeight,
    });
    if (!mounted) return;
    if (!response.ok) {
      setState(() => _error = response.error?.message ?? 'spawn failed');
      return;
    }

    _paneId = response.data['id'] as String?;
    _pid = (response.data['pid'] as num?)?.toInt() ?? 0;
    _subscribeToPaneEvents();
    setState(() {}); // refresh subtitle with PID
  }

  void _subscribeToPaneEvents() {
    final kernel = _kernel();
    if (kernel == null) return;
    _eventSub = kernel.events.on<DaemonEvent>().listen((event) {
      if (event.subsystem != 'pane') return;
      if (event.data['id'] != _paneId) return;
      switch (event.kind) {
        case 'pane.output':
          final b64 = event.data['bytes_b64'];
          if (b64 is String) {
            final bytes = base64Decode(b64);
            _terminal.write(utf8.decode(bytes, allowMalformed: true));
          }
        case 'pane.exit':
          setState(() => _error = 'Shell exited.');
        case 'pane.closed':
          // Daemon-side gone; reset state so the user can retry.
          _paneId = null;
          setState(() {});
      }
    });
  }

  void _onTerminalOutput(String text) {
    final id = _paneId;
    if (id == null) return;
    _kernelIpc()?.request('pane.write', args: {'id': id, 'text': text});
  }

  void _onTerminalResize(int cols, int rows, int pixelWidth, int pixelHeight) {
    final id = _paneId;
    if (id == null) return;
    _kernelIpc()?.request('pane.resize', args: {
      'id': id,
      'cols': cols,
      'rows': rows,
    });
  }

  DaemonClient? _kernelIpc() => _kernel()?.ipc;

  KernelServices? _kernel() {
    try {
      return ClideKernel.of(context);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _error != null
        ? _error!
        : (_paneId == null ? 'spawning shell…' : 'pid $_pid · ${_paneId!}');

    return ClidePaneChrome(
      title: 'terminal',
      subtitle: subtitle,
      child: _error != null
          ? _ErrorBody(message: _error!)
          : ClidePtyView(
              terminal: _terminal,
              label: 'terminal — $subtitle',
            ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ClideText('Terminal unavailable'),
            const SizedBox(height: 4),
            ClideText(message, muted: true),
          ],
        ),
      ),
    );
  }
}

/// Cast the Uint8List base64 source to a typed form consumers can
/// inspect in tests. Exposed via the library's barrel only because it
/// helps the extension test probe the terminal state without pulling
/// in the xterm.dart model directly.
typedef TerminalBytes = Uint8List;
