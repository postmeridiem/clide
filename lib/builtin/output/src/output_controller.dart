/// Filter state + filtered view over a [LogRing] for the Output dock tab
/// (T-54 / D-87). Notifies when the ring changes or a filter is set, so the
/// view rebuilds; the ring itself stays Flutter-free.
library;

import 'dart:async';

import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/log_ring.dart';
import 'package:flutter/foundation.dart';

class OutputController extends ChangeNotifier {
  OutputController(this.ring) {
    _sub = ring.changes.listen((_) => notifyListeners());
  }

  final LogRing ring;
  late final StreamSubscription<void> _sub;

  /// Minimum level shown. Defaults to debug (trace is firehose-noise).
  LogLevel minLevel = LogLevel.debug;

  /// Source filter; null = all sources.
  String? source;

  /// Free-text filter over message + source.
  String text = '';

  void setMinLevel(LogLevel level) {
    if (minLevel == level) return;
    minLevel = level;
    notifyListeners();
  }

  void setSource(String? value) {
    if (source == value) return;
    source = value;
    notifyListeners();
  }

  void setText(String value) {
    if (text == value) return;
    text = value;
    notifyListeners();
  }

  /// Clear the underlying ring (the panel's Clear action). The ring's change
  /// event drives the rebuild.
  void clear() => ring.clear();

  /// Records passing the current filters, oldest first.
  List<LogRecord> get filtered {
    final lf = text.toLowerCase();
    return ring.records.where((r) {
      if (r.level.index < minLevel.index) return false;
      if (source != null && r.source != source) return false;
      if (lf.isNotEmpty && !r.message.toLowerCase().contains(lf) && !r.source.toLowerCase().contains(lf)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
