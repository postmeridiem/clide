/// Accumulates [ConversationItem]s from a transcript stream for the
/// native Claude conversation view (epic T-132, D-75).
///
/// Thin [ChangeNotifier] over a `Stream<ConversationItem>` (normally
/// [TranscriptReader.stream]). Kept separate from the widget so it can
/// be unit-tested with a plain stream and reused per teammate panel
/// when the team work (T-139/T-140) lands.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/transcript_publisher.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:flutter/foundation.dart';

class ConversationController extends ChangeNotifier {
  /// Listens to [stream] and accumulates items. [seed] pre-populates the
  /// item list synchronously before subscribing — used when resuming a
  /// session (D-77), where `claude --resume` doesn't replay prior turns
  /// over stream-json so the pane would otherwise start empty. [onDispose]
  /// is invoked from [dispose] — wire it to the reader's `dispose` so
  /// cancelling the view tears down the underlying tail.
  ConversationController({required Stream<ConversationItem> stream, Iterable<ConversationItem>? seed, Future<void> Function()? onDispose})
    : _onDispose = onDispose {
    if (seed != null) _items.addAll(seed);
    _sub = stream.listen(_onItem);
  }

  /// Build a controller fed from the kernel [MessageBus] — it consumes
  /// the [ConversationItem]s a `TranscriptPublisher` writes onto
  /// `publisher`/[channel]. Decouples the view from the reader so several
  /// panels can render the same conversation (team work, T-139/T-140).
  factory ConversationController.fromBus({required MessageBus messages, String channel = ClaudeConversation.leadChannel, Future<void> Function()? onDispose}) {
    final stream = messages
        .subscribe(publisher: ClaudeConversation.publisher, channel: channel)
        .map((m) => m.data[ClaudeConversation.itemKey] as ConversationItem);
    return ConversationController(stream: stream, onDispose: onDispose);
  }

  final Future<void> Function()? _onDispose;
  late final StreamSubscription<ConversationItem> _sub;
  final List<ConversationItem> _items = [];

  /// Index from uuid → position in [_items] for the FIRST item with that
  /// uuid. Used to upsert partial-message streaming updates in-place (T-168):
  /// when a partial arrives, the session emits an item with the same uuid as
  /// the previous partial so the controller replaces rather than appends it.
  /// Only the first occurrence is indexed — full (non-partial) items that
  /// share a uuid after a session resume are appended normally (uuid reuse
  /// across turns is rare; correctness wins over perf there).
  final Map<String, int> _uuidIndex = {};

  Timer? _notifyTimer;
  bool _disposed = false;

  /// Items in arrival (transcript) order.
  List<ConversationItem> get items => List.unmodifiable(_items);

  /// Index from `tool_use_id` to the corresponding [AssistantToolUse] item,
  /// built as items arrive. Used by the conversation view to render the
  /// result card in the context of its tool_use (T-168).
  Map<String, AssistantToolUse> get toolUseById => Map.unmodifiable(_toolUseById);
  final Map<String, AssistantToolUse> _toolUseById = {};

  bool get isEmpty => _items.isEmpty;

  /// Append a locally-produced item that did not come from the transcript
  /// stream — e.g. an image card driven by `clide image show` (T-249). It
  /// lands in arrival order and notifies listeners exactly like a streamed
  /// item, so the view renders it inline. No-op once disposed.
  void inject(ConversationItem item) {
    if (_disposed) return;
    _onItem(item);
  }

  void _onItem(ConversationItem item) {
    // Track AssistantToolUse items by toolUseId for result-card pairing (T-168).
    if (item is AssistantToolUse) {
      _toolUseById[item.toolUseId] = item;
    }
    // Upsert-by-uuid only for partial-message streaming items (T-168). Partial
    // items are distinguished by a `partial-<message.id>` uuid prefix assigned
    // by [StreamJsonSession]. Real transcript items always have distinct uuids
    // (or at least should not be collapsed even when they collide, since the
    // transcript records separate turns). This guard prevents test items with
    // fixed uuids from accidentally replacing each other.
    if (item.uuid.startsWith('partial-')) {
      final existing = _uuidIndex[item.uuid];
      if (existing != null && existing < _items.length) {
        _items[existing] = item;
        if (item is AssistantToolUse) _toolUseById[item.toolUseId] = item;
        // Coalesce-notify path below handles notifications.
      } else {
        _uuidIndex[item.uuid] = _items.length;
        _items.add(item);
      }
    } else {
      // Normal (non-partial) item: always append. Index only if not already
      // seen (so the first real occurrence wins in the upsert table — there
      // should be no real collision, but be safe).
      _uuidIndex.putIfAbsent(item.uuid, () => _items.length);
      _items.add(item);
    }
    // Coalesce notifications: the reader emits a burst (the initial tail
    // read), and a notify-per-item would thrash the view's rebuild +
    // auto-scroll. A zero-duration Timer fires only after the microtask
    // queue drains — the stream delivers one event per microtask, so a
    // microtask-scheduled notify would interleave between deliveries and
    // fire per item. The timer collapses a whole burst into one rebuild.
    _notifyTimer ??= Timer(Duration.zero, () {
      _notifyTimer = null;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    unawaited(_sub.cancel());
    unawaited(_onDispose?.call());
    super.dispose();
  }
}
