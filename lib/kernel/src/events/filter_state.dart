import 'dart:async';

import 'message_bus.dart';

/// Caches the latest filter value per address, fed by `filter.state`
/// messages on the [MessageBus] (T-270, D-6 parity).
///
/// Sidebar filter boxes are addressable from the CLI: `clide ui filter`
/// with an address and text publishes a `filter.set` message the box
/// reacts to (the drive-half). The observe-half — the same verb with no
/// text — needs to read the box's *current* value back, but the bus is
/// a plain broadcast stream with no retention. Each box republishes its
/// value on the `filter.state` channel whenever it changes; this cache
/// listens once and remembers the latest per address, giving the observe
/// verb something to read.
///
/// Pure Dart — no Flutter import — so it serialises through the kernel and
/// stays usable from `dart test`.
class FilterStateCache {
  FilterStateCache({required MessageBus messages}) {
    _sub = messages.subscribe(channel: 'filter.state').listen((m) {
      _values[m.publisher] = m.data['query'] as String? ?? '';
    });
  }

  final Map<String, String> _values = {};
  StreamSubscription<Message>? _sub;

  /// The last reported filter value for [address], or null if no box at
  /// that address has reported yet.
  String? get(String address) => _values[address];

  void dispose() {
    _sub?.cancel();
  }
}
