/// Bridges a [TranscriptReader] onto the kernel [MessageBus] (epic T-132,
/// D-75).
///
/// One reader tails a workspace transcript; this publisher republishes
/// every [ConversationItem] as a bus [Message]. Any number of Claude
/// panels can then subscribe to the same conversation via the bus instead
/// of each owning its own reader — the decoupling the team panels
/// (T-139/T-140) need, where a single observer feeds the lead tile plus a
/// tile per teammate.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/events/message_bus.dart';

/// Bus addressing for Claude conversation content.
abstract final class ClaudeConversation {
  /// Publisher id under which conversation items are published.
  static const publisher = 'builtin.claude';

  /// Channel for the lead (or single) Claude pane's conversation.
  static const leadChannel = 'conversation';

  /// Channel for a teammate's conversation (team work, T-139/T-140).
  static String teammateChannel(String agentId) => 'conversation/$agentId';

  /// Key under which the [ConversationItem] travels in a [Message]'s data.
  static const itemKey = 'item';
}

class TranscriptPublisher {
  /// Starts republishing [reader]'s items onto [messages] under
  /// [ClaudeConversation.publisher] / [channel]. The subscription is
  /// attached synchronously, so a controller that subscribes before the
  /// reader's first poll never misses the initial tail.
  TranscriptPublisher({
    required MessageBus messages,
    required TranscriptReader reader,
    this.channel = ClaudeConversation.leadChannel,
  })  : _messages = messages,
        _reader = reader {
    _sub = _reader.stream.listen((item) {
      _messages.publish(ClaudeConversation.publisher, channel, {
        ClaudeConversation.itemKey: item,
      });
    });
  }

  final MessageBus _messages;
  final TranscriptReader _reader;
  final String channel;
  late final StreamSubscription<ConversationItem> _sub;

  /// Stops publishing and tears down the underlying reader.
  Future<void> dispose() async {
    await _sub.cancel();
    await _reader.dispose();
  }
}
