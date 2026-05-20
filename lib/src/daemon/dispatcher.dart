import 'package:clide/clide.dart' show clideVersion;
import 'package:clide/src/ipc/command_schema.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';

typedef CommandHandler = Future<IpcResponse> Function(IpcRequest req);

class DaemonDispatcher {
  DaemonDispatcher() {
    register('ping', _ping);
    register('version', _version);
  }

  final Map<String, CommandHandler> _handlers = {};

  /// Per-command argument schemas (T-120 / D-74). Populated alongside
  /// handlers by registrants. A command with no entry dispatches
  /// unvalidated — schema adoption is opt-in per command.
  final Map<String, CommandSchema> _schemas = {};

  /// Register [handler] for [cmd]. Pass [schema] to have the dispatcher
  /// normalise + validate `req.args` before the handler runs (D-74).
  void register(String cmd, CommandHandler handler, {CommandSchema? schema}) {
    _handlers[cmd] = handler;
    if (schema != null) {
      _schemas[cmd] = schema;
    } else {
      _schemas.remove(cmd);
    }
  }

  /// Remove all registered handlers except ping/version.
  void clear() {
    _handlers.removeWhere((k, _) => k != 'ping' && k != 'version');
    _schemas.removeWhere((k, _) => k != 'ping' && k != 'version');
  }

  bool get isEmpty => _handlers.length <= 2; // only ping + version

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
    final schema = _schemas[req.cmd];
    if (schema == null) return h(req);
    final result = schema.validate(schema.normalize(req.args));
    if (!result.isOk) {
      return schemaError(req.id, result.error!);
    }
    return h(IpcRequest(id: req.id, cmd: req.cmd, args: result.values!));
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
