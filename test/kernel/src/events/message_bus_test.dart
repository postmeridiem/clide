/// Unit tests for `MessageBus` in `lib/kernel/src/events/message_bus.dart`.
library;

import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Message', () {
    test('address joins publisher and channel with a slash', () {
      final m = Message(publisher: 'pty', channel: 'output', data: const {});
      expect(m.address, 'pty/output');
    });

    test('timestamp is set at construction', () {
      final before = DateTime.now();
      final m = Message(publisher: 'p', channel: 'c', data: const {});
      final after = DateTime.now();
      expect(m.timestamp.isBefore(before), isFalse);
      expect(m.timestamp.isAfter(after), isFalse);
    });
  });

  group('MessageBus', () {
    late MessageBus bus;

    setUp(() => bus = MessageBus());
    tearDown(() => bus.dispose());

    test('publish delivers to every subscriber', () async {
      final received = <Message>[];
      final sub = bus.subscribe().listen(received.add);
      bus.publish('git', 'status-changed', {'dirty': true});
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      expect(received.first.publisher, 'git');
      expect(received.first.channel, 'status-changed');
      expect(received.first.data, {'dirty': true});
      await sub.cancel();
    });

    test('subscribe filter by publisher narrows the stream', () async {
      final got = <Message>[];
      final sub = bus.subscribe(publisher: 'git').listen(got.add);
      bus.publish('git', 'a', const {});
      bus.publish('pty', 'a', const {});
      bus.publish('git', 'b', const {});
      await Future<void>.delayed(Duration.zero);
      expect(got.map((m) => m.channel), ['a', 'b']);
      await sub.cancel();
    });

    test('subscribe filter by channel narrows the stream', () async {
      final got = <Message>[];
      final sub = bus.subscribe(channel: 'output').listen(got.add);
      bus.publish('pty', 'output', const {});
      bus.publish('pty', 'exit', const {});
      bus.publish('git', 'output', const {});
      await Future<void>.delayed(Duration.zero);
      expect(got.map((m) => m.publisher), ['pty', 'git']);
      await sub.cancel();
    });

    test('subscribe with both filters intersects them', () async {
      final got = <Message>[];
      final sub = bus.subscribe(publisher: 'git', channel: 'status').listen(got.add);
      bus.publish('git', 'status', const {});
      bus.publish('git', 'other', const {});
      bus.publish('pty', 'status', const {});
      await Future<void>.delayed(Duration.zero);
      expect(got, hasLength(1));
      await sub.cancel();
    });
  });
}
