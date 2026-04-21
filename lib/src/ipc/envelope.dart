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
  IpcRequest({
    required this.id,
    required this.cmd,
    this.args = const {},
  });

  final String id;
  final String cmd;
  final Map<String, Object?> args;

  @override
  Map<String, Object?> toJson() => {
        'type': 'request',
        'v': ipcSchemaVersion,
        'id': id,
        'cmd': cmd,
        'args': args,
      };

  factory IpcRequest.fromJson(Map<String, Object?> j) => IpcRequest(
        id: j['id']! as String,
        cmd: j['cmd']! as String,
        args: (j['args'] as Map?)?.cast<String, Object?>() ?? const {},
      );
}

class IpcResponse extends IpcMessage {
  IpcResponse.ok({required this.id, this.data = const {}})
      : ok = true,
        error = null;

  IpcResponse.err({required this.id, required IpcError this.error})
      : ok = false,
        data = const {};

  IpcResponse._({
    required this.id,
    required this.ok,
    required this.data,
    required this.error,
  });

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
    return IpcResponse._(
      id: j['id']! as String,
      ok: ok,
      data: (j['data'] as Map?)?.cast<String, Object?>() ?? const {},
      error: ok
          ? null
          : IpcError.fromJson((j['error'] as Map).cast<String, Object?>()),
    );
  }
}

class IpcError {
  IpcError({
    required this.code,
    required this.kind,
    required this.message,
    this.hint,
  });

  final int code;
  final String kind;
  final String message;
  final String? hint;

  Map<String, Object?> toJson() => {
        'code': code,
        'kind': kind,
        'message': message,
        if (hint != null) 'hint': hint,
      };

  factory IpcError.fromJson(Map<String, Object?> j) => IpcError(
        code: (j['code'] as num).toInt(),
        kind: j['kind']! as String,
        message: j['message']! as String,
        hint: j['hint'] as String?,
      );
}

class IpcEvent extends IpcMessage {
  IpcEvent({
    required this.subsystem,
    required this.kind,
    required this.timestamp,
    this.data = const {},
  });

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
