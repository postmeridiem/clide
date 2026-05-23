/// Tests for TranscriptReader (pure-Dart, no Flutter).
///
/// Uses a snapshotted JSONL fixture written to a temp directory so tests are
/// hermetic and never depend on real Claude transcript files.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

/// Write [lines] to [file], each JSON-encoded, newline-terminated.
void writeLines(File file, List<Map<String, dynamic>> lines) {
  file.writeAsStringSync(
    '${lines.map(jsonEncode).join('\n')}\n',
    mode: FileMode.writeOnly,
  );
}

/// Append [lines] to [file].
void appendLines(File file, List<Map<String, dynamic>> lines) {
  file.writeAsStringSync(
    '${lines.map(jsonEncode).join('\n')}\n',
    mode: FileMode.append,
  );
}

/// Poll [ready] until it returns true or [timeout] elapses. Streaming
/// assertions use this instead of a fixed delay so they don't flake under
/// load (the reader polls on a timer and may parse off-isolate).
Future<void> pumpUntil(
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// JSONL envelope skeleton with default sentinel values.
Map<String, dynamic> envelope({
  required String type,
  required String uuid,
  Map<String, dynamic>? message,
  String parentUuid = '',
  bool isSidechain = false,
  String version = '2.1.143',
  String timestamp = '2026-05-16T08:53:06.708Z',
}) {
  return {
    'type': type,
    'uuid': uuid,
    'parentUuid': parentUuid,
    'isSidechain': isSidechain,
    'version': version,
    'timestamp': timestamp,
    if (message != null) 'message': message,
  };
}

/// Build a `user` envelope whose content is a plain string.
Map<String, dynamic> userText(String uuid, String text) {
  return envelope(
    type: 'user',
    uuid: uuid,
    message: {'role': 'user', 'content': text},
  );
}

/// Build a `user` envelope whose content is an array of text parts.
Map<String, dynamic> userTextArray(String uuid, List<String> parts) {
  return envelope(
    type: 'user',
    uuid: uuid,
    message: {
      'role': 'user',
      'content': [
        for (final p in parts) {'type': 'text', 'text': p}
      ],
    },
  );
}

/// Build a `user` envelope containing a tool_result.
Map<String, dynamic> userToolResult(
  String uuid, {
  required String toolUseId,
  required String content,
  bool isError = false,
}) {
  return envelope(
    type: 'user',
    uuid: uuid,
    message: {
      'role': 'user',
      'content': [
        {
          'type': 'tool_result',
          'tool_use_id': toolUseId,
          'content': content,
          'is_error': isError,
        }
      ],
    },
  );
}

/// Build an `assistant` envelope with a tool_use content block.
Map<String, dynamic> assistantToolUse(
  String uuid, {
  required String id,
  required String name,
  required Map<String, dynamic> input,
}) {
  return envelope(
    type: 'assistant',
    uuid: uuid,
    message: {
      'role': 'assistant',
      'content': [
        {'type': 'tool_use', 'id': id, 'name': name, 'input': input},
      ],
    },
  );
}

/// Build an `assistant` envelope with a text content block.
Map<String, dynamic> assistantText(String uuid, String text) {
  return envelope(
    type: 'assistant',
    uuid: uuid,
    message: {
      'role': 'assistant',
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
  );
}

/// Build an `assistant` envelope with a thinking content block.
Map<String, dynamic> assistantThinking(String uuid, String thinking) {
  return envelope(
    type: 'assistant',
    uuid: uuid,
    message: {
      'role': 'assistant',
      'content': [
        {'type': 'thinking', 'thinking': thinking},
      ],
    },
  );
}

/// A skip-type record.
Map<String, dynamic> skipRecord(String type, String uuid) {
  return {'type': type, 'uuid': uuid, 'timestamp': '2026-05-16T08:53:06.708Z'};
}

// ---------------------------------------------------------------------------
// Synchronous parse helper — uses the REAL TranscriptReader.parseLine
// ---------------------------------------------------------------------------

/// Parses [lines] synchronously via the real [TranscriptReader.parseLine] and
/// returns every emitted [ConversationItem].
List<ConversationItem> parseAll(
  List<Map<String, dynamic>> lines, {
  void Function(String)? onWarn,
}) {
  final reader = TranscriptReader('/fake', onWarn: onWarn);
  return [for (final l in lines) ...reader.parseLine(jsonEncode(l))];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  group('ConversationItem model', () {
    test('UserMessage holds text and metadata', () {
      final item = UserMessage(
        uuid: 'u1',
        timestamp: _epoch,
        isSidechain: false,
        text: 'hello',
      );
      expect(item.uuid, 'u1');
      expect(item.text, 'hello');
      expect(item.isSidechain, isFalse);
      expect(item.toString(), contains('UserMessage'));
    });

    test('AssistantTextMessage holds text', () {
      final item = AssistantTextMessage(
        uuid: 'a1',
        timestamp: _epoch,
        isSidechain: false,
        text: 'world',
      );
      expect(item.text, 'world');
    });

    test('AssistantThinkingMessage holds thinking', () {
      final item = AssistantThinkingMessage(
        uuid: 't1',
        timestamp: _epoch,
        isSidechain: false,
        thinking: 'pondering',
      );
      expect(item.thinking, 'pondering');
    });

    test('AssistantToolUse holds name and input', () {
      final item = AssistantToolUse(
        uuid: 'tu1',
        timestamp: _epoch,
        isSidechain: false,
        toolUseId: 'toolu_001',
        name: 'Bash',
        input: const {'command': 'ls'},
      );
      expect(item.name, 'Bash');
      expect(item.input['command'], 'ls');
      expect(item.toString(), contains('Bash'));
    });

    test('ToolResultMessage holds content and error flag', () {
      final item = ToolResultMessage(
        uuid: 'r1',
        timestamp: _epoch,
        isSidechain: false,
        toolUseId: 'toolu_001',
        content: 'ok',
        isError: false,
      );
      expect(item.content, 'ok');
      expect(item.isError, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('TranscriptReader — path munging', () {
    test('mungedDir replaces slashes with dashes and keeps leading dash', () {
      // The munging rule (path '/' -> '-') is verified directly here; the
      // real reader's directory resolution is exercised end-to-end by the
      // file-discovery / streaming tests below (via projectsBase).
      final munged = '/var/mnt/foo'.replaceAll('/', '-');
      expect(munged, '-var-mnt-foo');
    });

    test('munged dir has leading dash for absolute paths', () {
      final munged = '/home/user/project'.replaceAll('/', '-');
      expect(munged, startsWith('-'));
    });
  });

  // -------------------------------------------------------------------------
  group('TranscriptReader — parse: skip types', () {
    test('skips attachment, system, last-prompt, permission-mode, file-history-snapshot, queue-operation', () {
      final skipTypes = [
        'attachment',
        'system',
        'last-prompt',
        'permission-mode',
        'file-history-snapshot',
        'queue-operation',
      ];
      for (final t in skipTypes) {
        final items = parseAll([skipRecord(t, 'skip-$t')]);
        expect(items, isEmpty, reason: 'type "$t" should be skipped');
      }
    });
  });

  // -------------------------------------------------------------------------
  group('TranscriptReader — parse: user messages', () {
    test('plain string content emits UserMessage', () {
      final items = parseAll([userText('u1', 'hello world')]);
      expect(items, hasLength(1));
      expect(items.first, isA<UserMessage>());
      expect((items.first as UserMessage).text, 'hello world');
    });

    test('array content with text parts emits joined UserMessage', () {
      final items = parseAll([
        userTextArray('u2', ['foo', 'bar'])
      ]);
      expect(items, hasLength(1));
      final msg = items.first as UserMessage;
      expect(msg.text, 'foo\nbar');
    });

    test('array content with tool_result emits ToolResultMessage', () {
      final items = parseAll([
        userToolResult('u3', toolUseId: 'toolu_abc', content: '{"ok":true}'),
      ]);
      expect(items, hasLength(1));
      final res = items.first as ToolResultMessage;
      expect(res.toolUseId, 'toolu_abc');
      expect(res.content, '{"ok":true}');
      expect(res.isError, isFalse);
    });

    test('tool_result with is_error=true sets isError', () {
      final items = parseAll([
        userToolResult('u4', toolUseId: 'toolu_xyz', content: 'boom', isError: true),
      ]);
      final res = items.first as ToolResultMessage;
      expect(res.isError, isTrue);
    });

    test('mixed array: text + tool_result emits both', () {
      final raw = envelope(
        type: 'user',
        uuid: 'u5',
        message: {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'see result'},
            {
              'type': 'tool_result',
              'tool_use_id': 'toolu_mixed',
              'content': 'done',
              'is_error': false,
            },
          ],
        },
      );
      final items = parseAll([raw]);
      // ToolResultMessage emitted first (order of content array), then UserMessage.
      expect(items, hasLength(2));
      expect(items.whereType<ToolResultMessage>(), hasLength(1));
      expect(items.whereType<UserMessage>(), hasLength(1));
    });

    test('empty string content emits nothing', () {
      final items = parseAll([userText('u6', '')]);
      expect(items, isEmpty);
    });

    test('uuid and timestamp are preserved', () {
      final items = parseAll([userText('uuid-abc', 'hi')]);
      expect(items.first.uuid, 'uuid-abc');
      expect(items.first.timestamp, DateTime.parse('2026-05-16T08:53:06.708Z'));
    });

    test('isSidechain flag is preserved', () {
      final raw = envelope(
        type: 'user',
        uuid: 'u7',
        isSidechain: true,
        message: {'role': 'user', 'content': 'side'},
      );
      final items = parseAll([raw]);
      expect(items.first.isSidechain, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('TranscriptReader — parse: assistant messages', () {
    test('text block emits AssistantTextMessage', () {
      final items = parseAll([assistantText('a1', 'here is the answer')]);
      expect(items, hasLength(1));
      final msg = items.first as AssistantTextMessage;
      expect(msg.text, 'here is the answer');
    });

    test('thinking block emits AssistantThinkingMessage', () {
      final items = parseAll([assistantThinking('a2', 'I am thinking...')]);
      expect(items, hasLength(1));
      expect(items.first, isA<AssistantThinkingMessage>());
    });

    test('empty thinking block is not emitted', () {
      final raw = envelope(
        type: 'assistant',
        uuid: 'a3',
        message: {
          'role': 'assistant',
          'content': [
            {'type': 'thinking', 'thinking': ''},
          ],
        },
      );
      final items = parseAll([raw]);
      expect(items, isEmpty);
    });

    test('tool_use block emits AssistantToolUse', () {
      final items = parseAll([
        assistantToolUse(
          'a4',
          id: 'toolu_001',
          name: 'Bash',
          input: {'command': 'ls -la', 'description': 'List files'},
        ),
      ]);
      expect(items, hasLength(1));
      final tu = items.first as AssistantToolUse;
      expect(tu.name, 'Bash');
      expect(tu.toolUseId, 'toolu_001');
      expect(tu.input['command'], 'ls -la');
    });

    test('mixed assistant turn emits multiple items in order', () {
      final raw = envelope(
        type: 'assistant',
        uuid: 'a5',
        message: {
          'role': 'assistant',
          'content': [
            {'type': 'thinking', 'thinking': 'working...'},
            {'type': 'text', 'text': 'I will run a command'},
            {
              'type': 'tool_use',
              'id': 'toolu_002',
              'name': 'Read',
              'input': {'file_path': '/foo'}
            },
          ],
        },
      );
      final items = parseAll([raw]);
      expect(items, hasLength(3));
      expect(items[0], isA<AssistantThinkingMessage>());
      expect(items[1], isA<AssistantTextMessage>());
      expect(items[2], isA<AssistantToolUse>());
    });
  });

  // -------------------------------------------------------------------------
  group('TranscriptReader — parse: snapshot fixture', () {
    /// Canonical fixture: assistant text + tool_use + tool_result + skip-type.
    /// Simulates a real Claude Code conversation turn.
    test('parses snapshot fixture into correct ConversationItems', () {
      final fixture = _snapshotFixture();
      final items = parseAll(fixture);

      // Expected items from fixture (see _snapshotFixture):
      //   1. UserMessage (user turn)
      //   2. AssistantThinkingMessage (thinking block)
      //   3. AssistantToolUse (Bash call)
      //   4. ToolResultMessage (tool result)
      //   5. AssistantTextMessage (final reply)
      // Skip types are not counted.

      expect(items, hasLength(5));
      expect(items[0], isA<UserMessage>());
      expect((items[0] as UserMessage).text, 'what files are here?');

      expect(items[1], isA<AssistantThinkingMessage>());
      expect((items[1] as AssistantThinkingMessage).thinking, contains('need to list'));

      expect(items[2], isA<AssistantToolUse>());
      final tu = items[2] as AssistantToolUse;
      expect(tu.name, 'Bash');
      expect(tu.input['command'], 'ls -la');

      expect(items[3], isA<ToolResultMessage>());
      final tr = items[3] as ToolResultMessage;
      expect(tr.toolUseId, tu.toolUseId);
      expect(tr.content, contains('file.dart'));
      expect(tr.isError, isFalse);

      expect(items[4], isA<AssistantTextMessage>());
      expect((items[4] as AssistantTextMessage).text, contains('file.dart'));
    });
  });

  // -------------------------------------------------------------------------
  group('TranscriptReader — version drift-guard', () {
    test('known versions (1.x, 2.x) produce no warning', () {
      final warnings = <String>[];
      parseAll(
        [userText('u1', 'hello'), assistantText('a1', 'world')],
        onWarn: warnings.add,
      );
      expect(warnings, isEmpty);
    });

    test('unknown major version warns and still emits parseable items', () {
      final warnings = <String>[];
      final raw = envelope(
        type: 'user',
        uuid: 'u1',
        version: '99.0.1',
        message: {'role': 'user', 'content': 'future format'},
      );
      final items = parseAll([raw], onWarn: warnings.add);
      expect(warnings, hasLength(1));
      expect(warnings.first, contains('99'));
      expect(warnings.first, contains('degrade gracefully'));
      // The item still parses — degrade, don't crash.
      expect(items, hasLength(1));
      expect(items.first, isA<UserMessage>());
    });

    test('multiple lines with unknown version warn once per line that has it', () {
      final warnings = <String>[];
      final lines = [
        envelope(type: 'user', uuid: 'u1', version: '5.0.0', message: {'role': 'user', 'content': 'a'}),
        envelope(type: 'user', uuid: 'u2', version: '5.0.0', message: {'role': 'user', 'content': 'b'}),
      ];
      parseAll(lines, onWarn: warnings.add);
      expect(warnings, hasLength(2));
    });

    test('missing version field does not warn', () {
      final warnings = <String>[];
      final raw = <String, dynamic>{
        'type': 'user',
        'uuid': 'u1',
        'isSidechain': false,
        'timestamp': '2026-05-16T08:53:06.708Z',
        'message': {'role': 'user', 'content': 'no version'},
      };
      parseAll([raw], onWarn: warnings.add);
      expect(warnings, isEmpty);
    });

    test('malformed JSON line is skipped without throwing', () {
      expect(
        TranscriptReader('/fake').parseLine('not json!!!'),
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------------------------
  group('SessionStatus (T-145)', () {
    test('parseTranscriptChunk extracts model, permission-mode, context tokens', () {
      final chunk = [
        jsonEncode({'type': 'permission-mode', 'permissionMode': 'plan', 'sessionId': 's'}),
        jsonEncode({
          'type': 'assistant',
          'uuid': 'a1',
          'version': '2.1.143',
          'timestamp': '2026-05-16T08:53:06.708Z',
          'message': {
            'role': 'assistant',
            'model': 'claude-opus-4-7',
            'content': [
              {'type': 'text', 'text': 'hi'}
            ],
            'usage': {
              'input_tokens': 2,
              'cache_read_input_tokens': 1000,
              'cache_creation_input_tokens': 500,
              'output_tokens': 99,
            },
          },
        }),
      ].join('\n');

      final parsed = parseTranscriptChunk(chunk);
      expect(parsed.status.permissionMode, 'plan');
      expect(parsed.status.model, 'claude-opus-4-7');
      expect(parsed.status.contextTokens, 1502); // input 2 + read 1000 + create 500 (not output)
      // The assistant text item is still emitted alongside.
      expect(parsed.items.whereType<AssistantTextMessage>(), hasLength(1));
    });

    test('empty chunk yields an empty status', () {
      expect(parseTranscriptChunk('').status.isEmpty, isTrue);
    });

    test('merge overlays non-null fields only', () {
      const a = SessionStatus(model: 'm1', permissionMode: 'default');
      const b = SessionStatus(permissionMode: 'plan', contextTokens: 10);
      final m = a.merge(b);
      expect(m.model, 'm1'); // kept — b.model is null
      expect(m.permissionMode, 'plan'); // overlaid
      expect(m.contextTokens, 10);
    });

    test('equality compares all fields', () {
      expect(const SessionStatus(model: 'x'), const SessionStatus(model: 'x'));
      expect(const SessionStatus(model: 'x'), isNot(const SessionStatus(model: 'y')));
    });
  });

  group('TranscriptReader — append streaming (filesystem)', () {
    late Directory tempBase;

    /// The workspace path used in all streaming tests.
    const workspace = '/test/workspace';

    /// Resolves the munged project dir inside [base] for [workspacePath].
    Directory mungedDir(Directory base, String workspacePath) {
      final munged = workspacePath.replaceAll('/', '-');
      return Directory('${base.path}/$munged');
    }

    setUp(() async {
      tempBase = await Directory.systemTemp.createTemp('transcript_reader_test_');
    });

    tearDown(() async {
      await tempBase.delete(recursive: true);
    });

    test('initial lines are emitted on first poll', () async {
      final projectDir = mungedDir(tempBase, workspace);
      await projectDir.create(recursive: true);
      final sessionFile = File('${projectDir.path}/session-abc.jsonl');

      writeLines(sessionFile, [
        userText('u1', 'first message'),
        assistantText('a1', 'first reply'),
      ]);

      final reader = TranscriptReader(
        workspace,
        projectsBase: tempBase.path,
        pollInterval: const Duration(milliseconds: 20),
      );
      final collected = <ConversationItem>[];
      final sub = reader.stream.listen(collected.add);

      await pumpUntil(() => collected.whereType<UserMessage>().isNotEmpty && collected.whereType<AssistantTextMessage>().isNotEmpty);

      await sub.cancel();
      await reader.dispose();

      expect(collected.whereType<UserMessage>(), hasLength(1));
      expect(collected.whereType<AssistantTextMessage>(), hasLength(1));
    });

    test('appended lines are emitted without replaying earlier lines', () async {
      final projectDir = mungedDir(tempBase, workspace);
      await projectDir.create(recursive: true);
      final sessionFile = File('${projectDir.path}/session-abc.jsonl');

      writeLines(sessionFile, [userText('u1', 'initial')]);

      final reader = TranscriptReader(
        workspace,
        projectsBase: tempBase.path,
        pollInterval: const Duration(milliseconds: 20),
      );
      final collected = <ConversationItem>[];
      final sub = reader.stream.listen(collected.add);

      // Let the reader consume the initial lines.
      await pumpUntil(() => collected.whereType<UserMessage>().isNotEmpty);
      final countAfterInit = collected.length;

      // Append new lines.
      appendLines(sessionFile, [assistantText('a1', 'appended reply')]);

      // Let the reader pick up the append.
      await pumpUntil(() => collected.whereType<AssistantTextMessage>().isNotEmpty);

      await sub.cancel();
      await reader.dispose();

      expect(collected.length, greaterThan(countAfterInit));
      expect(collected.whereType<AssistantTextMessage>(), hasLength(1));
      // The initial UserMessage was already counted; no duplicates.
      expect(collected.whereType<UserMessage>(), hasLength(1));
    });

    test('session switch: newer file triggers replay from new file start', () async {
      final projectDir = mungedDir(tempBase, workspace);
      await projectDir.create(recursive: true);
      final sessionFile = File('${projectDir.path}/session-abc.jsonl');

      // Write session A and backdate it to a fixed past time. This makes
      // "newest by mtime" deterministic: relying on wall-clock mtimes lets
      // the two files tie under timing pressure, so the reader never
      // switches and the test flakes. A fixed old mtime removes the race.
      writeLines(sessionFile, [userText('u1', 'old session')]);
      await sessionFile.setLastModified(DateTime.utc(2020));

      final reader = TranscriptReader(
        workspace,
        projectsBase: tempBase.path,
        pollInterval: const Duration(milliseconds: 20),
      );
      final collected = <ConversationItem>[];
      final sub = reader.stream.listen(collected.add);

      await pumpUntil(() => collected.whereType<UserMessage>().any((m) => m.text == 'old session'));

      // A newer session file — its mtime (now, then pinned to 2021) is
      // unambiguously after session A's 2020, so the switch is guaranteed.
      final newerFile = File('${projectDir.path}/session-xyz.jsonl');
      writeLines(newerFile, [userText('u2', 'new session')]);
      await newerFile.setLastModified(DateTime.utc(2021));

      await pumpUntil(() => collected.whereType<UserMessage>().any((m) => m.text == 'new session'));

      await sub.cancel();
      await reader.dispose();

      // The reader should have switched to the newer file.
      final userMessages = collected.whereType<UserMessage>().map((m) => m.text).toList();
      expect(userMessages, contains('new session'));
    });

    test('skip types in a real file are not emitted', () async {
      final projectDir = mungedDir(tempBase, workspace);
      await projectDir.create(recursive: true);
      final sessionFile = File('${projectDir.path}/session-abc.jsonl');

      writeLines(sessionFile, [
        skipRecord('last-prompt', 'skip1'),
        skipRecord('attachment', 'skip2'),
        userText('u1', 'real message'),
        skipRecord('system', 'skip3'),
      ]);

      final reader = TranscriptReader(
        workspace,
        projectsBase: tempBase.path,
        pollInterval: const Duration(milliseconds: 20),
      );
      final collected = <ConversationItem>[];
      final sub = reader.stream.listen(collected.add);

      await pumpUntil(() => collected.isNotEmpty);

      await sub.cancel();
      await reader.dispose();

      expect(collected, hasLength(1));
      expect((collected.first as UserMessage).text, 'real message');
    });

    test('initial attach reads only the recent tail (initialTailBytes cap)', () async {
      final projectDir = mungedDir(tempBase, workspace);
      await projectDir.create(recursive: true);
      final sessionFile = File('${projectDir.path}/session-abc.jsonl');

      // A long pre-existing transcript — the kind that froze the UI when
      // parsed in full on attach.
      writeLines(sessionFile, [
        for (var i = 0; i < 200; i++) assistantText('a$i', 'reply number $i'),
      ]);

      // Cap the initial read well below the file size so only the last
      // records are within the tail window.
      final reader = TranscriptReader(
        workspace,
        projectsBase: tempBase.path,
        pollInterval: const Duration(milliseconds: 20),
        initialTailBytes: 256,
      );
      final collected = <ConversationItem>[];
      final sub = reader.stream.listen(collected.add);

      await pumpUntil(() => collected.isNotEmpty);

      await sub.cancel();
      await reader.dispose();

      // Far fewer than the 200 records — only the recent tail was read.
      expect(collected, isNotEmpty);
      expect(collected.length, lessThan(200));
      // The most recent record is always intact at the end of the file.
      expect(
        collected.whereType<AssistantTextMessage>().last.text,
        'reply number 199',
      );
    });

    test('explicit file: tails that exact file, ignoring newest-discovery', () async {
      // A teammate reader (T-139) points at one fixed subagent file rather
      // than the newest .jsonl in the munged dir.
      final dir = await Directory.systemTemp.createTemp('explicit_file_');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/agent-abc.jsonl');
      writeLines(target, [assistantText('a1', 'from the explicit file')]);

      final reader = TranscriptReader(
        '/unused/workspace',
        projectsBase: '/nonexistent',
        pollInterval: const Duration(milliseconds: 20),
        file: target.path,
      );
      final collected = <ConversationItem>[];
      final sub = reader.stream.listen(collected.add);

      await pumpUntil(() => collected.isNotEmpty);

      await sub.cancel();
      await reader.dispose();

      expect(collected.whereType<AssistantTextMessage>().single.text, 'from the explicit file');
    });

    test('explicit file: waits without error until the file appears', () async {
      // claude writes <session-id>.jsonl shortly after spawn (T-146); the
      // reader must poll without throwing until it exists, then stream it.
      final dir = await Directory.systemTemp.createTemp('late_file_');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/agent-late.jsonl');

      final reader = TranscriptReader(
        '/unused',
        projectsBase: '/nonexistent',
        pollInterval: const Duration(milliseconds: 20),
        file: target.path,
      );
      final collected = <ConversationItem>[];
      final sub = reader.stream.listen(collected.add);

      // Let it poll a few times against the missing file — must not throw.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(collected, isEmpty);

      // Now the file appears.
      writeLines(target, [assistantText('a1', 'arrived late')]);
      await pumpUntil(() => collected.isNotEmpty);

      await sub.cancel();
      await reader.dispose();
      expect(collected.whereType<AssistantTextMessage>().single.text, 'arrived late');
    });

    test('statusStream emits model / permission-mode / context tokens', () async {
      final projectDir = mungedDir(tempBase, workspace);
      await projectDir.create(recursive: true);
      File('${projectDir.path}/session-abc.jsonl').writeAsStringSync(
        '${[
          jsonEncode({'type': 'permission-mode', 'permissionMode': 'acceptEdits', 'sessionId': 's'}),
          jsonEncode({
            'type': 'assistant',
            'uuid': 'a1',
            'version': '2.1.143',
            'timestamp': '2026-05-16T08:53:06.708Z',
            'message': {
              'role': 'assistant',
              'model': 'claude-sonnet-4-6',
              'content': [
                {'type': 'text', 'text': 'hi'}
              ],
              'usage': {'input_tokens': 5, 'cache_read_input_tokens': 200, 'cache_creation_input_tokens': 0, 'output_tokens': 10},
            },
          }),
        ].join('\n')}\n',
      );

      final reader = TranscriptReader(workspace, projectsBase: tempBase.path, pollInterval: const Duration(milliseconds: 20));
      final statuses = <SessionStatus>[];
      final sub = reader.statusStream.listen(statuses.add);

      await pumpUntil(() => statuses.isNotEmpty && statuses.last.model != null && statuses.last.permissionMode != null);

      await sub.cancel();
      await reader.dispose();
      expect(statuses.last.permissionMode, 'acceptEdits');
      expect(statuses.last.model, 'claude-sonnet-4-6');
      expect(statuses.last.contextTokens, 205);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _epoch = DateTime.utc(2026, 5, 16, 8, 53, 6);

/// Canonical snapshot fixture representing a full conversation turn.
List<Map<String, dynamic>> _snapshotFixture() {
  const toolUseId = 'toolu_fixture_001';
  return [
    // skip type — must not appear in output
    skipRecord('last-prompt', 'skip-0'),

    // user turn — plain string
    userText('u-001', 'what files are here?'),

    // skip type inside the sequence
    skipRecord('permission-mode', 'skip-1'),

    // assistant turn — thinking + tool_use
    envelope(
      type: 'assistant',
      uuid: 'a-001',
      message: {
        'role': 'assistant',
        'content': [
          {'type': 'thinking', 'thinking': 'I need to list the directory to answer.'},
          {
            'type': 'tool_use',
            'id': toolUseId,
            'name': 'Bash',
            'input': {'command': 'ls -la'}
          },
        ],
      },
    ),

    // tool result (user turn)
    userToolResult(
      'u-002',
      toolUseId: toolUseId,
      content: 'total 4\n-rw-r--r-- file.dart',
    ),

    // assistant text reply
    assistantText('a-002', 'The directory contains file.dart.'),

    // another skip type at the end
    skipRecord('file-history-snapshot', 'skip-2'),
  ];
}
