/// Accumulates [ConversationItem]s from a transcript stream for the
/// native Claude conversation view (epic T-132, D-75).
///
/// Thin [ChangeNotifier] over a `Stream<ConversationItem>` (normally
/// [TranscriptReader.stream]). Kept separate from the widget so it can
/// be unit-tested with a plain stream and reused per teammate panel
/// when the team work (T-139/T-140) lands.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/transcript_reader.dart';
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

  /// Convenience: build a controller backed by a live [TranscriptReader]
  /// for [workspacePath].
  factory ConversationController.forWorkspace(String workspacePath) {
    final reader = TranscriptReader(workspacePath);
    return ConversationController(stream: reader.stream, onDispose: reader.dispose);
  }

  final Future<void> Function()? _onDispose;
  late final StreamSubscription<ConversationItem> _sub;
  final List<ConversationItem> _items = [];

  /// Items in arrival (transcript) order.
  List<ConversationItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  void _onItem(ConversationItem item) {
    _items.add(item);
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    unawaited(_onDispose?.call());
    super.dispose();
  }
}
