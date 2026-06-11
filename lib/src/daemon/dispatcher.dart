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

  /// Commands withheld from the generated MCP tool surface (D-86). A poor
  /// MCP fit — long-lived streams or strongly UI-side-effecting verbs —
  /// registers with `mcpExpose: false`. The CLI/palette surfaces are
  /// unaffected; only [mcpTools] skips these.
  final Set<String> _mcpHidden = {};

  /// Register [handler] for [cmd]. Pass [schema] to have the dispatcher
  /// normalise + validate `req.args` before the handler runs (D-74). Pass
  /// `mcpExpose: false` to keep the command off the MCP tool surface (D-86).
  void register(String cmd, CommandHandler handler, {CommandSchema? schema, bool mcpExpose = true}) {
    _handlers[cmd] = handler;
    if (schema != null) {
      _schemas[cmd] = schema;
    } else {
      _schemas.remove(cmd);
    }
    if (mcpExpose) {
      _mcpHidden.remove(cmd);
    } else {
      _mcpHidden.add(cmd);
    }
  }

  /// Built-in commands registered in the constructor; survive [clear] and
  /// don't count toward [isEmpty].
  static const _builtins = {'ping', 'version', 'capabilities'};

  /// Remove all registered handlers except the built-ins.
  void clear() {
    _handlers.removeWhere((k, _) => !_builtins.contains(k));
    _schemas.removeWhere((k, _) => !_builtins.contains(k));
    _mcpHidden.removeWhere((k) => !_builtins.contains(k));
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

  Future<IpcResponse> _ping(IpcRequest req) async =>
      IpcResponse.ok(id: req.id, data: {'pong': true, 'ts': DateTime.now().toUtc().toIso8601String(), 'version': clideVersion});

  Future<IpcResponse> _version(IpcRequest req) async => IpcResponse.ok(id: req.id, data: {'version': clideVersion});

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

  /// Build the MCP `tools/list` surface from the live command registry
  /// (D-86): one tool per registered command (minus [_mcpHidden]), named
  /// `<prefix><cmd>`, with an `inputSchema` derived from the same D-74
  /// [CommandSchema] that drives CLI/palette argument validation — so the
  /// MCP surface can't drift from what actually dispatches. Server-intercepted
  /// commands (`tail`, `events`) aren't registered here, so they're naturally
  /// absent.
  List<Map<String, Object?>> mcpTools({String prefix = 'mcp__clide__'}) {
    final names = _handlers.keys.toList()..sort();
    final tools = <Map<String, Object?>>[];
    for (final cmd in names) {
      if (_mcpHidden.contains(cmd)) continue;
      final schema = _schemas[cmd];
      final props = <String, Object?>{};
      final required = <String>[];
      if (schema != null) {
        for (final e in schema.args.entries) {
          props[e.key] = _argJsonSchema(e.value);
          if (e.value.required) required.add(e.key);
        }
      }
      final dot = cmd.indexOf('.');
      final subsystem = dot >= 0 ? cmd.substring(0, dot) : '';
      final verb = dot >= 0 ? cmd.substring(dot + 1) : cmd;
      tools.add({
        'name': '$prefix$cmd',
        'description': subsystem.isEmpty ? verb : '$subsystem: $verb',
        'inputSchema': {'type': 'object', 'properties': props, if (required.isNotEmpty) 'required': required},
      });
    }
    return tools;
  }

  /// Map one [ArgSpec] to a JSON-Schema property (MCP `inputSchema` shape).
  static Map<String, Object?> _argJsonSchema(ArgSpec s) {
    switch (s.type) {
      case ArgType.string:
        return {'type': 'string', if (s.allowed != null) 'enum': (s.allowed!.toList()..sort()), if (s.pattern != null) 'pattern': s.pattern!.pattern};
      case ArgType.number:
        return {'type': 'number', if (s.min != null) 'minimum': s.min, if (s.max != null) 'maximum': s.max};
      case ArgType.boolean:
        return {'type': 'boolean'};
      case ArgType.stringList:
        return {
          'type': 'array',
          'items': const {'type': 'string'},
          if (s.maxItems != null) 'maxItems': s.maxItems,
        };
    }
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
