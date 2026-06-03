/// Retained back/forward navigation history for the right-pane readers
/// (markdown, decisions — T-196).
///
/// The history is the single source of truth for "what the reader is
/// showing", and it OUTLIVES the reader widget — so a reader that mounts
/// after a selection (its tab was just revealed) grabs [ReaderNav.current]
/// instead of missing a broadcast it subscribed to too late. The bus
/// stays a dumb pipe: a [ReaderNav] subscribes to its reader's
/// `selection` channel, records the entry, and (re-)emits `load` — which
/// is the single channel a reader loads from. Back/forward/pin navigation
/// re-emits `load` the same way, so every load flows through one path.
library;

import 'dart:async';

import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:flutter/foundation.dart';

class ReaderNav extends ChangeNotifier {
  ReaderNav({
    required MessageBus messages,
    required this.publisherId,
    required this.dataKey,
  }) : _messages = messages {
    // Retained recorder: every selection for this reader is captured
    // here whether or not the reader widget is mounted.
    _selectionSub = _messages.subscribe(publisher: publisherId, channel: 'selection').listen((m) {
      final entry = m.data[dataKey];
      if (entry is String) open(entry);
    });
  }

  final MessageBus _messages;

  /// The reader's publisher id, e.g. `builtin.decisions` / `builtin.markdown`.
  final String publisherId;

  /// The key under which the entry travels in the bus payload (`id` for
  /// decisions, `path` for markdown).
  final String dataKey;

  StreamSubscription<Message>? _selectionSub;

  final List<String> _stack = [];
  int _index = -1;
  int? _pinnedIndex;

  String? get current => _index >= 0 && _index < _stack.length ? _stack[_index] : null;
  bool get canGoBack => _index > 0;
  bool get canGoForward => _index < _stack.length - 1;
  bool get hasPinned => _pinnedIndex != null && _pinnedIndex! < _stack.length;

  /// External navigation: record [entry] (browser semantics — truncates
  /// forward history) and emit a load. A repeat of the current entry
  /// re-emits the load without pushing a duplicate.
  void open(String entry) {
    if (current == entry) {
      _emit(entry);
      return;
    }
    if (_index < _stack.length - 1) {
      _stack.removeRange(_index + 1, _stack.length);
    }
    _stack.add(entry);
    _index = _stack.length - 1;
    _emit(entry);
  }

  /// Step back and re-emit the now-current entry. No-op at the start.
  void back() {
    if (!canGoBack) return;
    _index--;
    _emit(current!);
  }

  /// Step forward and re-emit the now-current entry. No-op at the end.
  void forward() {
    if (!canGoForward) return;
    _index++;
    _emit(current!);
  }

  /// Pin the current entry (one slot; a later pin replaces it).
  void pin() {
    if (_index < 0) return;
    _pinnedIndex = _index;
    notifyListeners();
  }

  /// Toggle the pinned state: pin the current entry when nothing is
  /// pinned, otherwise clear the pin. (The reader's left-hand pin button.)
  void togglePin() {
    if (_pinnedIndex != null) {
      _pinnedIndex = null;
      notifyListeners();
    } else {
      pin();
    }
  }

  /// Jump to the pinned entry and re-emit it. No-op when nothing is pinned.
  void jumpToPin() {
    final p = _pinnedIndex;
    if (p == null || p >= _stack.length) return;
    _index = p;
    _emit(current!);
  }

  void _emit(String entry) {
    _messages.publish(publisherId, 'load', {dataKey: entry});
    notifyListeners();
  }

  @override
  void dispose() {
    _selectionSub?.cancel();
    _selectionSub = null;
    super.dispose();
  }
}

/// Lazily creates and retains one [ReaderNav] per reader id, so the
/// history persists across reader widget mount/unmount.
class ReaderNavRegistry {
  ReaderNavRegistry(this._messages);

  final MessageBus _messages;
  final Map<String, ReaderNav> _navs = {};

  /// The currently-viewed doc for every reader that has one, keyed by
  /// publisher id (e.g. `builtin.markdown`, `builtin.decisions`). Used by
  /// `clide status` to surface what the user is reading (T-221, D-6 parity) —
  /// viewer files aren't editor buffers, so they don't live in EditorRegistry.
  Map<String, String> get currentByReader => {
        for (final e in _navs.entries)
          if (e.value.current != null) e.key: e.value.current!,
      };

  /// The retained [ReaderNav] for [publisherId], created on first use.
  /// [dataKey] is the bus-payload key for this reader's entry.
  ReaderNav navFor(String publisherId, {required String dataKey}) {
    return _navs.putIfAbsent(
      publisherId,
      () => ReaderNav(messages: _messages, publisherId: publisherId, dataKey: dataKey),
    );
  }

  void dispose() {
    for (final n in _navs.values) {
      n.dispose();
    }
    _navs.clear();
  }
}
