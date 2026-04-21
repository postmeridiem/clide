import 'package:clide/clide.dart';
import 'package:clide_app/kernel/kernel.dart';

/// A DaemonClient that doesn't actually open a socket. Use in tests
/// that need a connected-state observable but not a real daemon.
class FakeDaemonClient extends DaemonClient {
  FakeDaemonClient({required super.log, required super.events})
      : super(socketPath: '/dev/null/fake-clide.sock');

  bool _fakeConnected = false;
  final Map<String, Future<IpcResponse> Function(Map<String, Object?>)> _stubs =
      {};

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
  Future<IpcResponse> request(
    String cmd, {
    Map<String, Object?> args = const {},
  }) async {
    final stub = _stubs[cmd];
    if (stub != null) return stub(args);
    return IpcResponse.err(
      id: '',
      error: IpcError(
        code: IpcExitCode.notFound,
        kind: IpcErrorKind.notFound,
        message: 'no stub for $cmd',
      ),
    );
  }

  void setConnected(bool v) {
    if (_fakeConnected == v) return;
    _fakeConnected = v;
    notifyListeners();
  }

  void stub(
    String cmd,
    Future<IpcResponse> Function(Map<String, Object?>) handler,
  ) {
    _stubs[cmd] = handler;
  }
}
