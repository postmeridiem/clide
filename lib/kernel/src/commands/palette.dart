import 'package:clide/extension/src/contribution.dart';
import 'package:clide/kernel/src/commands/registry.dart';
import 'package:flutter/foundation.dart';

class PaletteController extends ChangeNotifier {
  PaletteController(this._registry);

  final CommandRegistry _registry;

  bool _open = false;
  String _filter = '';

  bool get isOpen => _open;
  String get filter => _filter;

  void open() {
    if (_open) return;
    _open = true;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    _filter = '';
    notifyListeners();
  }

  void toggle() => _open ? close() : open();

  void setFilter(String f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
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
