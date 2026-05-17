import 'package:clide/extension/src/contribution.dart';
import 'package:clide/kernel/src/commands/registry.dart';
import 'package:flutter/foundation.dart';

class PaletteController extends ChangeNotifier {
  PaletteController(this._registry);

  final CommandRegistry _registry;

  bool _open = false;
  String _filter = '';
  int _selectedIndex = 0;

  bool get isOpen => _open;
  String get filter => _filter;

  /// Index of the highlighted entry inside the currently-filtered
  /// list. Clamped to `[0, filtered().length - 1]` on read. Returns 0
  /// when the filter excludes everything.
  int get selectedIndex {
    final n = filtered().length;
    if (n == 0) return 0;
    if (_selectedIndex < 0) return 0;
    if (_selectedIndex >= n) return n - 1;
    return _selectedIndex;
  }

  void open() {
    if (_open) return;
    _open = true;
    _selectedIndex = 0;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    _filter = '';
    _selectedIndex = 0;
    notifyListeners();
  }

  void toggle() => _open ? close() : open();

  void setFilter(String f) {
    if (_filter == f) return;
    _filter = f;
    _selectedIndex = 0;
    notifyListeners();
  }

  /// Highlight the next entry, wrapping at the end. No-op when the
  /// filtered list has fewer than 2 entries.
  void selectNext() {
    final n = filtered().length;
    if (n < 2) return;
    _selectedIndex = (selectedIndex + 1) % n;
    notifyListeners();
  }

  /// Highlight the previous entry, wrapping at the start.
  void selectPrevious() {
    final n = filtered().length;
    if (n < 2) return;
    _selectedIndex = (selectedIndex - 1 + n) % n;
    notifyListeners();
  }

  /// Invoke whatever's currently highlighted; no-op when the filter
  /// excludes everything.
  Future<void> acceptSelected() async {
    final list = filtered();
    if (list.isEmpty) return;
    await invoke(list[selectedIndex].command);
  }

  List<CommandContribution> filtered() {
    if (_filter.isEmpty) return _registry.all.toList();
    final q = _filter.toLowerCase();
    return _registry.all.where((c) {
      final haystack = (c.title ?? c.command).toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> invoke(String command) async {
    close();
    await _registry.execute(command);
  }
}
