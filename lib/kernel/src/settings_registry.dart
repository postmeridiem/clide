import 'package:clide/kernel/src/settings_schema.dart';
import 'package:flutter/foundation.dart';

/// Holds the [SettingsCategory] schemas subsystems register against the kernel
/// (via `SettingsCategoryContribution`, routed by the extension manager). The
/// settings panel reads this to build its rail + panels (T-447/T-448) and
/// rebuilds when the set changes.
class SettingsRegistry extends ChangeNotifier {
  final Map<String, SettingsCategory> _byId = <String, SettingsCategory>{};

  /// Registered categories, sorted by (priority, then case-insensitive title).
  List<SettingsCategory> get categories {
    final list = _byId.values.toList()
      ..sort((a, b) {
        final p = a.priority.compareTo(b.priority);
        return p != 0 ? p : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return List.unmodifiable(list);
  }

  SettingsCategory? byId(String id) => _byId[id];

  /// Register a category. Throws on a duplicate id — a collision is a wiring
  /// bug that should roll the contributing extension's activation back, the
  /// same way duplicate command/slot ids do.
  void register(SettingsCategory category) {
    if (_byId.containsKey(category.id)) {
      throw StateError('duplicate settings category id: ${category.id}');
    }
    _byId[category.id] = category;
    notifyListeners();
  }

  void unregister(String id) {
    if (_byId.remove(id) != null) notifyListeners();
  }
}
