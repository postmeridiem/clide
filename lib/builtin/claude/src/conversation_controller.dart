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
  /// Listens to [stream] and accumulates items. [onDispose] is invoked
  /// from [dispose] — wire it to the reader's `dispose` so cancelling
  /// the view tears down the underlying tail.
  ConversationController({
    required Stream<ConversationItem> stream,
    Future<void> Function()? onDispose,
  }) : _onDispose = onDispose {
    _sub = stream.listen(_onItem);
  }

  /// Build a controller fed from the kernel [MessageBus] — it consumes
  /// the [ConversationItem]s a [TranscriptPublisher] writes onto
  /// [publisher]/[channel]. Decouples the view from the reader so several
  /// panels can render the same conversation (team work, T-139/T-140).
  factory ConversationController.fromBus({
    required MessageBus messages,
    String channel = ClaudeConversation.leadChannel,
    Future<void> Function()? onDispose,
  }) {
    final stream =
        messages.subscribe(publisher: ClaudeConversation.publisher, channel: channel).map((m) => m.data[ClaudeConversation.itemKey] as ConversationItem);
    return ConversationController(stream: stream, onDispose: onDispose);
  }

  final Future<void> Function()? _onDispose;
  late final StreamSubscription<ConversationItem> _sub;
  final List<ConversationItem> _items = [];
  Timer? _notifyTimer;
  bool _disposed = false;

  /// Items in arrival (transcript) order.
  List<ConversationItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  void _onItem(ConversationItem item) {
    _items.add(item);
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
