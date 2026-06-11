/// Tests for TranscriptPublisher — bridges a TranscriptReader onto the
/// kernel MessageBus (T-137/D-75). Pure Dart: MessageBus + reader have no
/// Flutter dependency, so this runs under `package:test`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/transcript_publisher.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/kernel/src/events/message_bus.dart';
import 'package:test/test.dart';

Map<String, dynamic> _userLine(String uuid, String text) => {
  'type': 'user',
  'uuid': uuid,
  'parentUuid': '',
  'isSidechain': false,
  'version': '2.1.143',
  'timestamp': '2026-05-16T08:53:06.708Z',
  'message': {'role': 'user', 'content': text},
};

Map<String, dynamic> _asstLine(String uuid, String text) => {
  'type': 'assistant',
  'uuid': uuid,
  'parentUuid': '',
  'isSidechain': false,
  'version': '2.1.143',
  'timestamp': '2026-05-16T08:53:07.708Z',
  'message': {
    'role': 'assistant',
    'content': [
      {'type': 'text', 'text': text},
    ],
  },
};

void main() {
  group('TranscriptPublisher', () {
    late Directory base;
    const workspace = '/pub/ws';

    setUp(() async => base = await Directory.systemTemp.createTemp('transcript_publisher_test_'));
    tearDown(() async => base.delete(recursive: true));

    // Serialized: this MessageBus republish assertion is timing-sensitive and
    // flaked in the parallel flutter pool; runs in the --concurrency=1 pass (T-193).
    test('republishes reader items onto the bus (lead channel + item key)', tags: ['serial'], () async {
      final dir = Directory('${base.path}/${workspace.replaceAll('/', '-')}');
      await dir.create(recursive: true);
      File('${dir.path}/session-abc.jsonl').writeAsStringSync('${[_userLine('u1', 'hello'), _asstLine('a1', 'hi there')].map(jsonEncode).join('\n')}\n');

      final bus = MessageBus();
      addTearDown(bus.dispose);
      final received = <Message>[];
      // Subscribe before the publisher starts the reader's first poll.
      final sub = bus.subscribe(publisher: ClaudeConversation.publisher, channel: ClaudeConversation.leadChannel).listen(received.add);

      final reader = TranscriptReader(workspace, projectsBase: base.path, pollInterval: const Duration(milliseconds: 20));
      final pub = TranscriptPublisher(messages: bus, reader: reader);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      await pub.dispose();

      expect(received, hasLength(2));
      expect(received.every((m) => m.data[ClaudeConversation.itemKey] is ConversationItem), isTrue);
      final items = received.map((m) => m.data[ClaudeConversation.itemKey]).toList();
      expect(items.first, isA<UserMessage>());
      expect((items.first as UserMessage).text, 'hello');
      expect(items[1], isA<AssistantTextMessage>());
    });

    test('teammateChannel namespaces by agentId', () {
      expect(ClaudeConversation.teammateChannel('coder@team-x'), 'conversation/coder@team-x');
    });

    test('memberStatusData encodes agentId + present status fields (T-157)', () {
      final full = ClaudeConversation.memberStatusData(
        'coder@team-x',
        const SessionStatus(model: 'claude-opus-4-7', permissionMode: 'plan', contextTokens: 21000),
      );
      expect(full, {'agentId': 'coder@team-x', 'model': 'claude-opus-4-7', 'permissionMode': 'plan', 'contextTokens': 21000});
      // Absent fields are omitted (only agentId is always present).
      expect(ClaudeConversation.memberStatusData('a', const SessionStatus()), {'agentId': 'a'});
    });
  });
}
