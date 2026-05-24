import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:test/test.dart';

class _FakeProc implements StreamJsonProcess {
  final _ctl = StreamController<String>();
  final List<String> writes = [];
  bool killed = false;

  @override
  Stream<String> get lines => _ctl.stream;
  @override
  void writeLine(String line) => writes.add(line);
  @override
  Future<void> kill() async => killed = true;

  void emit(String line) => _ctl.add(line);
}

String assistantText(String text) => jsonEncode({
      'type': 'assistant',
      'uuid': 'a1',
      'message': {
        'model': 'claude-opus-4-7',
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': text},
        ],
        'usage': {'input_tokens': 100, 'cache_read_input_tokens': 50, 'cache_creation_input_tokens': 0},
      },
    });

String assistantToolUse() => jsonEncode({
      'type': 'assistant',
      'uuid': 'a2',
      'message': {
        'role': 'assistant',
        'content': [
          {
            'type': 'tool_use',
            'id': 't1',
            'name': 'Bash',
            'input': {'command': 'ls'}
          },
        ],
      },
    });

String initEvent() => jsonEncode({
      'type': 'system',
      'subtype': 'init',
      'model': 'claude-opus-4-7',
      'permissionMode': 'default',
    });

void main() {
  late _FakeProc proc;
  late StreamJsonSession session;
  late List<ConversationItem> items;
  late List<SessionStatus> statuses;

  setUp(() {
    proc = _FakeProc();
    session = StreamJsonSession(proc);
    items = [];
    statuses = [];
    session.items.listen(items.add);
    session.statusStream.listen(statuses.add);
    session.start();
  });

  tearDown(() => session.dispose());

  test('parses assistant text + tool_use events into items', () async {
    proc.emit(assistantText('hello there'));
    proc.emit(assistantToolUse());
    await Future<void>.delayed(Duration.zero);

    expect(items, hasLength(2));
    expect(items[0], isA<AssistantTextMessage>());
    expect((items[0] as AssistantTextMessage).text, 'hello there');
    expect(items[1], isA<AssistantToolUse>());
    final tu = items[1] as AssistantToolUse;
    expect(tu.name, 'Bash');
    expect(tu.toolUseId, 't1');
    expect(tu.input['command'], 'ls');
  });

  test('derives status: model + tokens from assistant, permission-mode from init', () async {
    proc.emit(initEvent());
    proc.emit(assistantText('hi'));
    await Future<void>.delayed(Duration.zero);

    expect(statuses.last.model, 'claude-opus-4-7');
    expect(statuses.last.permissionMode, 'default');
    expect(statuses.last.contextTokens, 150); // 100 + 50 + 0
  });

  test('only emits status on change', () async {
    proc.emit(initEvent());
    proc.emit(initEvent()); // identical → no second emit
    await Future<void>.delayed(Duration.zero);
    expect(statuses, hasLength(1));
  });

  test('ignores blank and non-JSON lines', () async {
    proc.emit('');
    proc.emit('not json');
    proc.emit('   ');
    await Future<void>.delayed(Duration.zero);
    expect(items, isEmpty);
    expect(statuses, isEmpty);
  });

  test('send writes a stream-json user message and echoes it locally', () async {
    session.send('do the thing');
    await Future<void>.delayed(Duration.zero);

    expect(proc.writes, hasLength(1));
    final sent = jsonDecode(proc.writes.single) as Map<String, Object?>;
    expect(sent['type'], 'user');
    expect((sent['message'] as Map)['content'], 'do the thing');

    final echoed = items.whereType<UserMessage>().toList();
    expect(echoed, hasLength(1));
    expect(echoed.single.text, 'do the thing');
  });

  test('dispose kills the process', () async {
    await session.dispose();
    expect(proc.killed, isTrue);
  });
}
