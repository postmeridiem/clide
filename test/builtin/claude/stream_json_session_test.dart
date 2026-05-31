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

String resultEvent({double? cost, Map<String, dynamic>? modelUsage}) => jsonEncode({
      'type': 'result',
      'result': '',
      'usage': <String, dynamic>{},
      if (cost != null) 'total_cost_usd': cost,
      if (modelUsage != null) 'modelUsage': modelUsage,
    });

String rateLimitEvent({String? status, String? resetsAt}) => jsonEncode({
      'type': 'rate_limit_event',
      'rate_limit_info': <String, dynamic>{
        if (status != null) 'status': status,
        if (resetsAt != null) 'resetsAt': resetsAt,
      },
    });

// Real `--include-partial-messages` wire shape (captured from claude 2.1.150,
// interactive stream-json mode — T-184): partials arrive as `stream_event`
// envelopes wrapping Anthropic streaming deltas, NOT `assistant`+`partial:true`.
String streamMessageStart(String messageId) => jsonEncode({
      'type': 'stream_event',
      'event': {
        'type': 'message_start',
        'message': {'id': messageId, 'role': 'assistant', 'content': <dynamic>[]},
      },
    });

String streamTextDelta(String text, {int index = 0}) => jsonEncode({
      'type': 'stream_event',
      'event': {
        'type': 'content_block_delta',
        'index': index,
        'delta': {'type': 'text_delta', 'text': text},
      },
    });

String streamMessageStop() => jsonEncode({
      'type': 'stream_event',
      'event': {'type': 'message_stop'},
    });

// The final per-block `assistant` event carrying a message id (so the session
// can pair it with a streamed placeholder).
String assistantTextWithId(String messageId, String text, {String uuid = 'final-uuid'}) => jsonEncode({
      'type': 'assistant',
      'uuid': uuid,
      'message': {
        'id': messageId,
        'role': 'assistant',
        'content': [
          {'type': 'text', 'text': text},
        ],
      },
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

  test('captures the claude session id from the first event carrying it (T-185)', () async {
    final ids = <String>[];
    session.sessionIdResolved.listen(ids.add);
    proc.emit(jsonEncode({
      'type': 'system',
      'subtype': 'init',
      'session_id': 'sess-abc',
      'model': 'claude-opus-4-7',
      'permissionMode': 'default',
    }));
    await Future<void>.delayed(Duration.zero);
    expect(session.claudeSessionId, 'sess-abc');
    expect(ids, ['sess-abc']);
  });

  group('live cost/context from result events (T-168)', () {
    test('result event with total_cost_usd populates cost field', () async {
      proc.emit(resultEvent(cost: 0.042));
      await Future<void>.delayed(Duration.zero);
      expect(statuses.last.cost, closeTo(0.042, 1e-9));
    });

    test('result event with modelUsage populates contextWindow', () async {
      proc.emit(resultEvent(
        cost: 0.01,
        modelUsage: {
          'claude-opus-4-7': {'contextWindow': 1000000, 'maxOutputTokens': 8192},
        },
      ));
      await Future<void>.delayed(Duration.zero);
      expect(statuses.last.contextWindow, 1000000);
    });

    test('result event does not clear existing model/permissionMode fields', () async {
      proc.emit(initEvent());
      proc.emit(assistantText('hi'));
      proc.emit(resultEvent(cost: 0.05));
      await Future<void>.delayed(Duration.zero);
      expect(statuses.last.model, 'claude-opus-4-7');
      expect(statuses.last.permissionMode, 'default');
      expect(statuses.last.cost, closeTo(0.05, 1e-9));
    });

    test('result event without cost or modelUsage emits nothing', () async {
      final before = statuses.length;
      proc.emit(jsonEncode({'type': 'result', 'result': '', 'usage': <String, dynamic>{}}));
      await Future<void>.delayed(Duration.zero);
      expect(statuses.length, before); // no change → no emit
    });
  });

  group('rate_limit_event status (T-168)', () {
    test('rate_limit_event with status populates rateLimitInfo', () async {
      proc.emit(rateLimitEvent(status: 'rate_limited'));
      await Future<void>.delayed(Duration.zero);
      expect(statuses.last.rateLimitInfo, contains('rate limited'));
    });

    test('rate_limit_event with an ISO resetsAt includes the time', () async {
      // 2026-05-30T14:32:00Z → shows 14:32 (UTC, local may differ but contains digits)
      proc.emit(rateLimitEvent(status: 'rate_limited', resetsAt: '2026-05-30T14:32:00Z'));
      await Future<void>.delayed(Duration.zero);
      expect(statuses.last.rateLimitInfo, contains('rate limited'));
      expect(statuses.last.rateLimitInfo, contains('resets'));
    });
  });

  group('token streaming via stream_event (T-168, shape verified by T-184)', () {
    test('content_block_delta text streams under a stable partial-<msgId> uuid, accumulating', () async {
      proc.emit(streamMessageStart('msg-1'));
      proc.emit(streamTextDelta('one '));
      proc.emit(streamTextDelta('two three'));
      await Future<void>.delayed(Duration.zero);
      final parts = items.whereType<AssistantTextMessage>().toList();
      // Each delta emits an upserting placeholder; all share the stable uuid and
      // the latest carries the accumulated text.
      expect(parts, isNotEmpty);
      expect(parts.every((m) => m.uuid == 'partial-msg-1'), isTrue);
      expect(parts.last.text, 'one two three');
    });

    test('the final assistant text event finalises the placeholder in place (same uuid)', () async {
      proc.emit(streamMessageStart('msg-2'));
      proc.emit(streamTextDelta('hel'));
      proc.emit(assistantTextWithId('msg-2', 'hello there'));
      await Future<void>.delayed(Duration.zero);
      final parts = items.whereType<AssistantTextMessage>().toList();
      // The final, complete text reuses the placeholder uuid so the controller
      // replaces rather than appends — no duplicate.
      expect(parts.last.uuid, 'partial-msg-2');
      expect(parts.last.text, 'hello there');
    });

    test('a tool_use block keeps its own uuid and appends after the streamed text', () async {
      proc.emit(streamMessageStart('msg-3'));
      proc.emit(streamTextDelta('working'));
      proc.emit(assistantTextWithId('msg-3', 'working on it')); // finalises partial-msg-3
      proc.emit(assistantToolUse()); // separate block, own uuid
      await Future<void>.delayed(Duration.zero);
      final tool = items.whereType<AssistantToolUse>().single;
      expect(tool.uuid, isNot('partial-msg-3'));
      expect(items.last, isA<AssistantToolUse>());
    });

    test('streaming state resets after a result so the next turn streams cleanly', () async {
      proc.emit(streamMessageStart('msg-4'));
      proc.emit(streamTextDelta('first'));
      proc.emit(streamMessageStop());
      proc.emit(jsonEncode({'type': 'result', 'result': '', 'usage': <String, dynamic>{}}));
      await Future<void>.delayed(Duration.zero);
      // A new turn reusing the same id still streams (no leftover finalised flag).
      proc.emit(streamMessageStart('msg-4'));
      proc.emit(streamTextDelta('second'));
      await Future<void>.delayed(Duration.zero);
      final parts = items.whereType<AssistantTextMessage>().toList();
      expect(parts.last.text, 'second');
    });
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

  test('setPermissionMode writes a set_permission_mode control_request (T-181)', () async {
    session.setPermissionMode('acceptEdits');
    expect(proc.writes, hasLength(1));
    final sent = jsonDecode(proc.writes.single) as Map<String, dynamic>;
    expect(sent['type'], 'control_request');
    expect(sent['request_id'], isNotNull);
    final req = sent['request'] as Map;
    expect(req['subtype'], 'set_permission_mode');
    expect(req['mode'], 'acceptEdits');
  });

  test('setPermissionMode uses a unique request_id each call (T-181)', () async {
    session.setPermissionMode('plan');
    session.setPermissionMode('default');
    expect(proc.writes, hasLength(2));
    final id1 = (jsonDecode(proc.writes[0]) as Map)['request_id'] as String;
    final id2 = (jsonDecode(proc.writes[1]) as Map)['request_id'] as String;
    expect(id1, isNot(equals(id2)));
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

  test('promptedToolUseIds contains the tool_use_id after a can_use_tool arrives', () async {
    proc.emit(canUseTool('p1'));
    await Future<void>.delayed(Duration.zero);
    // promptedToolUseIds exposes the set of prompted tool use ids.
    expect(session.promptedToolUseIds, contains('toolu_1'));
  });

  test('rate_limit_event with a non-ISO resetsAt shows the raw string', () async {
    proc.emit(rateLimitEvent(status: 'rate_limited', resetsAt: 'soon'));
    await Future<void>.delayed(Duration.zero);
    // Non-ISO resetsAt → DateTime.tryParse returns null → raw string is used.
    expect(statuses.last.rateLimitInfo, 'rate limited — resets soon');
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

    test('answers notifications/initialized with an empty result', () async {
      mproc.emit(mcpMessage('m5', {'method': 'notifications/initialized', 'jsonrpc': '2.0', 'id': 4}));
      await Future<void>.delayed(Duration.zero);
      final r = mcpResponseOf(mproc.writes.last);
      expect(r['result'], isA<Map>());
    });

    test('answers unknown MCP method with a JSON-RPC error -32601', () async {
      mproc.emit(mcpMessage('m6', {'method': 'resources/list', 'jsonrpc': '2.0', 'id': 5}));
      await Future<void>.delayed(Duration.zero);
      final r = mcpResponseOf(mproc.writes.last);
      expect((r['error'] as Map)['code'], -32601);
      expect((r['error'] as Map)['message'], contains('resources/list'));
    });
  });
}
