/// Manages the backend isolate lifecycle.
///
/// Two-phase boot:
///   1. [Backend.spawn] — starts the isolate, resolves toolchain (binary checks only).
///   2. [Backend.openProject] — initializes services for a specific project root.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:clide/kernel/src/backend_entry.dart';
import 'package:clide/kernel/src/ipc/isolate_client.dart';
import 'package:clide/kernel/src/toolchain.dart';

class Backend {
  Backend._({
    required this.client,
    required this.toolchain,
    required SendPort backendRequestPort,
    required Isolate isolate,
    required ReceivePort receivePort,
  })  : _backendRequestPort = backendRequestPort,
        _isolate = isolate,
        _receivePort = receivePort;

  final IsolateClient client;
  final Toolchain toolchain;
  final SendPort _backendRequestPort;
  final Isolate _isolate;
  final ReceivePort _receivePort;

  Completer<void>? _projectCompleter;
  final Map<String, Completer<String?>> _validateCompleters = {};
  int _validateId = 0;

  /// Spawn the backend isolate. Returns when the toolchain is resolved.
  /// No services are active yet — call [openProject] to activate.
  static Future<Backend> spawn({
    required IsolateClient Function(SendPort backendPort) clientFactory,
    String? hintRoot,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<Backend>();

    late final IsolateClient client;
    late final Isolate isolate;
    late final SendPort backendRequestPort;
    late final Backend backend;

    receivePort.listen((message) {
      if (message is Map<String, Object?>) {
        final type = message['type'] as String?;
        if (type == 'ready') {
          backendRequestPort = message['requestPort'] as SendPort;
          client = clientFactory(backendRequestPort);

          final tcData = message['toolchain'] as Map<String, Object?>;
          final toolchain = Toolchain();
          toolchain.applyResolved(ResolvedPaths(
            git: tcData['git'] as String?,
            pql: tcData['pql'] as String?,
            tmux: tcData['tmux'] as String?,
            ptyc: tcData['ptyc'] as String?,
            shell: tcData['shell'] as String?,
            gitEnv: (tcData['gitEnv'] as Map?)?.cast<String, String>(),
          ));

          backend = Backend._(
            client: client,
            toolchain: toolchain,
            backendRequestPort: backendRequestPort,
            isolate: isolate,
            receivePort: receivePort,
          );

          if (!completer.isCompleted) completer.complete(backend);
        } else if (type == 'project.validated') {
          final id = message['id'] as String;
          final root = message['root'] as String?;
          final c = backend._validateCompleters.remove(id);
          if (c != null && !c.isCompleted) c.complete(root);
        } else if (type == 'project.ready') {
          // Update toolchain with project-specific paths.
          final tcData = message['toolchain'] as Map<String, Object?>;
          backend.toolchain.applyResolved(ResolvedPaths(
            git: tcData['git'] as String?,
            pql: tcData['pql'] as String?,
            tmux: tcData['tmux'] as String?,
            ptyc: tcData['ptyc'] as String?,
            shell: tcData['shell'] as String?,
            gitEnv: (tcData['gitEnv'] as Map?)?.cast<String, String>(),
          ));
          backend._projectCompleter?.complete();
          backend._projectCompleter = null;
        } else {
          // Response or event — forward to the client.
          client.handleMessage(message);
        }
      }
    });

    isolate = await Isolate.spawn(
      backendEntry,
      BackendBootMessage(frontendPort: receivePort.sendPort, hintRoot: hintRoot),
    );

    return completer.future;
  }

  /// Validate a path as a git repo. Returns the repo root or null.
  /// Runs git rev-parse in the backend isolate (no main-thread I/O).
  Future<String?> validateProject(String path) {
    final id = '${_validateId++}';
    final c = Completer<String?>();
    _validateCompleters[id] = c;
    _backendRequestPort.send({
      'type': 'project.validate',
      'path': path,
      'id': id,
    });
    return c.future;
  }

  /// Activate a project. The backend (re)initializes all services
  /// for the given root directory. Returns when services are ready.
  Future<void> openProject(String path) {
    _projectCompleter = Completer<void>();
    _backendRequestPort.send({
      'type': 'project.open',
      'path': path,
    });
    return _projectCompleter!.future;
  }

  /// Shut down the backend isolate.
  void dispose() {
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _receivePort.close();
  }
}
