import 'dart:async';

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';

/// A DaemonClient that doesn't actually open a socket. Use in tests
/// that need a connected-state observable but not a real daemon.
///
/// Beyond answering stubs (T-638):
///  * [calls] logs every request, stubbed or not, so a test can assert what
///    the widget asked for — and in what order.
///  * [strict] makes an unstubbed command throw instead of quietly returning
///    a not-found error, so a missing stub fails the test where it happens
///    rather than surfacing as an empty screen three assertions later.
///  * [requireConnection] answers a request made while disconnected the way
///    the real client does — `daemon not connected` — instead of pretending.
///  * [defer] parks a command's replies until the test answers them, which
///    is how an out-of-order reply race is written.
///  * [reconnectWith] / [reconnectAt] are recorded, never dialled.
class FakeDaemonClient extends DaemonClient {
  FakeDaemonClient({required super.log, required super.events, this.strict = false, this.requireConnection = false})
    : super.unixSocket(socketPath: '/dev/null/fake-clide.sock');

  /// An unstubbed command throws [StateError] instead of answering not-found.
  bool strict;

  /// A request while disconnected answers `daemon not connected`, as the
  /// real client does once it gives up waiting for a connection.
  bool requireConnection;

  bool _fakeConnected = false;
  final Map<String, Future<IpcResponse> Function(Map<String, Object?>)> _stubs = {};

  /// Every request, in order.
  final List<({String cmd, Map<String, Object?> args})> calls = [];

  /// The commands requested, in order.
  List<String> get commands => [for (final c in calls) c.cmd];

  /// The args of every request for [cmd], in order.
  List<Map<String, Object?>> callsTo(String cmd) => [
    for (final c in calls)
      if (c.cmd == cmd) c.args,
  ];

  /// Endpoints passed to [reconnectWith] / [reconnectAt], in order.
  final List<String> reconnects = [];

  /// Whether a reconnect comes back connected.
  bool reconnectSucceeds = true;

  @override
  bool get isConnected => _fakeConnected;

  @override
  Future<void> start() async {
    // No real socket; tests drive connection-state via [setConnected].
  }

  @override
  Future<void> stop() async {
    _fakeConnected = false;
    notifyListeners();
  }

  @override
  Future<void> reconnectWith(DaemonTransport transport) async {
    reconnects.add(transport.endpoint);
    setConnected(false);
    setConnected(reconnectSucceeds);
  }

  @override
  Future<IpcResponse> request(String cmd, {Map<String, Object?> args = const {}}) async {
    calls.add((cmd: cmd, args: args));
    if (requireConnection && !_fakeConnected) {
      return IpcResponse.err(
        id: '',
        error: IpcError(code: IpcExitCode.toolError, kind: IpcErrorKind.toolError, message: 'daemon not connected'),
      );
    }
    final stub = _stubs[cmd];
    if (stub != null) return stub(args);
    if (strict) throw StateError('FakeDaemonClient (strict): no stub for "$cmd" (args: $args)');
    return IpcResponse.err(
      id: '',
      error: IpcError(code: IpcExitCode.notFound, kind: IpcErrorKind.notFound, message: 'no stub for $cmd'),
    );
  }

  void setConnected(bool v) {
    if (_fakeConnected == v) return;
    _fakeConnected = v;
    notifyListeners();
  }

  void stub(String cmd, Future<IpcResponse> Function(Map<String, Object?>) handler) {
    _stubs[cmd] = handler;
  }

  /// Park every [cmd] request until the test answers it. The returned
  /// [DeferredStub] lists the parked calls in arrival order; answering them
  /// in a different order is how a stale-reply race is reproduced.
  DeferredStub defer(String cmd) {
    final d = DeferredStub._(cmd);
    _stubs[cmd] = d._park;
    return d;
  }
}

/// The parked replies of one command (see [FakeDaemonClient.defer]).
class DeferredStub {
  DeferredStub._(this.cmd);

  final String cmd;
  final List<DeferredCall> _calls = [];

  /// Parked calls, in arrival order — answered ones included.
  List<DeferredCall> get calls => List.unmodifiable(_calls);

  /// Calls not yet answered, in arrival order.
  List<DeferredCall> get pending => [
    for (final c in _calls)
      if (!c.answered) c,
  ];

  Future<IpcResponse> _park(Map<String, Object?> args) {
    final call = DeferredCall._(args);
    _calls.add(call);
    return call._reply.future;
  }
}

/// One parked request; answer it with [ok] or [err].
class DeferredCall {
  DeferredCall._(this.args);

  final Map<String, Object?> args;
  final _reply = Completer<IpcResponse>();

  bool get answered => _reply.isCompleted;

  void ok(Map<String, Object?> data) => _reply.complete(IpcResponse.ok(id: '', data: data));

  void err(String message, {int code = IpcExitCode.toolError, String kind = IpcErrorKind.toolError}) => _reply.complete(
    IpcResponse.err(
      id: '',
      error: IpcError(code: code, kind: kind, message: message),
    ),
  );
}
