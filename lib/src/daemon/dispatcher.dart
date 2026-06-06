import 'package:clide/clide.dart' show clideVersion;
import 'package:clide/src/ipc/command_schema.dart';
import 'package:clide/src/ipc/envelope.dart';
import 'package:clide/src/ipc/schema_v1.dart';

typedef CommandHandler = Future<IpcResponse> Function(IpcRequest req);

class DaemonDispatcher {
  DaemonDispatcher() {
    register('ping', _ping);
    register('version', _version);
    register('capabilities', _capabilities);
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

  /// Built-in commands registered in the constructor; survive [clear] and
  /// don't count toward [isEmpty].
  static const _builtins = {'ping', 'version', 'capabilities'};

  /// Remove all registered handlers except the built-ins.
  void clear() {
    _handlers.removeWhere((k, _) => !_builtins.contains(k));
    _schemas.removeWhere((k, _) => !_builtins.contains(k));
  }

  bool get isEmpty => _handlers.length <= _builtins.length;

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

  /// Reflects the live command registry so the surface is discoverable, not
  /// just present (T-248). Every registered verb is listed — split into
  /// subsystem + verb — with its argument schema (positional order + per-arg
  /// type/required/constraints) where one is declared. Sourced from the
  /// registry, so it never drifts from what actually dispatches.
  Future<IpcResponse> _capabilities(IpcRequest req) async {
    final names = _handlers.keys.toList()..sort();
    final commands = <String, Object?>{};
    for (final cmd in names) {
      final dot = cmd.indexOf('.');
      final schema = _schemas[cmd];
      commands[cmd] = {
        'subsystem': dot >= 0 ? cmd.substring(0, dot) : '',
        'verb': dot >= 0 ? cmd.substring(dot + 1) : cmd,
        if (schema != null) 'positional': schema.positional,
        if (schema != null) 'args': {for (final e in schema.args.entries) e.key: _argSpecJson(e.value)},
      };
    }
    return IpcResponse.ok(id: req.id, data: {'version': clideVersion, 'commands': commands});
  }

  static Map<String, Object?> _argSpecJson(ArgSpec s) => {
        'type': s.type.name,
        if (s.required) 'required': true,
        if (s.allowed != null) 'allowed': (s.allowed!.toList()..sort()),
        if (s.pattern != null) 'pattern': s.pattern!.pattern,
        if (s.min != null) 'min': s.min,
        if (s.max != null) 'max': s.max,
        if (s.maxItems != null) 'maxItems': s.maxItems,
        if (s.rejectLeadingDash) 'rejectLeadingDash': true,
      };
}
