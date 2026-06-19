import 'package:clide/extension/src/contribution.dart';
import 'package:clide/kernel/src/commands/registry.dart';
import 'package:clide/kernel/src/fuzzy.dart';
import 'package:flutter/foundation.dart';

class PaletteController extends ChangeNotifier {
  PaletteController(this._registry);

  final CommandRegistry _registry;

  /// Resolves a command's display title (the widget sets this to an i18n-aware
  /// resolver so both the rendered title AND fuzzy search use the localized
  /// string, T-462). Defaults to the English title/id.
  String Function(CommandContribution cmd)? titleResolver;
  String _titleOf(CommandContribution c) => titleResolver?.call(c) ?? c.title ?? c.command;

  bool _open = false;
  String _filter = '';
  int _selectedIndex = 0;

  /// Recently-invoked command ids, most-recent-first. Floats recent commands
  /// to the top of the list (empty query) and breaks fuzzy-score ties in their
  /// favour. In-session only. Capped so it can't grow unbounded.
  final List<String> _recent = [];
  static const int _recentCap = 20;

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

  /// The visible command list. Empty query → every command with recents
  /// floated to the top (most-recent-first), the rest in registry order. A
  /// non-empty query → a subsequence fuzzy match over each command's title
  /// (or id), best-score first; ties break toward recents, then alphabetical.
  List<CommandContribution> filtered() {
    final all = _registry.all.toList();
    final recentRank = {for (var i = 0; i < _recent.length; i++) _recent[i]: i};
    final order = {for (var i = 0; i < all.length; i++) all[i].command: i};
    int rank(String cmd) => recentRank[cmd] ?? (1 << 30);

    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) {
      all.sort((a, b) {
        final c = rank(a.command).compareTo(rank(b.command));
        // Non-recents (equal rank) keep registry order.
        return c != 0 ? c : order[a.command]!.compareTo(order[b.command]!);
      });
      return all;
    }

    final scored = <({CommandContribution cmd, int score})>[];
    for (final c in all) {
      final s = fuzzyScore(_titleOf(c).toLowerCase(), q);
      if (s != null) scored.add((cmd: c, score: s));
    }
    scored.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      final byRecent = rank(a.cmd.command).compareTo(rank(b.cmd.command));
      if (byRecent != 0) return byRecent;
      return _titleOf(a.cmd).toLowerCase().compareTo(_titleOf(b.cmd).toLowerCase());
    });
    return [for (final s in scored) s.cmd];
  }

  Future<void> invoke(String command) async {
    _recordRecent(command);
    close();
    await _registry.execute(command);
  }

  void _recordRecent(String command) {
    _recent
      ..remove(command)
      ..insert(0, command);
    if (_recent.length > _recentCap) _recent.removeRange(_recentCap, _recent.length);
  }
}
