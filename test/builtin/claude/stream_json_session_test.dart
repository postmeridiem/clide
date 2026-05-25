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

class _FakeMcpServer implements McpServer {
  @override
  String get name => 'clide-team';
  @override
  String get version => '9.9.9';
  final List<String> calls = [];
  @override
  List<Map<String, dynamic>> get tools => [
        {
          'name': 'ping',
          'description': 'p',
          'inputSchema': {'type': 'object', 'properties': <String, dynamic>{}},
        },
      ];
  @override
  Future<Map<String, dynamic>> callTool(String name, Map<String, dynamic> arguments) async {
    calls.add(name);
    return {
      'content': [
        {'type': 'text', 'text': 'pong'},
      ],
      'isError': false,
    };
  }
}

String mcpMessage(String rid, Map<String, dynamic> message, {String server = 'clide-team'}) => jsonEncode({
      'type': 'control_request',
      'request_id': rid,
      'request': {'subtype': 'mcp_message', 'server_name': server, 'message': message},
    });

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

  test('a synthetic user message (skill/command inject) is flagged injected', () async {
    proc.emit(jsonEncode({
      'type': 'user',
      'isSynthetic': true,
      'message': {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'Base directory for this skill: /x'}
        ],
      },
    }));
    await Future<void>.delayed(Duration.zero);
    final u = items.whereType<UserMessage>().single;
    expect(u.injected, isTrue);
  });

  test('a plain user text event is not flagged injected', () async {
    proc.emit(jsonEncode({
      'type': 'user',
      'message': {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'hello'}
        ],
      },
    }));
    await Future<void>.delayed(Duration.zero);
    expect(items.whereType<UserMessage>().single.injected, isFalse);
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

  test('a permission request carries its permission_suggestions', () async {
    proc.emit(jsonEncode({
      'type': 'control_request',
      'request_id': 'rs',
      'request': {
        'subtype': 'can_use_tool',
        'tool_name': 'Write',
        'input': {'file_path': '/tmp/x'},
        'permission_suggestions': [
          {'type': 'setMode', 'mode': 'acceptEdits', 'destination': 'session'}
        ],
      },
    }));
    await Future<void>.delayed(Duration.zero);
    expect(session.pendingPrompt!.permissionSuggestions, hasLength(1));
  });

  test('resolvePrompt(allow with updatedPermissions) echoes them in the response', () async {
    proc.emit(canUseTool('rp'));
    await Future<void>.delayed(Duration.zero);
    session.resolvePrompt(
        'rp',
        AllowTool(const {
          'x': 1
        }, updatedPermissions: const [
          {'type': 'setMode'}
        ]));
    final decision = ((jsonDecode(proc.writes.single) as Map)['response'] as Map)['response'] as Map;
    expect(decision['behavior'], 'allow');
    expect(decision['updatedPermissions'], hasLength(1));
  });

  test('resolvePrompt(allow with a follow-up note) sends the note as a user message', () async {
    proc.emit(canUseTool('rn'));
    await Future<void>.delayed(Duration.zero);
    session.resolvePrompt('rn', AllowTool(const {'x': 1}, followUpNote: 'use docs/ instead'));

    // first write = control_response (allow), second = the follow-up message
    expect(proc.writes, hasLength(2));
    final follow = jsonDecode(proc.writes[1]) as Map;
    expect(follow['type'], 'user');
    expect((follow['message'] as Map)['content'], 'use docs/ instead');
  });

  test('resolvePrompt records the tool outcome — allow', () async {
    proc.emit(canUseTool('o1'));
    await Future<void>.delayed(Duration.zero);
    session.resolvePrompt('o1', AllowTool(const {}));
    expect(session.toolUseOutcomes['toolu_1'], isTrue);
  });

  test('resolvePrompt records the tool outcome — deny', () async {
    proc.emit(canUseTool('o2'));
    await Future<void>.delayed(Duration.zero);
    session.resolvePrompt('o2', const DenyTool('no'));
    expect(session.toolUseOutcomes['toolu_1'], isFalse);
  });

  test('resolvePrompt(deny) writes a deny decision with a message', () async {
    proc.emit(canUseTool('req-3'));
    await Future<void>.delayed(Duration.zero);

    session.resolvePrompt('req-3', const DenyTool('nope'));
    final decision = ((jsonDecode(proc.writes.single) as Map)['response'] as Map)['response'] as Map;
    expect(decision['behavior'], 'deny');
    expect(decision['message'], 'nope');
  });

  test('resolving an AskUserQuestion leaves an answered echo in the log', () async {
    proc.emit(jsonEncode({
      'type': 'control_request',
      'request_id': 'aq',
      'request': {
        'subtype': 'can_use_tool',
        'tool_name': 'AskUserQuestion',
        'input': {'questions': <dynamic>[]},
      },
    }));
    await Future<void>.delayed(Duration.zero);
    session.resolvePrompt(
        'aq',
        AllowTool(const {
          'answers': {'Pet': 'Dogs'}
        }));
    await Future<void>.delayed(Duration.zero);

    final echo = items.whereType<UserMessage>().toList();
    expect(echo, hasLength(1));
    expect(echo.single.text, contains('Pet → Dogs'));
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

  test('interrupt writes an interrupt control_request', () async {
    session.interrupt();
    final sent = jsonDecode(proc.writes.single) as Map<String, dynamic>;
    expect(sent['type'], 'control_request');
    expect((sent['request'] as Map)['subtype'], 'interrupt');
    expect(sent['request_id'], isNotNull);
  });

  test('busy goes true on send and false on a result event', () async {
    final busy = <bool>[];
    session.busyStream.listen(busy.add);
    session.send('hi');
    expect(session.busy, isTrue);

    proc.emit(jsonEncode({'type': 'result', 'subtype': 'success'}));
    await Future<void>.delayed(Duration.zero);
    expect(session.busy, isFalse);
    expect(busy, [true, false]);
  });

  test('dispose kills the process', () async {
    await session.dispose();
    expect(proc.killed, isTrue);
  });

  group('MCP server hosting (T-170)', () {
    late _FakeProc mproc;
    late StreamJsonSession msession;
    late _FakeMcpServer server;

    setUp(() {
      mproc = _FakeProc();
      server = _FakeMcpServer();
      msession = StreamJsonSession(mproc, mcpServers: [server]);
      msession.start();
    });

    tearDown(() => msession.dispose());

    Map<String, dynamic> mcpResponseOf(String write) {
      final resp = jsonDecode(write) as Map<String, dynamic>;
      return ((resp['response'] as Map)['response'] as Map)['mcp_response'] as Map<String, dynamic>;
    }

    test('declares its sdkMcpServers in the initialize handshake', () {
      final init = mproc.writes.map((w) => jsonDecode(w) as Map).firstWhere(
            (m) => (m['request'] as Map?)?['subtype'] == 'initialize',
          );
      expect((init['request'] as Map)['sdkMcpServers'], ['clide-team']);
    });

    test('answers mcp initialize with our serverInfo', () async {
      mproc.emit(mcpMessage('m1', {
        'method': 'initialize',
        'params': {'protocolVersion': '2025-11-25'},
        'jsonrpc': '2.0',
        'id': 0,
      }));
      await Future<void>.delayed(Duration.zero);
      final r = mcpResponseOf(mproc.writes.last);
      expect((r['result'] as Map)['serverInfo'], {'name': 'clide-team', 'version': '9.9.9'});
    });

    test('answers tools/list with the server tools', () async {
      mproc.emit(mcpMessage('m2', {'method': 'tools/list', 'jsonrpc': '2.0', 'id': 1}));
      await Future<void>.delayed(Duration.zero);
      final r = mcpResponseOf(mproc.writes.last);
      final tools = (r['result'] as Map)['tools'] as List;
      expect(tools.single['name'], 'ping');
    });

    test('routes tools/call to the server and returns its result', () async {
      mproc.emit(mcpMessage('m3', {
        'method': 'tools/call',
        'params': {'name': 'ping', 'arguments': <String, dynamic>{}},
        'jsonrpc': '2.0',
        'id': 2,
      }));
      await Future<void>.delayed(Duration.zero);
      expect(server.calls, ['ping']);
      final r = mcpResponseOf(mproc.writes.last);
      final content = (r['result'] as Map)['content'] as List;
      expect(content.single['text'], 'pong');
    });

    test('an mcp_message for an unknown server is answered with an error', () async {
      mproc.emit(mcpMessage('m4', {'method': 'tools/list', 'jsonrpc': '2.0', 'id': 3}, server: 'nope'));
      await Future<void>.delayed(Duration.zero);
      final r = mcpResponseOf(mproc.writes.last);
      expect(r['error'], isNotNull);
    });
  });
}
