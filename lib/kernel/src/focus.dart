import 'package:clide/kernel/src/panels/slot_id.dart';
import 'package:flutter/foundation.dart';

/// Tracks the currently focused contribution (tab id + slot). Backs
/// `clide active`; extensions that need "which tab does the user care
/// about right now?" read from here instead of poking Flutter's
/// FocusScope directly.
class FocusTracker extends ChangeNotifier {
  SlotId? _slot;
  String? _contributionId;

  SlotId? get activeSlot => _slot;
  String? get activeContributionId => _contributionId;

  void setActive({required SlotId slot, required String contributionId}) {
    if (_slot == slot && _contributionId == contributionId) return;
    _slot = slot;
    _contributionId = contributionId;
    notifyListeners();
  }

  void clear() {
    if (_slot == null && _contributionId == null) return;
    _slot = null;
    _contributionId = null;
    notifyListeners();
  }
}
