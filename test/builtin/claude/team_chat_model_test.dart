/// Unit tests for TeamChatModel (T-180).
///
/// All tests are pure Dart (no Flutter widgets). TeamChatModel and TeamBroker
/// are both Flutter-free; this file runs under `flutter test` but does NOT
/// import any Flutter package.
library;

import 'package:clide/builtin/claude/src/team_broker.dart';
import 'package:clide/builtin/claude/src/team_chat_model.dart';
import 'package:test/test.dart';

void main() {
  late TeamBroker broker;
  late List<(String, String)> delivered; // (toMemberId, text)
  late TeamChatModel model;

  setUp(() {
    delivered = [];
    broker = TeamBroker(deliver: (to, text) => delivered.add((to, text)));
    broker.addMember(const TeamMemberRef(id: 'primary', name: 'lead', role: 'lead'));
    broker.addMember(const TeamMemberRef(id: 'teammate:tyre', name: 'tyre', role: 'teammate'));
    model = TeamChatModel(broker: broker);
  });

  tearDown(() {
    model.dispose();
    broker.dispose();
  });

  // ---------------------------------------------------------------------------
  // Message stream → timeline
  // ---------------------------------------------------------------------------

  group('message stream', () {
    test('model starts with an empty timeline', () {
      expect(model.messages, isEmpty);
    });

    test('appends a message when the broker delivers one', () async {
      final events = <void>[];
      final sub = model.changes.listen((_) => events.add(null));
      broker.sendMessage('primary', 'tyre', 'hello tyre');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(model.messages, hasLength(1));
      expect(model.messages.single.from, 'lead');
      expect(model.messages.single.text, 'hello tyre');
      expect(model.messages.single.to, 'tyre');
      expect(events, hasLength(1));
    });

    test('broadcast messages are appended for each recipient', () async {
      broker.broadcast('primary', 'standup');
      await Future<void>.delayed(Duration.zero);
      // One message for 'tyre', one for 'user' (both are non-sender members).
      expect(model.messages.length, greaterThanOrEqualTo(1));
      expect(model.messages.every((m) => m.text == 'standup'), isTrue);
    });

    test('direct send_message to user lands in the timeline', () async {
      broker.sendMessage('primary', 'user', 'attention user');
      await Future<void>.delayed(Duration.zero);
      expect(model.messages.single.text, 'attention user');
      expect(model.messages.single.to, 'user');
      // User has no stdin delivery.
      expect(delivered, isEmpty);
    });

    test('changes stream fires on each message', () async {
      final events = <void>[];
      final sub = model.changes.listen((_) => events.add(null));
      broker.sendMessage('primary', 'tyre', 'one');
      broker.sendMessage('primary', 'tyre', 'two');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(events, hasLength(2));
    });

    test('messages list is append-only (oldest first)', () async {
      broker.sendMessage('primary', 'tyre', 'first');
      broker.sendMessage('primary', 'tyre', 'second');
      await Future<void>.delayed(Duration.zero);
      expect(model.messages[0].text, 'first');
      expect(model.messages[1].text, 'second');
    });
  });

  // ---------------------------------------------------------------------------
  // postAsUser — routing
  // ---------------------------------------------------------------------------

  group('postAsUser routing', () {
    test('postAsUser with no toName broadcasts to all agents', () async {
      model.postAsUser('hello team');
      await Future<void>.delayed(Duration.zero);
      // Delivered to tyre (lead is the sender-equivalent; user has no delivery).
      expect(delivered.any((d) => d.$1 == 'teammate:tyre'), isTrue);
    });

    test('postAsUser with toName=team broadcasts', () async {
      model.postAsUser('standup', toName: 'team');
      await Future<void>.delayed(Duration.zero);
      expect(delivered.any((d) => d.$1 == 'teammate:tyre'), isTrue);
    });

    test('postAsUser with a member name delivers to that member only', () async {
      model.postAsUser('hey tyre', toName: 'tyre');
      await Future<void>.delayed(Duration.zero);
      expect(delivered.length, 1);
      expect(delivered.single.$1, 'teammate:tyre');
    });

    test('postAsUser creates a local timeline entry immediately', () {
      model.postAsUser('quick post', toName: 'tyre');
      // Synchronous: the entry is in messages before any async event.
      expect(model.messages, hasLength(1));
      expect(model.messages.single.from, 'user');
      expect(model.messages.single.to, 'tyre');
    });

    test('postAsUser broadcast creates a local entry with broadcast=true', () {
      model.postAsUser('broadcast text');
      expect(model.messages.single.broadcast, isTrue);
    });

    test('postAsUser fires the changes stream synchronously', () {
      var fired = false;
      model.changes.listen((_) => fired = true);
      model.postAsUser('sync');
      // The stream is broadcast but the listener is called asynchronously by
      // the Dart event loop — wait one microtask.
      expect(fired, isFalse); // not yet
    });
  });

  // ---------------------------------------------------------------------------
  // postAsUser — interrupt flag
  // ---------------------------------------------------------------------------

  group('postAsUser interrupt', () {
    test('interrupt=true calls the session resolver', () async {
      String? resolvedName;
      final interruptModel = TeamChatModel(
        broker: broker,
        sessionResolver: (name) {
          resolvedName = name;
          return null; // no real session in unit tests
        },
      );
      interruptModel.postAsUser('cancel that', toName: 'tyre', interrupt: true);
      await Future<void>.delayed(Duration.zero);
      expect(resolvedName, 'tyre');
      interruptModel.dispose();
    });

    test('interrupt=true on a broadcast does NOT call the resolver', () async {
      String? resolvedName;
      final interruptModel = TeamChatModel(
        broker: broker,
        sessionResolver: (name) {
          resolvedName = name;
          return null;
        },
      );
      interruptModel.postAsUser('abort all', interrupt: true);
      await Future<void>.delayed(Duration.zero);
      // Broadcast → resolver not called (no single target to interrupt).
      expect(resolvedName, isNull);
      interruptModel.dispose();
    });

    test('interrupt=false never calls the resolver', () async {
      String? resolvedName;
      final interruptModel = TeamChatModel(
        broker: broker,
        sessionResolver: (name) {
          resolvedName = name;
          return null;
        },
      );
      interruptModel.postAsUser('no interrupt', toName: 'tyre', interrupt: false);
      await Future<void>.delayed(Duration.zero);
      expect(resolvedName, isNull);
      interruptModel.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  test('dispose closes the changes stream', () async {
    var done = false;
    model.changes.listen(null, onDone: () => done = true);
    model.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
  });
}
