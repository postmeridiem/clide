import 'dart:async';

class Message {
  Message({
    required this.publisher,
    required this.channel,
    required this.data,
  }) : timestamp = DateTime.now();

  final String publisher;
  final String channel;
  final DateTime timestamp;
  final Map<String, Object?> data;

  String get address => '$publisher/$channel';
}

class MessageBus {
  final _controller = StreamController<Message>.broadcast();

  void publish(String publisher, String channel, Map<String, Object?> data) {
    _controller.add(Message(publisher: publisher, channel: channel, data: data));
  }

  Stream<Message> subscribe({String? publisher, String? channel}) {
    return _controller.stream.where((m) {
      if (publisher != null && m.publisher != publisher) return false;
      if (channel != null && m.channel != channel) return false;
      return true;
    });
  }

  void dispose() {
    _controller.close();
  }
}
