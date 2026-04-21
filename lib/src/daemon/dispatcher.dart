import 'package:clide/clide.dart' show clideVersion;
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';

typedef CommandHandler = Future<IpcResponse> Function(IpcRequest req);

class DaemonDispatcher {
  DaemonDispatcher() {
    register('ping', _ping);
    register('version', _version);
  }

  final Map<String, CommandHandler> _handlers = {};

  void register(String cmd, CommandHandler handler) {
    _handlers[cmd] = handler;
  }

  Future<IpcResponse> dispatch(IpcRequest req) async {
    final h = _handlers[req.cmd];
    if (h == null) {
      return IpcResponse.err(
        id: req.id,
        error: IpcError(
          code: IpcExitCode.notFound,
          kind: IpcErrorKind.notFound,
          message: 'unknown command: ${req.cmd}',
          hint: 'run `clide --help` for the surface.',
        ),
      );
    }
    return h(req);
  }

  Future<IpcResponse> _ping(IpcRequest req) async => IpcResponse.ok(
        id: req.id,
        data: {
          'pong': true,
          'ts': DateTime.now().toUtc().toIso8601String(),
          'version': clideVersion,
        },
      );

  Future<IpcResponse> _version(IpcRequest req) async => IpcResponse.ok(
        id: req.id,
        data: {'version': clideVersion},
      );
}
