import 'package:flutter/foundation.dart';

/// One tab inside a [MultitabPane]. The [payload] is the host-owned
/// domain object the body builder renders (e.g. a Claude session ref,
/// an editor buffer ref).
@immutable
class MultitabEntry<T> {
  const MultitabEntry({
    required this.id,
    required this.title,
    required this.payload,
    this.closeable = true,
    this.reorderable = true,
  });

  /// Stable id for this tab. Must be unique within the controller.
  final String id;

  /// Display label shown in the tab strip.
  final String title;

  /// Domain object the host's body builder consumes.
  final T payload;

  /// Whether the user can close this tab. Set to `false` for tabs
  /// the host considers permanent (e.g. the primary Claude pane).
  final bool closeable;

  /// Whether the user can drag this tab to a new position. Pinned
  /// tabs (e.g. the primary) keep their position and form a barrier:
  /// reorderable tabs cannot move past a pinned tab on either side.
  final bool reorderable;

  MultitabEntry<T> copyWith({
    String? title,
    T? payload,
    bool? closeable,
    bool? reorderable,
  }) {
    return MultitabEntry<T>(
      id: id,
      title: title ?? this.title,
      payload: payload ?? this.payload,
      closeable: closeable ?? this.closeable,
      reorderable: reorderable ?? this.reorderable,
    );
  }
}

/// Manages the entries and active selection for a [MultitabPane].
/// Hosts seed the controller and route the user's add/close/reorder
/// gestures back through it.
class MultitabController<T> extends ChangeNotifier {
  MultitabController({List<MultitabEntry<T>> initial = const []}) {
    for (final e in initial) {
      _checkUniqueId(e.id);
      _entries.add(e);
    }
    if (_entries.isNotEmpty) _activeId = _entries.first.id;
  }

  final List<MultitabEntry<T>> _entries = [];
  String? _activeId;

  /// Read-only view of current entries in display order.
  List<MultitabEntry<T>> get entries => List.unmodifiable(_entries);

  /// Currently-active entry, or null when there are no entries.
  MultitabEntry<T>? get active {
    final id = _activeId;
    if (id == null) return null;
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return _entries.isEmpty ? null : _entries.first;
  }

  String? get activeId => active?.id;

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  /// Insert [entry] at the end. If [activate] is true (default), make
  /// it the active tab.
  void add(MultitabEntry<T> entry, {bool activate = true}) {
    _checkUniqueId(entry.id);
    _entries.add(entry);
    if (activate || _activeId == null) _activeId = entry.id;
    notifyListeners();
  }

  /// Insert [entry] at [index] (clamped into range).
  void insert(int index, MultitabEntry<T> entry, {bool activate = true}) {
    _checkUniqueId(entry.id);
    final at = index.clamp(0, _entries.length);
    _entries.insert(at, entry);
    if (activate || _activeId == null) _activeId = entry.id;
    notifyListeners();
  }

  /// Remove the entry with [id]. If it was active, activation falls
  /// to the entry immediately to its right, then to its left, then
  /// to null (empty controller).
  ///
  /// Silently no-ops if the id isn't found or the entry is not
  /// closeable. Hosts that want to bypass closeable should remove
  /// the entry by replacing it via [replace] first.
  void remove(String id) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    if (!_entries[index].closeable) return;
    final wasActive = _activeId == id;
    _entries.removeAt(index);
    if (wasActive) {
      if (_entries.isEmpty) {
        _activeId = null;
      } else {
        final fallback = index < _entries.length ? index : _entries.length - 1;
        _activeId = _entries[fallback].id;
      }
    }
    notifyListeners();
  }

  /// Replace the entry with [id] in place. Used when the host needs
  /// to update title or payload without disturbing position or
  /// active selection.
  void replace(String id, MultitabEntry<T> next) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    if (next.id != id) {
      throw StateError('replace() must keep the same id (got "${next.id}", expected "$id")');
    }
    _entries[index] = next;
    notifyListeners();
  }

  /// Make [id] the active tab. No-op if the id isn't present.
  void activate(String id) {
    if (_activeId == id) return;
    if (!_entries.any((e) => e.id == id)) return;
    _activeId = id;
    notifyListeners();
  }

  /// Move the entry with [id] to [newIndex]. Pinned (`reorderable:
  /// false`) entries form barriers that cannot be crossed: a
  /// reorderable tab cannot be dropped before a pinned tab that
  /// currently sits to its left, and a pinned tab itself cannot move.
  void reorder(String id, int newIndex) {
    final from = _entries.indexWhere((e) => e.id == id);
    if (from < 0) return;
    if (!_entries[from].reorderable) return;

    var to = newIndex.clamp(0, _entries.length - 1);
    if (to == from) return;

    // Enforce pinned barriers. The lowest legal index is one past
    // the last pinned entry to the left; the highest is one before
    // the first pinned entry to the right.
    var minIndex = 0;
    for (var i = 0; i < _entries.length; i++) {
      if (i == from) continue;
      if (!_entries[i].reorderable && i < from) minIndex = i + 1;
    }
    var maxIndex = _entries.length - 1;
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (i == from) continue;
      if (!_entries[i].reorderable && i > from) maxIndex = i - 1;
    }
    to = to.clamp(minIndex, maxIndex);
    if (to == from) return;

    final entry = _entries.removeAt(from);
    _entries.insert(to, entry);
    notifyListeners();
  }

  /// Activate the next entry to the right of the active one,
  /// wrapping at the end. No-op if fewer than 2 entries.
  void activateNext() => _step(1);

  /// Activate the previous entry, wrapping at the start.
  void activatePrev() => _step(-1);

  void _step(int delta) {
    if (_entries.length < 2) return;
    final id = _activeId;
    final from = id == null ? 0 : _entries.indexWhere((e) => e.id == id);
    final next = (from + delta) % _entries.length;
    final wrapped = next < 0 ? next + _entries.length : next;
    _activeId = _entries[wrapped].id;
    notifyListeners();
  }

  void _checkUniqueId(String id) {
    if (_entries.any((e) => e.id == id)) {
      throw StateError('MultitabController already contains entry id "$id"');
    }
  }
}
