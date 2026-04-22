// clide — CLI + daemon entry point.
//
// One binary, two modes (per ADR 0005):
//   * `clide <subcommand>` — one-shot; connects to the daemon socket,
//      sends a request, prints the response, exits with the ADR-0006
//      exit code.
//   * `clide --daemon` — long-running; owns the socket, dispatches
//      requests. Tier 0 ships `ping` and `version`; feature subsystems
//      (pane, git, pql, etc.) register handlers as they land.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/clide.dart';
// Daemon-only deep imports — these pull in dart:ffi (PTY) and
// daemon-subsystem wiring that the Flutter app doesn't need and
// can't compile for web. See lib/clide.dart for the barrel split.
import 'package:clide/src/daemon/editor_commands.dart';
import 'package:clide/src/daemon/files_commands.dart';
import 'package:clide/src/daemon/pane_commands.dart';
import 'package:clide/src/editor/registry.dart' show EditorRegistry;
import 'package:clide/src/panes/registry.dart';

Future<void> main(List<String> argv) async {
  if (argv.isEmpty) {
    _printHelp(stdout);
    exit(0);
  }

  if (argv.first == '--daemon') {
    await _runDaemon(argv.sublist(1));
    return;
  }

  switch (argv.first) {
    case '--version':
    case 'version':
      await _runCli('version', const [], exitOnOk: true);
    case '--help':
    case '-h':
    case 'help':
      _printHelp(stdout);
      exit(0);
    case 'ping':
      await _runCli('ping', argv.sublist(1), exitOnOk: true);
    default:
      // Unknown-to-the-CLI commands still go over IPC — the daemon is
      // authoritative about what's registered. Lets extensions add
      // subcommands without the CLI caring.
      await _runCli(argv.first, argv.sublist(1), exitOnOk: true);
  }
}

void _printHelp(IOSink sink) {
  sink.writeln('''
clide $clideVersion — Flutter desktop IDE for Claude Code.

Usage:
  clide --daemon          Run the long-running daemon process.
  clide <subcommand>      Run a one-shot subcommand against the daemon.

Built-in subcommands:
  ping                    Round-trip a ping to the daemon.
  version                 Print the clide version.
  help                    Print this help.

Any other subcommand is forwarded to the daemon; registered handlers
(e.g. `clide git status` once `builtin.git` lands) resolve there.
Matches ADR 0006's exit-code contract:
  0 success · 1 user-error · 2 tool-error · 3 not-found · 4 conflict
''');
}

Future<void> _runDaemon(List<String> args) async {
  final socketPath = defaultSocketPath();
  final dispatcher = DaemonDispatcher();
  late final DaemonServer server;
  server = DaemonServer(
    socketPath: socketPath,
    dispatch: dispatcher.dispatch,
  );
  final events = _ServerEventSink(server);
  final registry = PaneRegistry(events: events);
  registerPaneCommands(dispatcher, registry);

  final files = FilesService.atCwd(events: events);
  registerFilesCommands(dispatcher, files);

  final editor = EditorRegistry(events: events, workspaceRoot: files.root);
  registerEditorCommands(dispatcher, editor);

  final stopping = Completer<void>();
  void shutdown(ProcessSignal sig) {
    if (!stopping.isCompleted) {
      stderr.writeln('clide daemon: received ${sig.toString()}, shutting down');
      stopping.complete();
    }
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  ProcessSignal.sigterm.watch().listen(shutdown);

  await server.start();
  await stopping.future;
  await registry.shutdown();
  await editor.shutdown();
  await files.shutdown();
  await server.stop();
  exit(0);
}

/// Thin adapter: the server doesn't `implement DaemonEventSink` itself
/// (that would tie ipc/ to panes/); instead the daemon entrypoint wraps
/// it at the seam where both are known.
class _ServerEventSink implements DaemonEventSink {
  _ServerEventSink(this._server);
  final DaemonServer _server;

  @override
  void emit(IpcEvent event) => _server.broadcast(event);
}

Future<void> _runCli(
  String cmd,
  List<String> args, {
  required bool exitOnOk,
}) async {
  final socketPath = defaultSocketPath();
  Socket socket;
  try {
    socket = await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
  } catch (e) {
    _emitError(
      code: IpcExitCode.toolError,
      kind: IpcErrorKind.toolError,
      message: 'daemon not reachable at $socketPath',
      hint: 'run `clide --daemon` in another terminal.',
    );
    exit(IpcExitCode.toolError);
  }

  final request = IpcRequest(
    id: '1',
    cmd: cmd,
    args: {'argv': args},
  );
  socket.writeln(request.encode());

  final line = await socket
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .first;
  await socket.close();

  try {
    final msg = IpcMessage.decode(line);
    if (msg is! IpcResponse) {
      _emitError(
        code: IpcExitCode.toolError,
        kind: IpcErrorKind.toolError,
        message: 'unexpected message from daemon',
      );
      exit(IpcExitCode.toolError);
    }
    if (msg.ok) {
      stdout.writeln(jsonEncode(msg.data));
      if (exitOnOk) exit(IpcExitCode.ok);
    } else {
      final err = msg.error!;
      _emitError(
        code: err.code,
        kind: err.kind,
        message: err.message,
        hint: err.hint,
      );
      exit(err.code);
    }
  } on FormatException catch (e) {
    _emitError(
      code: IpcExitCode.toolError,
      kind: IpcErrorKind.toolError,
      message: 'bad response from daemon: $e',
    );
    exit(IpcExitCode.toolError);
  }
}

void _emitError({
  required int code,
  required String kind,
  required String message,
  String? hint,
}) {
  final err = IpcError(code: code, kind: kind, message: message, hint: hint);
  stderr.writeln(jsonEncode(err.toJson()));
}
