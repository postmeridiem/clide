import 'package:clide/clide.dart';
import 'package:clide/kernel/src/ipc/client.dart';

class InProcessClient extends DaemonClient {
  InProcessClient({
    required super.log,
    required super.events,
    required this.dispatcher,
  }) : super(socketPath: '');

  DaemonDispatcher dispatcher;
  int _nextReqId = 0;

  @override
  bool get isConnected => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<IpcResponse> request(String cmd, {Map<String, Object?> args = const {}}) {
    final id = '${_nextReqId++}';
    final req = IpcRequest(id: id, cmd: cmd, args: args);
    return dispatcher.dispatch(req);
  }
}
