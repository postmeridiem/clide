/// Registers pane.* command handlers on a [DaemonDispatcher].
///
/// Verb list matches D-006's subsystem table:
///   pane.spawn pane.list pane.focus pane.close
///   pane.write pane.resize pane.tail
///
/// `pane.tail` is a no-op on the command surface — events are pushed
/// over the same socket. The name exists for parity with the CLI
/// (`clide pane tail --events`) which subscribes to the event stream.
library;

import 'dart:convert';

import '../ipc/envelope.dart';
import '../ipc/schema_v1.dart';
import '../panes/pane.dart';
import '../panes/registry.dart';
import '../../kernel/src/toolchain.dart';
import 'dispatcher.dart';

void registerPaneCommands(DaemonDispatcher d, PaneRegistry registry, {required Toolchain toolchain}) {
  d.register('pane.spawn', (req) => _spawn(req, registry, toolchain));
  d.register('pane.list', (req) => _list(req, registry));
  d.register('pane.close', (req) => _close(req, registry));
  d.register('pane.write', (req) => _write(req, registry));
  d.register('pane.resize', (req) => _resize(req, registry));
  d.register('pane.focus', (req) => _focus(req, registry));
  d.register('pane.tail', (req) => _tail(req, registry));
}

IpcResponse _userErr(String id, String message, {String? hint}) =>
    IpcResponse.err(
      id: id,
      error: IpcError(
        code: IpcExitCode.userError,
        kind: IpcErrorKind.userError,
        message: message,
        hint: hint,
      ),
    );

IpcResponse _notFound(String id, String message) => IpcResponse.err(
      id: id,
      error: IpcError(
        code: IpcExitCode.notFound,
        kind: IpcErrorKind.notFound,
        message: message,
      ),
    );

Future<IpcResponse> _spawn(IpcRequest req, PaneRegistry registry, Toolchain toolchain) async {
  // Wait for toolchain resolution if it hasn't completed yet.
  if (!toolchain.resolved) {
    await Future.any([
      toolchain.waitForResolution(),
      Future.delayed(const Duration(seconds: 5)),
    ]);
  }
  final args = req.args;
  final rawArgv = args['argv'];
  if (rawArgv is! List || rawArgv.isEmpty) {
    return _userErr(req.id, 'argv is required and non-empty');
  }
  final argv = rawArgv.whereType<String>().toList();
  if (argv.length != rawArgv.length) {
    return _userErr(req.id, 'argv entries must be strings');
  }

  final rawKind = args['kind'];
  PaneKind kind;
  try {
    kind = rawKind is String ? PaneKind.parse(rawKind) : PaneKind.terminal;
  } on ArgumentError catch (e) {
    return _userErr(req.id, e.message?.toString() ?? 'bad kind');
  }

  final envArg = args['env'];
  Map<String, String>? env;
  if (envArg is Map) {
    env = {
      for (final e in envArg.entries)
        '${e.key}': '${e.value}',
    };
  }

  try {
    final pane = await registry.spawn(
      kind: kind,
      argv: argv,
      cwd: args['cwd'] as String?,
      env: env,
      cols: (args['cols'] as num?)?.toInt() ?? 80,
      rows: (args['rows'] as num?)?.toInt() ?? 24,
      title: args['title'] as String?,
      ptycPath: (args['ptyc_path'] as String?) ?? toolchain.ptyc,
    );
    return IpcResponse.ok(id: req.id, data: pane.toJson());
  } catch (e) {
    return IpcResponse.err(
      id: req.id,
      error: IpcError(
        code: IpcExitCode.toolError,
        kind: IpcErrorKind.toolError,
        message: 'pane.spawn failed: $e',
      ),
    );
  }
}

Future<IpcResponse> _list(IpcRequest req, PaneRegistry registry) async {
  return IpcResponse.ok(
    id: req.id,
    data: {'panes': [for (final p in registry.panes) p.toJson()]},
  );
}

Future<IpcResponse> _close(IpcRequest req, PaneRegistry registry) async {
  final id = req.args['id'] as String?;
  if (id == null) return _userErr(req.id, 'id is required');
  if (registry.get(id) == null) return _notFound(req.id, 'no such pane: $id');
  await registry.close(id);
  return IpcResponse.ok(id: req.id, data: {'id': id});
}

Future<IpcResponse> _write(IpcRequest req, PaneRegistry registry) async {
  final id = req.args['id'] as String?;
  if (id == null) return _userErr(req.id, 'id is required');
  if (registry.get(id) == null) return _notFound(req.id, 'no such pane: $id');

  List<int> bytes;
  final rawBytes = req.args['bytes_b64'];
  final rawText = req.args['text'];
  if (rawBytes is String) {
    try {
      bytes = base64Decode(rawBytes);
    } on FormatException {
      return _userErr(req.id, 'bytes_b64 is not valid base64');
    }
  } else if (rawText is String) {
    bytes = utf8.encode(rawText);
  } else {
    return _userErr(req.id, 'write requires bytes_b64 or text');
  }

  final n = registry.write(id, bytes);
  return IpcResponse.ok(id: req.id, data: {'id': id, 'written': n});
}

Future<IpcResponse> _resize(IpcRequest req, PaneRegistry registry) async {
  final id = req.args['id'] as String?;
  final cols = (req.args['cols'] as num?)?.toInt();
  final rows = (req.args['rows'] as num?)?.toInt();
  if (id == null || cols == null || rows == null) {
    return _userErr(req.id, 'id, cols, rows are required');
  }
  if (registry.get(id) == null) return _notFound(req.id, 'no such pane: $id');
  registry.resize(id, cols: cols, rows: rows);
  return IpcResponse.ok(id: req.id, data: {'id': id, 'cols': cols, 'rows': rows});
}

Future<IpcResponse> _focus(IpcRequest req, PaneRegistry registry) async {
  final id = req.args['id'] as String?;
  if (id == null) return _userErr(req.id, 'id is required');
  if (registry.get(id) == null) return _notFound(req.id, 'no such pane: $id');
  // Focus is advisory on the daemon side — UIs track their own focus
  // state. We just emit the event so subscribers know what changed.
  registry.events.emit(IpcEvent(
    subsystem: 'pane',
    kind: 'pane.focused',
    timestamp: DateTime.now().toUtc(),
    data: {'id': id},
  ));
  return IpcResponse.ok(id: req.id, data: {'id': id});
}

Future<IpcResponse> _tail(IpcRequest req, PaneRegistry registry) async {
  // No-op — events are already pushed over the client's socket by the
  // server's broadcast. The response just acknowledges that the
  // subscription is in place.
  return IpcResponse.ok(id: req.id, data: {'subscribed': true});
}
