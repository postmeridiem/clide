/// Backend isolate entry point.
///
/// Two-phase boot:
///   1. Resolve toolchain (find binaries) → report ready.
///   2. On `project.open` message → initialize services for the project.
///
/// The dispatcher only registers command handlers after a project is
/// activated. IPC requests arriving before that get an error response.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:clide/kernel/src/toolchain.dart';
import 'package:clide/src/daemon/dispatcher.dart';
import 'package:clide/src/daemon/editor_commands.dart';
import 'package:clide/src/daemon/files_commands.dart';
import 'package:clide/src/daemon/git_commands.dart';
import 'package:clide/src/daemon/pane_commands.dart';
import 'package:clide/src/daemon/pql_commands.dart';
import 'package:clide/src/editor/registry.dart' show EditorRegistry;
import 'package:clide/src/git/client.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';
import 'package:clide/src/panes/event_sink.dart';
import 'package:clide/src/panes/registry.dart';
import 'package:clide/src/pql/client.dart';

/// Message sent from main isolate to bootstrap the backend.
class BackendBootMessage {
  const BackendBootMessage({required this.frontendPort, this.hintRoot});
  final SendPort frontendPort;

  /// Optional path hint for initial toolchain resolution (e.g. CLIDE_PROJECT).
  /// Used to find project-local binaries like dugite before a project opens.
  final String? hintRoot;
}

/// Top-level entry point for the backend isolate.
void backendEntry(BackendBootMessage boot) {
  final frontendPort = boot.frontendPort;
  final requestPort = ReceivePort();
  final eventSink = _IsolateEventSink(frontendPort);
  final dispatcher = DaemonDispatcher();
  late Toolchain toolchain;

  // Phase 1: resolve toolchain — just find binaries, don't init services.
  // We need a project root for ptyc/dugite paths. Use a sensible
  // default; the real project comes from project.open.
  final resolveRoot = boot.hintRoot ?? Platform.environment['HOME'] ?? '/tmp';
  toolchain = Toolchain();
  toolchain.applyResolved(resolveToolchainPaths(resolveRoot));

  // Listen for messages from the frontend.
  requestPort.listen((message) async {
    if (message is! Map<String, Object?>) return;
    final type = message['type'] as String?;

    if (type == 'project.validate') {
      // Validate a path as a git repo. Runs git rev-parse in the backend
      // isolate (safe from the merged thread). Returns the repo root or null.
      final path = message['path'] as String;
      final id = message['id'] as String;
      try {
        final r = await Process.run(toolchain.git, ['rev-parse', '--show-toplevel'], workingDirectory: path, environment: toolchain.gitEnv);
        if (r.exitCode == 0) {
          final root = (r.stdout as String).trim();
          frontendPort.send({'type': 'project.validated', 'id': id, 'root': root});
        } else {
          frontendPort.send({'type': 'project.validated', 'id': id, 'root': null});
        }
      } catch (_) {
        frontendPort.send({'type': 'project.validated', 'id': id, 'root': null});
      }
    } else if (type == 'project.open') {
      // Phase 2: (re)initialize services for the given project.
      final projectPath = message['path'] as String;
      final workDir = Directory(projectPath);

      // Re-resolve toolchain with the actual project root (finds
      // dugite in native/dugite/, ptyc in ptyc/bin/, etc.)
      toolchain = Toolchain();
      toolchain.applyResolved(resolveToolchainPaths(projectPath));

      // Clear existing handlers and re-register with new project.
      dispatcher.clear();

      final filesService = FilesService(root: workDir, events: eventSink);
      registerFilesCommands(dispatcher, filesService);

      final editorRegistry = EditorRegistry(events: eventSink, workspaceRoot: workDir);
      registerEditorCommands(dispatcher, editorRegistry);

      final gitClient = GitClient(toolchain: toolchain, workDir: workDir);
      registerGitCommands(dispatcher, gitClient, eventSink);

      final pql = PqlClient(workDir: workDir, toolchain: toolchain);
      registerPqlCommands(dispatcher, pql);

      final paneRegistry = PaneRegistry(events: eventSink);
      registerPaneCommands(dispatcher, paneRegistry);

      // Tell the frontend the project is active.
      frontendPort.send({
        'type': 'project.ready',
        'path': projectPath,
        'toolchain': _serializeToolchain(toolchain),
      });
    } else {
      // IPC request — dispatch if we have handlers.
      final req = IpcRequest.fromJson(message);
      if (dispatcher.isEmpty) {
        frontendPort.send(IpcResponse.err(
          id: req.id,
          error: IpcError(
            code: IpcExitCode.toolError,
            kind: IpcErrorKind.toolError,
            message: 'No project active',
            hint: 'Open a project first',
          ),
        ).toJson());
      } else {
        final resp = await dispatcher.dispatch(req);
        frontendPort.send(resp.toJson());
      }
    }
  });

  // Send ready with toolchain state and request port.
  frontendPort.send({
    'type': 'ready',
    'requestPort': requestPort.sendPort,
    'toolchain': _serializeToolchain(toolchain),
  });
}

Map<String, Object?> _serializeToolchain(Toolchain tc) => {
      'git': tc.git,
      'pql': tc.pql,
      'tmux': tc.tmux,
      'ptyc': tc.ptyc,
      'shell': tc.shell,
      'gitEnv': tc.gitEnv,
      'missing': tc.missing,
    };

/// Sends IPC events to the frontend via SendPort.
class _IsolateEventSink implements DaemonEventSink {
  _IsolateEventSink(this._port);
  final SendPort _port;

  @override
  void emit(IpcEvent event) {
    _port.send(event.toJson());
  }
}
