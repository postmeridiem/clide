// clide — CLI + daemon entry point.
//
// One binary, two modes (per D-005):
//   * `clide <subcommand>` — one-shot; connects to the daemon socket,
//      sends a request, prints the response, exits with the D-006
//      exit code.
//   * `clide --daemon` — long-running; owns the socket, dispatches
//      requests. Subsystems (pane, files, editor, …) register handlers
//      at boot.

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

  // Tier-2 single-word shortcuts (per CLAUDE.md). Each maps a flat
  // positional argv into the structured IPC shape of the canonical
  // editor.* / pane.* verb. Keeps Claude's tool-use pattern short.
  final rest = argv.sublist(1);
  switch (argv.first) {
    case '--version':
    case 'version':
      await _runCliArgs('version', const {}, exitOnOk: true);
    case '--help':
    case '-h':
    case 'help':
      _printHelp(stdout);
      exit(0);
    case 'ping':
      await _runCliArgs('ping', const {}, exitOnOk: true);
    case 'open':
      if (rest.isEmpty) _die('usage: clide open <path>');
      await _runCliArgs('editor.open', {'path': rest.first}, exitOnOk: true);
    case 'active':
      await _runCliArgs('editor.active', const {}, exitOnOk: true);
    case 'insert':
      final text = await _readTextArg(rest);
      await _runCliArgs('editor.insert', {'text': text}, exitOnOk: true);
    case 'replace-selection':
      final text = await _readTextArg(rest);
      await _runCliArgs(
        'editor.replace-selection',
        {'text': text},
        exitOnOk: true,
      );
    case 'save':
      await _runCliArgs('editor.save', const {}, exitOnOk: true);
    case 'tail':
      await _runTail(rest);
    default:
      // Unknown-to-the-CLI commands still go over IPC — the daemon is
      // authoritative about what's registered. Lets extensions add
      // subcommands without the CLI caring. Args forward as-is under
      // {argv: [...]} so daemon-side can parse whatever shape it wants.
      await _runCliArgs(
        argv.first,
        {'argv': rest},
        exitOnOk: true,
      );
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

Editor (tier 2):
  open <path>             Open a file in the editor (editor.open).
  active                  Print the active buffer (editor.active).
  insert <text|->         Insert text at the cursor in the active buffer.
                          `-` reads text from stdin.
  replace-selection <…>   Replace the selected text in the active buffer.
                          `-` reads text from stdin.
  save                    Save the active buffer (editor.save).

Event subscription:
  tail --events [--filter SUBSYSTEM[:ID]]
                          Stream events as JSON lines. --filter keeps
                          only events from one subsystem, optionally
                          narrowed to a single id. Exits on SIGINT.

Any other subcommand is forwarded to the daemon; registered handlers
(e.g. `clide git status` once `builtin.git` lands) resolve there.
Matches D-006's exit-code contract:
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

// ---------------------------------------------------------------------------
// CLI helpers
// ---------------------------------------------------------------------------

/// Read the "text" argument for insert / replace-selection. A lone
/// `-` means "slurp stdin"; anything else is concatenated into the
/// text body (so `clide insert hello world` emits "hello world").
Future<String> _readTextArg(List<String> rest) async {
  if (rest.isEmpty) _die('usage: clide <verb> <text>  (or `-` to read stdin)');
  if (rest.length == 1 && rest.first == '-') {
    final bytes = <int>[];
    await for (final chunk in stdin) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }
  return rest.join(' ');
}

Future<Socket> _connectSocket() async {
  final socketPath = defaultSocketPath();
  try {
    return await Socket.connect(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );
  } catch (_) {
    _emitError(
      code: IpcExitCode.toolError,
      kind: IpcErrorKind.toolError,
      message: 'daemon not reachable at $socketPath',
      hint: 'run `clide --daemon` in another terminal.',
    );
    exit(IpcExitCode.toolError);
  }
}

Future<void> _runCliArgs(
  String cmd,
  Map<String, Object?> args, {
  required bool exitOnOk,
}) async {
  final socket = await _connectSocket();
  final request = IpcRequest(id: '1', cmd: cmd, args: args);
  socket.writeln(request.encode());

  // Responses come back on the same socket. Events may be interleaved
  // (the daemon broadcasts), so we skip events until we see the
  // response whose id matches our request.
  final lines = socket
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  try {
    await for (final line in lines) {
      if (line.isEmpty) continue;
      final msg = IpcMessage.decode(line);
      if (msg is! IpcResponse) continue;
      if (msg.id != request.id) continue;
      await socket.close();
      if (msg.ok) {
        stdout.writeln(jsonEncode(msg.data));
        if (exitOnOk) exit(IpcExitCode.ok);
        return;
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
    }
    _emitError(
      code: IpcExitCode.toolError,
      kind: IpcErrorKind.toolError,
      message: 'daemon closed socket before responding',
    );
    exit(IpcExitCode.toolError);
  } on FormatException catch (e) {
    _emitError(
      code: IpcExitCode.toolError,
      kind: IpcErrorKind.toolError,
      message: 'bad response from daemon: $e',
    );
    exit(IpcExitCode.toolError);
  }
}

/// `clide tail --events [--filter SUBSYSTEM[:ID]]` — stream events.
Future<void> _runTail(List<String> args) async {
  // Parse flags: --events (required today; keeps us honest when more
  // modes like --history land), --filter SUBSYSTEM[:ID].
  var wantEvents = false;
  String? filterSubsystem;
  String? filterId;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--events') {
      wantEvents = true;
    } else if (a == '--filter') {
      if (i + 1 >= args.length) _die('--filter requires an argument');
      final spec = args[++i];
      final colon = spec.indexOf(':');
      if (colon < 0) {
        filterSubsystem = spec;
      } else {
        filterSubsystem = spec.substring(0, colon);
        filterId = spec.substring(colon + 1);
      }
    } else {
      _die('unknown argument: $a');
    }
  }
  if (!wantEvents) _die('clide tail: pass --events');

  final socket = await _connectSocket();

  // Shutdown on SIGINT / SIGTERM — close the socket so the stream
  // drains and we exit cleanly.
  void quit() {
    unawaited(socket.close());
  }
  ProcessSignal.sigint.watch().listen((_) => quit());
  ProcessSignal.sigterm.watch().listen((_) => quit());

  final lines = socket
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  try {
    await for (final line in lines) {
      if (line.isEmpty) continue;
      IpcMessage msg;
      try {
        msg = IpcMessage.decode(line);
      } on FormatException {
        continue;
      }
      if (msg is! IpcEvent) continue;
      if (filterSubsystem != null && msg.subsystem != filterSubsystem) continue;
      if (filterId != null && msg.data['id'] != filterId) continue;
      stdout.writeln(line);
    }
  } finally {
    await socket.close();
  }
  exit(0);
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

Never _die(String msg) {
  _emitError(
    code: IpcExitCode.userError,
    kind: IpcErrorKind.userError,
    message: msg,
  );
  exit(IpcExitCode.userError);
}
