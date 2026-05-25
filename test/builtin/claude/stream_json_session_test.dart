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

String canUseTool(String rid, {String tool = 'Write', Map<String, dynamic>? input}) => jsonEncode({
      'type': 'control_request',
      'request_id': rid,
      'request': {
        'subtype': 'can_use_tool',
        'tool_name': tool,
        'display_name': tool,
        'description': 'banana.txt',
        'input': input ?? {'file_path': '/tmp/banana.txt', 'content': 'banana'},
        'tool_use_id': 'toolu_1',
      },
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

  test('a can_use_tool control_request becomes a pending prompt (not a conversation item)', () async {
    final emitted = <ToolPrompt?>[];
    session.pendingPromptStream.listen(emitted.add);
    proc.emit(canUseTool('req-1'));
    await Future<void>.delayed(Duration.zero);

    final p = session.pendingPrompt;
    expect(p, isNotNull);
    expect(p!.promptId, 'req-1');
    expect(p.toolName, 'Write');
    expect(p.displayName, 'Write');
    expect(p.description, 'banana.txt');
    expect(p.toolUseId, 'toolu_1');
    expect(p.input['content'], 'banana');
    expect(emitted.last, isNotNull); // surfaced on the stream
    expect(items, isEmpty); // prompts are not conversation items
    expect(proc.writes, isEmpty); // no response until resolved
  });

  test('resolvePrompt(allow) writes success+updatedInput and clears the pending prompt', () async {
    proc.emit(canUseTool('req-2'));
    await Future<void>.delayed(Duration.zero);

    final p = session.pendingPrompt!;
    session.resolvePrompt(p.promptId, AllowTool(p.input));
    expect(session.pendingPrompt, isNull);

    final sent = jsonDecode(proc.writes.single) as Map<String, dynamic>;
    expect(sent['type'], 'control_response');
    final resp = sent['response'] as Map;
    expect(resp['subtype'], 'success');
    expect(resp['request_id'], 'req-2');
    final decision = resp['response'] as Map;
    expect(decision['behavior'], 'allow');
    expect((decision['updatedInput'] as Map)['content'], 'banana');
  });

  test('resolvePrompt(deny) writes a deny decision with a message', () async {
    proc.emit(canUseTool('req-3'));
    await Future<void>.delayed(Duration.zero);

    session.resolvePrompt('req-3', const DenyTool('nope'));
    final decision = ((jsonDecode(proc.writes.single) as Map)['response'] as Map)['response'] as Map;
    expect(decision['behavior'], 'deny');
    expect(decision['message'], 'nope');
  });

  test('prompts queue: resolving the head surfaces the next', () async {
    proc.emit(canUseTool('q1'));
    proc.emit(canUseTool('q2'));
    await Future<void>.delayed(Duration.zero);

    expect(session.pendingPrompt!.promptId, 'q1');
    session.resolvePrompt('q1', AllowTool(const {}));
    expect(session.pendingPrompt!.promptId, 'q2');
    session.resolvePrompt('q2', AllowTool(const {}));
    expect(session.pendingPrompt, isNull);
  });

  test('resolvePrompt is a no-op for an unknown / already-resolved id', () async {
    proc.emit(canUseTool('req-4'));
    await Future<void>.delayed(Duration.zero);

    session.resolvePrompt('req-4', AllowTool(const {})); // resolves
    session.resolvePrompt('req-4', AllowTool(const {})); // already gone
    session.resolvePrompt('does-not-exist', AllowTool(const {}));
    expect(proc.writes, hasLength(1));
  });

  test('an unsupported control_request is answered with an error (no hang)', () async {
    proc.emit(jsonEncode({
      'type': 'control_request',
      'request_id': 'req-5',
      'request': {'subtype': 'mystery_subtype'},
    }));
    await Future<void>.delayed(Duration.zero);

    expect(items, isEmpty);
    final resp = (jsonDecode(proc.writes.single) as Map)['response'] as Map;
    expect(resp['subtype'], 'error');
    expect(resp['request_id'], 'req-5');
    expect(resp['error'], contains('mystery_subtype'));
  });

  test('dispose kills the process', () async {
    await session.dispose();
    expect(proc.killed, isTrue);
  });
}
