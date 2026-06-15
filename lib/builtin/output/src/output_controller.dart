/// Filter state + filtered view over a [LogRing] for the Output dock tab
/// (T-54 / D-87). Notifies when the ring changes or a filter is set, so the
/// view rebuilds; the ring itself stays Flutter-free.
library;

import 'dart:async';

import 'package:clide/kernel/src/log.dart';
import 'package:clide/kernel/src/log_ring.dart';
import 'package:flutter/foundation.dart';

class OutputController extends ChangeNotifier {
  OutputController(this.ring, {LogLevel? initialLevel, this.onMinLevelChanged}) : minLevel = initialLevel ?? LogLevel.debug {
    _sub = ring.changes.listen((_) => notifyListeners());
  }

  final LogRing ring;
  late final StreamSubscription<void> _sub;

  /// Invoked when the Level chip changes the level — the dock chip is the live
  /// dev/prod verbosity toggle (T-433), not just a view filter. The owner wires
  /// this to set the kernel `Logger.minLevel` and persist `app.log.level`. Null
  /// in tests / when no kernel is attached, leaving the chip a pure view filter.
  final void Function(LogLevel)? onMinLevelChanged;

  /// Minimum level shown — initialized from the kernel logger's level so the
  /// chip reflects the real verbosity (which a `clide log level` CLI may have
  /// already set), defaulting to debug (trace is firehose-noise).
  LogLevel minLevel;

  /// Source filter; null = all sources.
  String? source;

  /// Free-text filter over message + source.
  String text = '';

  void setMinLevel(LogLevel level) {
    if (minLevel == level) return;
    minLevel = level;
    onMinLevelChanged?.call(level);
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
