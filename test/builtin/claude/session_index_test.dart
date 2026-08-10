import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/session_index.dart';
import 'package:clide/builtin/claude/src/session_naming.dart';
import 'package:test/test.dart';

String userLine(String text) => jsonEncode({
  'type': 'user',
  'message': {'role': 'user', 'content': text},
});

String userBlocksLine(String text) => jsonEncode({
  'type': 'user',
  'message': {
    'role': 'user',
    'content': [
      {'type': 'text', 'text': text},
    ],
  },
});

String toolResultLine() => jsonEncode({
  'type': 'user',
  'message': {
    'role': 'user',
    'content': [
      {'type': 'tool_result', 'content': 'output'},
    ],
  },
});

String assistantLine(String text) => jsonEncode({
  'type': 'assistant',
  'message': {
    'role': 'assistant',
    'content': [
      {'type': 'text', 'text': text},
    ],
  },
});

void main() {
  group('userText', () {
    test('extracts string and text-block content', () {
      expect(userText(jsonDecode(userLine('hello')) as Map<String, Object?>), 'hello');
      expect(userText(jsonDecode(userBlocksLine('blocky')) as Map<String, Object?>), 'blocky');
    });

    test('ignores tool-result-only user records and non-user records', () {
      expect(userText(jsonDecode(toolResultLine()) as Map<String, Object?>), isNull);
      expect(userText(jsonDecode(assistantLine('hi')) as Map<String, Object?>), isNull);
    });
  });

  group('listSessions', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('session_index_test'));
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<void> writeSession(String id, List<String> lines) async {
      await File('${dir.path}/$id.jsonl').writeAsString('${lines.join('\n')}\n');
    }

    test('empty / missing dir yields no sessions', () async {
      expect(await listSessions(dir), isEmpty);
      expect(await listSessions(Directory('${dir.path}/nope')), isEmpty);
    });

    group('companion transcripts (T-545)', () {
      test('are listed by default, so anything measuring disk sees the truth', () async {
        await writeSession(companionSessionId(), [userLine('a digest')]);
        expect(await listSessions(dir), hasLength(1));
      });

      test('are excluded on request, which is what the /resume picker asks for', () async {
        await writeSession(companionSessionId(), [userLine('a digest')]);
        await writeSession(freshSessionId(), [userLine('real work')]);

        final picker = await listSessions(dir, includeCompanions: false);

        expect(picker, hasLength(1));
        expect(picker.single.firstUser, 'real work');
      });

      test('are dropped before the cap, not after', () async {
        // The reason the filter lives in listSessions rather than at the call
        // site: clide writes one companion transcript per run, so filtering a
        // capped list would let a busy week push every real session off the end.
        for (var i = 0; i < 4; i++) {
          await writeSession(companionSessionId(), [userLine('digest $i')]);
        }
        await writeSession(freshSessionId(), [userLine('real work')]);

        final picker = await listSessions(dir, max: 3, includeCompanions: false);

        expect(picker.map((s) => s.firstUser), contains('real work'));
      });
    });

    test('summarises each session with first … last bookends', () async {
      await writeSession('aaaa', [userLine('start the swallow'), assistantLine('ok'), toolResultLine(), userLine('now the peacock')]);
      final sessions = await listSessions(dir);
      expect(sessions, hasLength(1));
      expect(sessions.single.id, 'aaaa');
      expect(sessions.single.firstUser, 'start the swallow');
      expect(sessions.single.lastUser, 'now the peacock');
      expect(sessions.single.label, 'start the swallow … now the peacock');
    });

    test('a single-prompt session labels without an ellipsis', () async {
      await writeSession('bbbb', [userLine('only one'), assistantLine('reply')]);
      expect((await listSessions(dir)).single.label, 'only one');
    });

    test('orders most-recently-modified first', () async {
      await writeSession('old', [userLine('older')]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await writeSession('new', [userLine('newer')]);
      final sessions = await listSessions(dir);
      expect(sessions.map((s) => s.id), ['new', 'old']);
      // Defensive: timestamps are non-increasing regardless of FS granularity.
      for (var i = 1; i < sessions.length; i++) {
        expect(sessions[i - 1].modified.isBefore(sessions[i].modified), isFalse);
      }
    });

    test('reads the last user prompt from the tail of a large transcript', () async {
      final lines = [
        userLine('the very first prompt'),
        for (var i = 0; i < 50; i++) assistantLine('filler line number $i to push past the window'),
        userLine('the very last prompt'),
      ];
      await writeSession('big', lines);
      // Tiny window forces the head/tail split path.
      final sessions = await listSessions(dir, window: 256);
      expect(sessions.single.firstUser, 'the very first prompt');
      expect(sessions.single.lastUser, 'the very last prompt');
    });

    test('sizeBytes folds the transcript and its subagents dir (T-148)', () async {
      final main = '${userLine('hi')}\n';
      await File('${dir.path}/sz.jsonl').writeAsString(main);
      final subDir = Directory('${dir.path}/sz/subagents')..createSync(recursive: true);
      const subBody = 'agent transcript bytes';
      await File('${subDir.path}/agent-1.jsonl').writeAsString(subBody);

      final s = (await listSessions(dir)).single;
      expect(s.sizeBytes, main.length + subBody.length);
    });
  });

  group('deleteSession', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('session_del_test'));
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('removes the transcript and its subagents dir', () async {
      await File('${dir.path}/del.jsonl').writeAsString('x');
      Directory('${dir.path}/del/subagents').createSync(recursive: true);
      await File('${dir.path}/del/subagents/a.jsonl').writeAsString('y');

      await deleteSession(dir, 'del');
      expect(File('${dir.path}/del.jsonl').existsSync(), isFalse);
      expect(Directory('${dir.path}/del').existsSync(), isFalse);
    });

    test('rejects ids that could escape the dir', () async {
      expect(() => deleteSession(dir, '../evil'), throwsArgumentError);
      expect(() => deleteSession(dir, 'a/b'), throwsArgumentError);
      expect(() => deleteSession(dir, ''), throwsArgumentError);
    });
  });

  group('formatBytes', () {
    test('scales B / KB / MB / GB', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes((1.5 * 1024 * 1024).round()), '1.5 MB');
      expect(formatBytes((2 * 1024 * 1024 * 1024).round()), '2.0 GB');
    });
  });
}
