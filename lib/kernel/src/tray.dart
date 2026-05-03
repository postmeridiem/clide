import 'package:clide/extension/src/contribution.dart';
import 'package:flutter/foundation.dart';

/// Tier-0 stub for OS tray / menu-bar integration.
///
/// Flutter desktop tray requires platform-channel wiring; this registry
/// holds the contributions so extensions can declare them today. Real
/// OS integration lands with a small per-platform channel in a later
/// tier.
class TrayRegistry extends ChangeNotifier {
  final Map<String, TrayItemContribution> _items = {};

  void add(TrayItemContribution item) {
    _items[item.id] = item;
    notifyListeners();
  }

  void remove(String id) {
    if (_items.remove(id) != null) notifyListeners();
  }

  Iterable<TrayItemContribution> get items {
    final sorted = _items.values.toList()..sort((a, b) => a.priority.compareTo(b.priority));
    return sorted;
  }
}
