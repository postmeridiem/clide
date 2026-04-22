import 'package:clide/extension/src/contribution.dart';
import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:flutter/foundation.dart';

@immutable
class SlotDefinition {
  const SlotDefinition({
    required this.id,
    required this.position,
    this.defaultSize,
    this.minSize,
    this.maxSize,
  });

  final SlotId id;
  final SlotPosition position;
  final double? defaultSize;
  final double? minSize;
  final double? maxSize;
}

class PanelRegistry extends ChangeNotifier {
  final Map<SlotId, SlotDefinition> _defs = {};
  final Map<SlotId, List<ContributionPoint>> _mounts = {};
  final Map<SlotId, String?> _activeTab = {};

  void registerSlot(SlotDefinition def) {
    _defs[def.id] = def;
    _mounts.putIfAbsent(def.id, () => <ContributionPoint>[]);
    notifyListeners();
  }

  void contribute(ContributionPoint point) {
    final slot = point.slot;
    if (slot == null) return; // non-slot contributions go elsewhere
    final list = _mounts.putIfAbsent(slot, () => <ContributionPoint>[]);
    list.add(point);
    list.sort((a, b) => _priority(a).compareTo(_priority(b)));
    // first tab-contribution in the sidebar/workspace/context becomes the
    // default active tab until the user picks another
    if (_activeTab[slot] == null && point is TabContribution) {
      _activeTab[slot] = point.id;
    }
    notifyListeners();
  }

  void uncontribute(String contributionId) {
    for (final entry in _mounts.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((c) => c.id == contributionId);
      if (entry.value.length != before) {
        if (_activeTab[entry.key] == contributionId) {
          _activeTab[entry.key] =
              entry.value.whereType<TabContribution>().isEmpty
                  ? null
                  : entry.value.whereType<TabContribution>().first.id;
        }
      }
    }
    notifyListeners();
  }

  Iterable<SlotDefinition> get slots => _defs.values;
  SlotDefinition? definitionFor(SlotId id) => _defs[id];

  List<ContributionPoint> contributionsFor(SlotId id) =>
      List.unmodifiable(_mounts[id] ?? const []);

  List<TabContribution> tabsFor(SlotId id) =>
      contributionsFor(id).whereType<TabContribution>().toList();

  String? activeTabIn(SlotId id) => _activeTab[id];

  void activateTab(SlotId id, String tabId) {
    if (_activeTab[id] == tabId) return;
    _activeTab[id] = tabId;
    notifyListeners();
  }

  int _priority(ContributionPoint p) {
    if (p is TabContribution) return p.priority;
    if (p is StatusItemContribution) return p.priority;
    if (p is ToolbarButtonContribution) return p.priority;
    if (p is TrayItemContribution) return p.priority;
    return 0;
  }
}
