import 'dart:convert';

import 'package:clide/src/ipc/schema_v1.dart';

sealed class IpcMessage {
  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());

  static IpcMessage decode(String line) {
    final obj = jsonDecode(line);
    if (obj is! Map<String, Object?>) {
      throw const FormatException('IPC message is not a JSON object');
    }
    final type = obj['type'];
    switch (type) {
      case 'request':
        return IpcRequest.fromJson(obj);
      case 'response':
        return IpcResponse.fromJson(obj);
      case 'event':
        return IpcEvent.fromJson(obj);
      default:
        throw FormatException('Unknown IPC message type: $type');
    }
  }
}

class IpcRequest extends IpcMessage {
  IpcRequest({required this.id, required this.cmd, this.args = const {}});

  final String id;
  final String cmd;
  final Map<String, Object?> args;

  @override
  Map<String, Object?> toJson() => {'type': 'request', 'v': ipcSchemaVersion, 'id': id, 'cmd': cmd, 'args': args};

  /// Throws [FormatException] — which the server answers as a userError — for
  /// a missing or wrong-type field, or a schema version it doesn't speak. A
  /// bare cast used to throw a TypeError instead, reported as an internal
  /// toolError with an empty id (test audit #10).
  factory IpcRequest.fromJson(Map<String, Object?> j) {
    final v = j['v'];
    if (v != null && v != ipcSchemaVersion) {
      throw FormatException('unsupported IPC schema version $v (this clide speaks $ipcSchemaVersion)');
    }
    final id = j['id'];
    if (id is! String) throw FormatException('request "id" must be a string, got ${_typeName(id)}');
    final cmd = j['cmd'];
    if (cmd is! String) throw FormatException('request "cmd" must be a string, got ${_typeName(cmd)}');
    final args = j['args'];
    if (args != null && args is! Map) throw FormatException('request "args" must be an object, got ${_typeName(args)}');
    return IpcRequest(id: id, cmd: cmd, args: (args as Map?)?.cast<String, Object?>() ?? const {});
  }
}

String _typeName(Object? v) => switch (v) {
  null => 'nothing',
  String() => 'a string',
  num() => 'a number',
  bool() => 'a boolean',
  List() => 'a list',
  Map() => 'an object',
  _ => v.runtimeType.toString(),
};

class IpcResponse extends IpcMessage {
  IpcResponse.ok({required this.id, this.data = const {}}) : ok = true, error = null;

  IpcResponse.err({required this.id, required IpcError this.error}) : ok = false, data = const {};

  IpcResponse._({required this.id, required this.ok, required this.data, required this.error});

  final String id;
  final bool ok;
  final Map<String, Object?> data;
  final IpcError? error;

  @override
  Map<String, Object?> toJson() => {
    'type': 'response',
    'v': ipcSchemaVersion,
    'id': id,
    'ok': ok,
    if (ok) 'data': data,
    if (!ok && error != null) 'error': error!.toJson(),
  };

  factory IpcResponse.fromJson(Map<String, Object?> j) {
    final ok = j['ok'] as bool? ?? false;
    final error = j['error'];
    return IpcResponse._(
      id: j['id']! as String,
      ok: ok,
      data: (j['data'] as Map?)?.cast<String, Object?>() ?? const {},
      error: ok
          ? null
          : error is Map
          ? IpcError.fromJson(error.cast<String, Object?>())
          // A failure with no error object is a malformed peer, not a reason
          // to throw a TypeError at the caller (T-81 #28).
          : IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'malformed IPC response: failure without an error object'),
    );
  }
}

class IpcError {
  IpcError({required this.code, required this.kind, required this.message, this.hint});

  final int code;
  final String kind;
  final String message;
  final String? hint;

  Map<String, Object?> toJson() => {'code': code, 'kind': kind, 'message': message, if (hint != null) 'hint': hint};

  factory IpcError.fromJson(Map<String, Object?> j) =>
      IpcError(code: (j['code'] as num).toInt(), kind: j['kind']! as String, message: j['message']! as String, hint: j['hint'] as String?);
}

class IpcEvent extends IpcMessage {
  IpcEvent({required this.subsystem, required this.kind, required this.timestamp, this.data = const {}});

  final String subsystem;
  final String kind;
  final DateTime timestamp;
  final Map<String, Object?> data;

  @override
  Map<String, Object?> toJson() => {
    'type': 'event',
    'v': ipcSchemaVersion,
    'subsystem': subsystem,
    'kind': kind,
    'ts': timestamp.toIso8601String(),
    'data': data,
  };

  factory IpcEvent.fromJson(Map<String, Object?> j) => IpcEvent(
    subsystem: j['subsystem']! as String,
    kind: j['kind']! as String,
    timestamp: DateTime.parse(j['ts']! as String),
    data: (j['data'] as Map?)?.cast<String, Object?>() ?? const {},
  );
}
