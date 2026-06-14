/// Replay-latest broadcast value holder (T-386).
///
/// Broadcast streams drop the current value for late subscribers — the
/// recurring bug factory behind T-274 (status bar blank because the
/// `system/init` event fired before the pane subscribed) and the
/// per-site `initialData` workarounds. A [ValueStream] carries STATE,
/// not events: every new subscriber immediately receives the latest
/// value (when one exists), then live updates.
///
/// Pure Dart — usable from the IPC/daemon layer and under `dart test`.
library;

import 'dart:async';

class ValueStream<T> {
  ValueStream();

  ValueStream.seeded(T value) : _value = value, _hasValue = true;

  final StreamController<T> _ctl = StreamController<T>.broadcast();
  T? _value;
  bool _hasValue = false;

  /// Whether a value has been added (or seeded) yet. A fresh, unseeded
  /// holder replays nothing — subscribers wait for the first [add].
  bool get hasValue => _hasValue;

  /// The latest value, or null before the first [add]. For a nullable
  /// [T], disambiguate with [hasValue].
  T? get valueOrNull => _value;

  /// The latest value. Throws [StateError] before the first [add] —
  /// callers that can race the first value should use [valueOrNull].
  T get value {
    if (!_hasValue) throw StateError('ValueStream has no value yet');
    return _value as T;
  }

  void add(T value) {
    _value = value;
    _hasValue = true;
    if (!_ctl.isClosed) _ctl.add(value);
  }

  /// A stream that replays the latest value (if any) to its subscriber,
  /// then follows live updates. Each access returns a fresh
  /// single-subscription stream, so every listener gets its own replay.
  Stream<T> get stream {
    late StreamController<T> out;
    StreamSubscription<T>? sub;
    out = StreamController<T>(
      onListen: () {
        if (_hasValue) out.add(_value as T);
        if (_ctl.isClosed) {
          out.close();
          return;
        }
        sub = _ctl.stream.listen(out.add, onError: out.addError, onDone: out.close);
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  bool get isClosed => _ctl.isClosed;

  Future<void> close() => _ctl.close();
}
