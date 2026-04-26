/// Manages the backend isolate lifecycle.
///
/// Call [spawn] to start the backend, which resolves the toolchain and
/// boots all daemon services in a separate isolate. Returns when the
/// backend is ready to accept requests.
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
    required Isolate isolate,
    required ReceivePort receivePort,
  })  : _isolate = isolate,
        _receivePort = receivePort;

  final IsolateClient client;
  final Toolchain toolchain;
  final Isolate _isolate;
  final ReceivePort _receivePort;

  /// Spawn the backend isolate and wait for it to be ready.
  static Future<Backend> spawn({
    required String workspaceRoot,
    required IsolateClient Function(SendPort backendPort) clientFactory,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<Backend>();

    late final IsolateClient client;
    late final Isolate isolate;

    receivePort.listen((message) {
      if (message is Map<String, Object?>) {
        final type = message['type'] as String?;
        if (type == 'ready') {
          // Backend is booted — extract its request port and toolchain state.
          final requestPort = message['requestPort'] as SendPort;
          client = clientFactory(requestPort);

          // Apply toolchain state from the backend.
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

          if (!completer.isCompleted) {
            completer.complete(Backend._(
              client: client,
              toolchain: toolchain,
              isolate: isolate,
              receivePort: receivePort,
            ));
          }
        } else {
          // Response or event — forward to the client.
          client.handleMessage(message);
        }
      }
    });

    isolate = await Isolate.spawn(
      backendEntry,
      BackendBootMessage(
        frontendPort: receivePort.sendPort,
        workspaceRoot: workspaceRoot,
      ),
    );

    return completer.future;
  }

  /// Shut down the backend isolate.
  void dispose() {
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _receivePort.close();
  }
}
