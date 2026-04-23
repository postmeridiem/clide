import 'dart:async';

import 'package:clide/kernel/src/events/types.dart';

class DaemonBus {
  DaemonBus();

  final StreamController<ClideEventEnvelope> _controller =
      StreamController<ClideEventEnvelope>.broadcast();

  Stream<ClideEventEnvelope> get stream => _controller.stream;

  Stream<T> on<T extends ClideEvent>() =>
      _controller.stream.where((e) => e.event is T).map((e) => e.event as T);

  void emit(ClideEvent event) {
    if (_controller.isClosed) return;
    _controller.add(ClideEventEnvelope(event, DateTime.now().toUtc()));
  }

  Future<void> dispose() => _controller.close();
}
