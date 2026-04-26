/// Backend isolate entry point.
///
/// Boots the daemon dispatcher, toolchain, and all subprocess services.
/// Communicates with the main isolate via SendPort (responses + events)
/// and ReceivePort (incoming requests).
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
import 'package:clide/src/daemon/files_commands.dart' show FilesService;
import 'package:clide/src/git/client.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/panes/event_sink.dart';
import 'package:clide/src/panes/registry.dart';
import 'package:clide/src/pql/client.dart';

/// Message sent from main isolate to bootstrap the backend.
class BackendBootMessage {
  const BackendBootMessage({
    required this.frontendPort,
    required this.workspaceRoot,
  });
  final SendPort frontendPort;
  final String workspaceRoot;
}

/// Top-level entry point for the backend isolate.
void backendEntry(BackendBootMessage boot) {
  final frontendPort = boot.frontendPort;
  final workspaceRoot = boot.workspaceRoot;

  // Set up the receive port for incoming requests from the frontend.
  final requestPort = ReceivePort();

  // Resolve toolchain (file I/O — safe here, not on UI thread).
  final toolchain = Toolchain();
  toolchain.applyResolved(resolveToolchainPaths(workspaceRoot));

  // Boot the dispatcher and all services.
  final dispatcher = DaemonDispatcher();
  final eventSink = _IsolateEventSink(frontendPort);
  final workDir = Directory(workspaceRoot);

  final filesService = FilesService(root: workDir, events: eventSink);
  registerFilesCommands(dispatcher, filesService);

  final editorRegistry = EditorRegistry(events: eventSink, workspaceRoot: workDir);
  registerEditorCommands(dispatcher, editorRegistry);

  final gitClient = GitClient(toolchain: toolchain, workDir: workDir);
  registerGitCommands(dispatcher, gitClient, eventSink);

  final pql = PqlClient(workDir: workDir, toolchain: toolchain);
  registerPqlCommands(dispatcher, pql);

  final paneRegistry = PaneRegistry(events: eventSink);
  registerPaneCommands(dispatcher, paneRegistry, toolchain: toolchain);

  // Listen for requests from the frontend.
  requestPort.listen((message) async {
    if (message is Map<String, Object?>) {
      final req = IpcRequest.fromJson(message);
      final resp = await dispatcher.dispatch(req);
      frontendPort.send(resp.toJson());
    }
  });

  // Tell the frontend we're ready, and give it our request port.
  frontendPort.send({
    'type': 'ready',
    'requestPort': requestPort.sendPort,
    'toolchain': {
      'git': toolchain.git,
      'pql': toolchain.pql,
      'tmux': toolchain.tmux,
      'ptyc': toolchain.ptyc,
      'shell': toolchain.shell,
      'gitEnv': toolchain.gitEnv,
      'missing': toolchain.missing,
    },
  });
}

/// Sends IPC events to the frontend via SendPort.
class _IsolateEventSink implements DaemonEventSink {
  _IsolateEventSink(this._port);
  final SendPort _port;

  @override
  void emit(IpcEvent event) {
    _port.send(event.toJson());
  }
}
