import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/builtin/claude/src/workflow_run.dart';
import 'package:test/test.dart';

class _FakeProc extends StreamJsonProcess {
  final _ctl = StreamController<String>();
  final List<String> writes = [];
  bool killed = false;

  /// Drives the T-361 exit watch; never completes unless a test exits it.
  final exit = Completer<int>();
  final List<String> stderr = [];

  @override
  Stream<String> get lines => _ctl.stream;
  @override
  void writeLine(String line) => writes.add(line);
  @override
  Future<void> kill() async => killed = true;
  @override
  Future<int> get exitCode => exit.future;
  @override
  List<String> get stderrTail => stderr;

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
        'input': {'command': 'ls'},
      },
    ],
  },
});

String initEvent() => jsonEncode({'type': 'system', 'subtype': 'init', 'model': 'claude-opus-4-7', 'permissionMode': 'default'});

String resultEvent({double? cost, Map<String, dynamic>? modelUsage}) =>
    jsonEncode({'type': 'result', 'result': '', 'usage': <String, dynamic>{}, 'total_cost_usd': ?cost, 'modelUsage': ?modelUsage});

String rateLimitEvent({String? status, String? resetsAt}) => jsonEncode({
  'type': 'rate_limit_event',
  'rate_limit_info': <String, dynamic>{'status': ?status, 'resetsAt': ?resetsAt},
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
    // start() always sends the `initialize` handshake (T-408); drop it so the
    // write assertions below stay about what each test sends. The handshake
    // itself is asserted in the 'initialize handshake' group.
    proc.writes.clear();
  });

  tearDown(() => session.dispose());

  group('initialize handshake + model list (T-408)', () {
    test('start() sends the initialize handshake even with no MCP servers', () {
      final p = _FakeProc();
      final s = StreamJsonSession(p);
      addTearDown(s.dispose);
      s.start();
      final init = jsonDecode(p.writes.single) as Map;
      expect(init['type'], 'control_request');
      expect((init['request'] as Map)['subtype'], 'initialize');
      expect((init['request'] as Map)['sdkMcpServers'], isEmpty);
    });

    test('the initialize response populates availableModels', () async {
      final p = _FakeProc();
      final s = StreamJsonSession(p);
      addTearDown(s.dispose);
      s.start();
      final rid = (jsonDecode(p.writes.single) as Map)['request_id'];
      expect(s.availableModels, isEmpty);
      p.emit(
        jsonEncode({
          'type': 'control_response',
          'response': {
            'subtype': 'success',
            'request_id': rid,
            'response': {
              'commands': <dynamic>[],
              'models': [
                {'value': 'default', 'displayName': 'Default', 'description': 'recommended'},
                {'value': 'sonnet', 'displayName': 'Sonnet'},
                {'value': 12345}, // malformed entry → skipped
              ],
            },
          },
        }),
      );
      await pumpEventQueue();
      expect(s.availableModels, hasLength(2));
      expect(s.availableModels[0].value, 'default');
      expect(s.availableModels[0].description, 'recommended');
      expect(s.availableModels[1].displayName, 'Sonnet');
      expect(s.availableModels[1].description, isEmpty);
    });

    // The `init` event only arrives with the first turn, so without this the
    // status bar showed no model until the user had talked to claude.
    String initResponse(Object? rid, {String? mode = 'default'}) => jsonEncode({
      'type': 'control_response',
      'response': {
        'subtype': 'success',
        'request_id': rid,
        'response': {
          'models': [
            {'value': 'default', 'resolvedModel': 'claude-opus-5-5[1m]', 'displayName': 'Default'},
            {'value': 'sonnet', 'resolvedModel': 'claude-sonnet-5', 'displayName': 'Sonnet'},
          ],
          'current_permission_mode': ?mode,
        },
      },
    });

    test('the initialize response seeds model + permission mode before any turn', () async {
      final p = _FakeProc();
      final s = StreamJsonSession(p);
      addTearDown(s.dispose);
      s.start();
      p.emit(initResponse((jsonDecode(p.writes.single) as Map)['request_id'], mode: 'plan'));
      await pumpEventQueue();
      // The [1m] variant suffix is dropped so the label doesn't change once
      // assistant events (bare id) arrive.
      expect(s.status.model, 'claude-opus-5-5');
      expect(s.status.permissionMode, 'plan');
    });

    test('the handshake never overwrites a model already known', () async {
      final p = _FakeProc();
      final s = StreamJsonSession(p);
      addTearDown(s.dispose);
      s.start();
      final rid = (jsonDecode(p.writes.single) as Map)['request_id'];
      s.setModel('sonnet'); // new-session default applied before the response
      p.emit(initResponse(rid, mode: null));
      await pumpEventQueue();
      expect(s.status.model, 'sonnet');
      expect(s.status.permissionMode, isNull);
    });

    test('setModel(default) shows what the handshake says default resolves to', () async {
      final p = _FakeProc();
      final s = StreamJsonSession(p);
      addTearDown(s.dispose);
      s.start();
      p.emit(initResponse((jsonDecode(p.writes.single) as Map)['request_id']));
      await pumpEventQueue();
      s.setModel('sonnet');
      s.setModel('default');
      await pumpEventQueue();
      expect(s.status.model, 'claude-opus-5-5');
    });
  });

  group('setModel (T-408)', () {
    test('sends a set_model control_request and optimistically merges status', () async {
      session.setModel('sonnet');
      final sent = jsonDecode(proc.writes.single) as Map;
      expect(sent['type'], 'control_request');
      expect((sent['request'] as Map)['subtype'], 'set_model');
      expect((sent['request'] as Map)['model'], 'sonnet');
      await pumpEventQueue();
      expect(statuses.last.model, 'sonnet');
    });

    test('setModel(default) does not guess the resolved model before the handshake', () async {
      session.setModel('default');
      await pumpEventQueue();
      expect(statuses, isEmpty, reason: 'only the CLI knows what default resolves to');
    });

    test('an error response rolls the model back and surfaces the message', () async {
      final errors = <String>[];
      session.modelErrors.listen(errors.add);
      proc.emit(initEvent()); // model: claude-opus-4-7
      await pumpEventQueue();

      session.setModel('bogus-model');
      await pumpEventQueue();
      expect(statuses.last.model, 'bogus-model'); // optimistic

      final rid = (jsonDecode(proc.writes.single) as Map)['request_id'];
      proc.emit(
        jsonEncode({
          'type': 'control_response',
          'response': {'subtype': 'error', 'request_id': rid, 'error': 'Unknown model: bogus-model'},
        }),
      );
      await pumpEventQueue();
      expect(statuses.last.model, 'claude-opus-4-7', reason: 'rolled back');
      expect(errors, ['Unknown model: bogus-model']);
    });

    test('a success response keeps the optimistic model', () async {
      session.setModel('opus');
      final rid = (jsonDecode(proc.writes.single) as Map)['request_id'];
      proc.emit(
        jsonEncode({
          'type': 'control_response',
          'response': {'subtype': 'success', 'request_id': rid},
        }),
      );
      await pumpEventQueue();
      expect(statuses.last.model, 'opus');
    });
  });

  test('parses assistant text + tool_use events into items', () async {
    proc.emit(assistantText('hello there'));
    proc.emit(assistantToolUse());
    await pumpEventQueue();

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
    await pumpEventQueue();

    expect(statuses.last.model, 'claude-opus-4-7');
    expect(statuses.last.permissionMode, 'default');
    expect(statuses.last.contextTokens, 150); // 100 + 50 + 0
  });

  test('only emits status on change', () async {
    proc.emit(initEvent());
    proc.emit(initEvent()); // identical → no second emit
    await pumpEventQueue();
    expect(statuses, hasLength(1));
  });

  // T-274 root cause: the init event fired before the pane subscribed and
  // the plain broadcast stream dropped it — the status bar stayed blank.
  test('subscribing AFTER the init event still yields the status (T-274/T-386)', () async {
    proc.emit(initEvent());
    await pumpEventQueue();

    final late = <SessionStatus>[];
    session.statusStream.listen(late.add);
    await pumpEventQueue();

    expect(late, hasLength(1), reason: 'replay-latest delivers the current status to late binders');
    expect(late.single.model, 'claude-opus-4-7');
    expect(late.single.permissionMode, 'default');
  });

  test('captures the claude session id from the first event carrying it (T-185)', () async {
    final ids = <String>[];
    session.sessionIdResolved.listen(ids.add);
    proc.emit(jsonEncode({'type': 'system', 'subtype': 'init', 'session_id': 'sess-abc', 'model': 'claude-opus-4-7', 'permissionMode': 'default'}));
    await pumpEventQueue();
    expect(session.claudeSessionId, 'sess-abc');
    expect(ids, ['sess-abc']);
  });

  group('live cost/context from result events (T-168)', () {
    test('result event with total_cost_usd populates cost field', () async {
      proc.emit(resultEvent(cost: 0.042));
      await pumpEventQueue();
      expect(statuses.last.cost, closeTo(0.042, 1e-9));
    });

    test('result event with modelUsage populates contextWindow', () async {
      proc.emit(
        resultEvent(
          cost: 0.01,
          modelUsage: {
            'claude-opus-4-7': {'contextWindow': 1000000, 'maxOutputTokens': 8192},
          },
        ),
      );
      await pumpEventQueue();
      expect(statuses.last.contextWindow, 1000000);
    });

    test('result event does not clear existing model/permissionMode fields', () async {
      proc.emit(initEvent());
      proc.emit(assistantText('hi'));
      proc.emit(resultEvent(cost: 0.05));
      await pumpEventQueue();
      expect(statuses.last.model, 'claude-opus-4-7');
      expect(statuses.last.permissionMode, 'default');
      expect(statuses.last.cost, closeTo(0.05, 1e-9));
    });

    test('result event without cost or modelUsage emits nothing', () async {
      final before = statuses.length;
      proc.emit(jsonEncode({'type': 'result', 'result': '', 'usage': <String, dynamic>{}}));
      await pumpEventQueue();
      expect(statuses.length, before); // no change → no emit
    });
  });

  group('rate_limit_event status (T-168)', () {
    test('rate_limit_event with status populates rateLimitInfo', () async {
      proc.emit(rateLimitEvent(status: 'rate_limited'));
      await pumpEventQueue();
      expect(statuses.last.rateLimitInfo, contains('rate limited'));
    });

    test('rate_limit_event with an ISO resetsAt includes the time', () async {
      // 2026-05-30T14:32:00Z → shows 14:32 (UTC, local may differ but contains digits)
      proc.emit(rateLimitEvent(status: 'rate_limited', resetsAt: '2026-05-30T14:32:00Z'));
      await pumpEventQueue();
      expect(statuses.last.rateLimitInfo, contains('rate limited'));
      expect(statuses.last.rateLimitInfo, contains('resets'));
    });

    test('rate_limit_event with a numeric (epoch) resetsAt does not crash', () async {
      // Claude sends resetsAt as a unix-epoch number, not a string — the
      // old `as String?` cast threw 'int is not a subtype of String?'.
      proc.emit(
        jsonEncode({
          'type': 'rate_limit_event',
          'rate_limit_info': {'status': 'rate_limited', 'resetsAt': 1780000000},
        }),
      );
      await pumpEventQueue();
      expect(statuses.last.rateLimitInfo, contains('rate limited'));
      expect(statuses.last.rateLimitInfo, contains('resets'));
    });
  });

  group('token streaming via stream_event (T-168, shape verified by T-184)', () {
    test('content_block_delta text streams under a stable partial-<msgId> uuid, accumulating', () async {
      proc.emit(streamMessageStart('msg-1'));
      proc.emit(streamTextDelta('one '));
      proc.emit(streamTextDelta('two three'));
      await pumpEventQueue();
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
      await pumpEventQueue();
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
      await pumpEventQueue();
      final tool = items.whereType<AssistantToolUse>().single;
      expect(tool.uuid, isNot('partial-msg-3'));
      expect(items.last, isA<AssistantToolUse>());
    });

    test('streaming state resets after a result so the next turn streams cleanly', () async {
      proc.emit(streamMessageStart('msg-4'));
      proc.emit(streamTextDelta('first'));
      proc.emit(streamMessageStop());
      proc.emit(jsonEncode({'type': 'result', 'result': '', 'usage': <String, dynamic>{}}));
      await pumpEventQueue();
      // A new turn reusing the same id still streams (no leftover finalised flag).
      proc.emit(streamMessageStart('msg-4'));
      proc.emit(streamTextDelta('second'));
      await pumpEventQueue();
      final parts = items.whereType<AssistantTextMessage>().toList();
      expect(parts.last.text, 'second');
    });
  });

  test('ignores blank and non-JSON lines', () async {
    proc.emit('');
    proc.emit('not json');
    proc.emit('   ');
    await pumpEventQueue();
    expect(items, isEmpty);
    expect(statuses, isEmpty);
  });

  test('send writes a stream-json user message and echoes it locally', () async {
    session.send('do the thing');
    await pumpEventQueue();

    expect(proc.writes, hasLength(1));
    final sent = jsonDecode(proc.writes.single) as Map<String, Object?>;
    expect(sent['type'], 'user');
    expect((sent['message'] as Map)['content'], 'do the thing');

    final echoed = items.whereType<UserMessage>().toList();
    expect(echoed, hasLength(1));
    expect(echoed.single.text, 'do the thing');
  });

  test('a synthetic user message (skill/command inject) is flagged injected', () async {
    proc.emit(
      jsonEncode({
        'type': 'user',
        'isSynthetic': true,
        'message': {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Base directory for this skill: /x'},
          ],
        },
      }),
    );
    await pumpEventQueue();
    final u = items.whereType<UserMessage>().single;
    expect(u.injected, isTrue);
  });

  test('a plain user text event is not flagged injected', () async {
    proc.emit(
      jsonEncode({
        'type': 'user',
        'message': {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'hello'},
          ],
        },
      }),
    );
    await pumpEventQueue();
    expect(items.whereType<UserMessage>().single.injected, isFalse);
  });

  test('a can_use_tool control_request becomes a pending prompt (not a conversation item)', () async {
    final emitted = <ToolPrompt?>[];
    session.pendingPromptStream.listen(emitted.add);
    proc.emit(canUseTool('req-1'));
    await pumpEventQueue();

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
    await pumpEventQueue();

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
    proc.emit(
      jsonEncode({
        'type': 'control_request',
        'request_id': 'rs',
        'request': {
          'subtype': 'can_use_tool',
          'tool_name': 'Write',
          'input': {'file_path': '/tmp/x'},
          'permission_suggestions': [
            {'type': 'setMode', 'mode': 'acceptEdits', 'destination': 'session'},
          ],
        },
      }),
    );
    await pumpEventQueue();
    expect(session.pendingPrompt!.permissionSuggestions, hasLength(1));
  });

  test('resolvePrompt(allow with updatedPermissions) echoes them in the response', () async {
    proc.emit(canUseTool('rp'));
    await pumpEventQueue();
    session.resolvePrompt(
      'rp',
      AllowTool(
        const {'x': 1},
        updatedPermissions: const [
          {'type': 'setMode'},
        ],
      ),
    );
    final decision = ((jsonDecode(proc.writes.single) as Map)['response'] as Map)['response'] as Map;
    expect(decision['behavior'], 'allow');
    expect(decision['updatedPermissions'], hasLength(1));
  });

  test('resolvePrompt(allow with a follow-up note) sends the note as a user message', () async {
    proc.emit(canUseTool('rn'));
    await pumpEventQueue();
    session.resolvePrompt('rn', AllowTool(const {'x': 1}, followUpNote: 'use docs/ instead'));

    // first write = control_response (allow), second = the follow-up message
    expect(proc.writes, hasLength(2));
    final follow = jsonDecode(proc.writes[1]) as Map;
    expect(follow['type'], 'user');
    expect((follow['message'] as Map)['content'], 'use docs/ instead');
  });

  test('resolvePrompt records the tool outcome — allow', () async {
    proc.emit(canUseTool('o1'));
    await pumpEventQueue();
    session.resolvePrompt('o1', AllowTool(const {}));
    expect(session.toolUseOutcomes['toolu_1'], isTrue);
  });

  test('resolvePrompt records the tool outcome — deny', () async {
    proc.emit(canUseTool('o2'));
    await pumpEventQueue();
    session.resolvePrompt('o2', const DenyTool('no'));
    expect(session.toolUseOutcomes['toolu_1'], isFalse);
  });

  String planInit() => jsonEncode({'type': 'system', 'subtype': 'init', 'model': 'claude-opus-4-7', 'permissionMode': 'plan'});

  test('approving ExitPlanMode leaves plan mode (T-337)', () async {
    proc.emit(planInit());
    await pumpEventQueue();
    expect(statuses.last.permissionMode, 'plan');

    proc.emit(canUseTool('exit-1', tool: 'ExitPlanMode', input: {'plan': 'do the thing'}));
    await pumpEventQueue();
    final p = session.pendingPrompt!;
    expect(p.toolName, 'ExitPlanMode');

    session.resolvePrompt(p.promptId, AllowTool(p.input));
    await pumpEventQueue();
    expect(statuses.last.permissionMode, 'default', reason: 'approving ExitPlanMode must exit plan mode');
  });

  test('denying ExitPlanMode stays in plan mode (T-337)', () async {
    proc.emit(planInit());
    await pumpEventQueue();
    proc.emit(canUseTool('exit-2', tool: 'ExitPlanMode', input: {'plan': 'x'}));
    await pumpEventQueue();
    session.resolvePrompt(session.pendingPrompt!.promptId, const DenyTool('keep planning'));
    await pumpEventQueue();
    expect(statuses.last.permissionMode, 'plan', reason: 'a denied plan-exit keeps plan mode');
  });

  test('approving a non-ExitPlanMode tool does not change plan mode (T-337)', () async {
    proc.emit(planInit());
    await pumpEventQueue();
    proc.emit(canUseTool('w1')); // a Write
    await pumpEventQueue();
    session.resolvePrompt(session.pendingPrompt!.promptId, AllowTool(const {}));
    await pumpEventQueue();
    expect(statuses.last.permissionMode, 'plan', reason: 'only ExitPlanMode exits plan mode');
  });

  test('noteEffort merges the effort level into the status (T-412)', () async {
    proc.emit(initEvent());
    await pumpEventQueue();
    session.noteEffort('xhigh');
    await pumpEventQueue();
    expect(statuses.last.effort, 'xhigh');
    expect(statuses.last.model, 'claude-opus-4-7'); // merge, not replace
  });

  test('addLocalNotice emits a synthetic clide item and sends nothing (T-411)', () async {
    final before = proc.writes.length;
    session.addLocalNotice('/status is a Claude Code TUI command');
    await pumpEventQueue();
    final notice = items.whereType<AssistantTextMessage>().single;
    expect(notice.synthetic, isTrue);
    expect(notice.text, contains('/status'));
    expect(proc.writes.length, before); // nothing went to the CLI
  });

  test('resolvePrompt(deny) writes a deny decision with a message', () async {
    proc.emit(canUseTool('req-3'));
    await pumpEventQueue();

    session.resolvePrompt('req-3', const DenyTool('nope'));
    final decision = ((jsonDecode(proc.writes.single) as Map)['response'] as Map)['response'] as Map;
    expect(decision['behavior'], 'deny');
    expect(decision['message'], 'nope');
  });

  test('resolving an AskUserQuestion leaves an answered echo in the log', () async {
    proc.emit(
      jsonEncode({
        'type': 'control_request',
        'request_id': 'aq',
        'request': {
          'subtype': 'can_use_tool',
          'tool_name': 'AskUserQuestion',
          'input': {'questions': <dynamic>[]},
        },
      }),
    );
    await pumpEventQueue();
    session.resolvePrompt(
      'aq',
      AllowTool(const {
        'answers': {'Pet': 'Dogs'},
      }),
    );
    await pumpEventQueue();

    final echo = items.whereType<UserMessage>().toList();
    expect(echo, hasLength(1));
    expect(echo.single.text, contains('Pet → Dogs'));
  });

  test('prompts queue: resolving the head surfaces the next', () async {
    proc.emit(canUseTool('q1'));
    proc.emit(canUseTool('q2'));
    await pumpEventQueue();

    expect(session.pendingPrompt!.promptId, 'q1');
    session.resolvePrompt('q1', AllowTool(const {}));
    expect(session.pendingPrompt!.promptId, 'q2');
    session.resolvePrompt('q2', AllowTool(const {}));
    expect(session.pendingPrompt, isNull);
  });

  test('resolvePrompt is a no-op for an unknown / already-resolved id', () async {
    proc.emit(canUseTool('req-4'));
    await pumpEventQueue();

    session.resolvePrompt('req-4', AllowTool(const {})); // resolves
    session.resolvePrompt('req-4', AllowTool(const {})); // already gone
    session.resolvePrompt('does-not-exist', AllowTool(const {}));
    expect(proc.writes, hasLength(1));
  });

  test('an unsupported control_request is answered with an error (no hang)', () async {
    proc.emit(
      jsonEncode({
        'type': 'control_request',
        'request_id': 'req-5',
        'request': {'subtype': 'mystery_subtype'},
      }),
    );
    await pumpEventQueue();

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

  test('setPermissionMode emits the new mode on statusStream (T-250)', () async {
    // The control_request itself emits no status event; without an optimistic
    // update the badge stayed stale. Each call must surface the new mode.
    session.setPermissionMode('plan');
    await pumpEventQueue();
    expect(statuses.last.permissionMode, 'plan');

    session.setPermissionMode('acceptEdits');
    await pumpEventQueue();
    expect(statuses.last.permissionMode, 'acceptEdits');
  });

  test('busy goes true on send and false on a result event', () async {
    final busy = <bool>[];
    session.busyStream.listen(busy.add);
    session.send('hi');
    expect(session.busy, isTrue);

    proc.emit(jsonEncode({'type': 'result', 'subtype': 'success'}));
    await pumpEventQueue();
    expect(session.busy, isFalse);
    // Leading false is the replayed seed — busyStream tells a new
    // subscriber the CURRENT state before the live updates (T-386).
    expect(busy, [false, true, false]);
  });

  group('permission modes (T-597)', () {
    String handshake(Object? rid, {bool autoOk = true}) => jsonEncode({
      'type': 'control_response',
      'response': {
        'subtype': 'success',
        'request_id': rid,
        'response': {
          'models': [
            {'value': 'default', 'resolvedModel': 'claude-opus-5-5[1m]', 'supportsAutoMode': autoOk},
            {'value': 'haiku', 'resolvedModel': 'claude-haiku-4-5', 'supportsAutoMode': false},
          ],
          'current_permission_mode': 'default',
        },
      },
    });
    String reply(String rid, {String? mode, String? error}) => jsonEncode({
      'type': 'control_response',
      'response': error != null
          ? {'subtype': 'error', 'request_id': rid, 'error': error}
          : {
              'subtype': 'success',
              'request_id': rid,
              'response': {'mode': mode},
            },
    });
    String lastRid(_FakeProc p) => (jsonDecode(p.writes.last) as Map)['request_id'] as String;

    Future<(StreamJsonSession, _FakeProc)> started({bool autoOk = true, bool bypassAllowed = false}) async {
      final p = _FakeProc();
      final s = StreamJsonSession(p, bypassAllowed: bypassAllowed);
      addTearDown(s.dispose);
      s.start();
      p.emit(handshake((jsonDecode(p.writes.single) as Map)['request_id'], autoOk: autoOk));
      await pumpEventQueue();
      return (s, p);
    }

    test('auto is offered when the current model supports it, never before the handshake', () async {
      final p = _FakeProc();
      final s = StreamJsonSession(p);
      addTearDown(s.dispose);
      s.start();
      expect(s.autoModeAvailable, isFalse, reason: 'nothing known yet');
      final (ready, _) = await started();
      expect(ready.autoModeAvailable, isTrue);
      expect(ready.availableModes.map((m) => m.value), ['default', 'acceptEdits', 'plan', 'auto']);
    });

    test('auto follows the model: a model without support hides it', () async {
      final (s, p) = await started();
      p.emit(
        jsonEncode({
          'type': 'assistant',
          'message': {'model': 'claude-haiku-4-5', 'content': <Object>[]},
        }),
      );
      await pumpEventQueue();
      expect(s.status.model, 'claude-haiku-4-5');
      expect(s.autoModeAvailable, isFalse);
    });

    test('bypass is offered only to a session launched allowing it', () async {
      final (plain, _) = await started();
      expect(plain.availableModes.map((m) => m.value), isNot(contains('bypassPermissions')));
      final (allowed, _) = await started(bypassAllowed: true);
      expect(allowed.availableModes.map((m) => m.value), contains('bypassPermissions'));
    });

    test('a refused mode rolls the status back and says why', () async {
      final (s, p) = await started();
      final errors = <String>[];
      s.permissionModeErrors.listen(errors.add);
      s.setPermissionMode('bypassPermissions');
      expect(s.status.permissionMode, 'bypassPermissions', reason: 'optimistic');
      p.emit(
        reply(lastRid(p), error: 'Cannot set permission mode to bypassPermissions because the session was not launched with --dangerously-skip-permissions'),
      );
      await pumpEventQueue();
      expect(s.status.permissionMode, 'default', reason: 'rolled back — the UI must not claim a mode the CLI refused');
      expect(errors.single, contains('--dangerously-skip-permissions'));
    });

    test('a refused auto stops offering auto for the rest of the session', () async {
      final (s, p) = await started();
      s.setPermissionMode('auto');
      p.emit(reply(lastRid(p), error: 'auto mode is unavailable'));
      await pumpEventQueue();
      expect(s.autoModeAvailable, isFalse);
      expect(s.availableModes.map((m) => m.value), isNot(contains('auto')));
    });

    test('`manual` is sent as default, and the CLI\'s answer wins over the guess', () async {
      final (s, p) = await started();
      s.setPermissionMode('acceptEdits');
      s.setPermissionMode('manual');
      final sent = jsonDecode(p.writes.last) as Map;
      expect((sent['request'] as Map)['mode'], 'default');
      p.emit(reply(lastRid(p), mode: 'default'));
      await pumpEventQueue();
      expect(s.status.permissionMode, 'default');
    });
  });

  group('queued messages (T-587)', () {
    String result() => jsonEncode({'type': 'result', 'subtype': 'success'});
    List<String> sentTexts() => [
      for (final w in proc.writes)
        if ((jsonDecode(w) as Map)['type'] == 'user') ((jsonDecode(w) as Map)['message'] as Map)['content'] as String,
    ];
    List<String> userItems() => [for (final i in items.whereType<UserMessage>()) i.text];

    test('submit while idle sends immediately', () async {
      session.submit('hi');
      await pumpEventQueue();
      expect(sentTexts(), ['hi']);
      expect(session.queued, isEmpty);
    });

    test('submit mid-turn queues: nothing written, nothing in the conversation yet', () async {
      session.submit('first');
      session.submit('second');
      await pumpEventQueue();
      expect(sentTexts(), ['first']);
      expect(session.queued.map((m) => m.text), ['second']);
      expect(userItems(), ['first'], reason: 'a queued message only renders once sent');
    });

    test('each result sends the next queued message — one per turn', () async {
      session.submit('a');
      session.submit('b');
      session.submit('c');
      proc.emit(result());
      await pumpEventQueue();
      expect(sentTexts(), ['a', 'b']);
      expect(session.busy, isTrue, reason: 'the flushed message started a turn');
      expect(session.queued.map((m) => m.text), ['c']);
      proc.emit(result());
      await pumpEventQueue();
      expect(sentTexts(), ['a', 'b', 'c']);
      expect(userItems(), ['a', 'b', 'c']);
      expect(session.queued, isEmpty);
    });

    test('a dismissed message is never sent', () async {
      session.submit('a');
      session.submit('drop me');
      final id = session.queued.single.id;
      expect(session.dismissQueued(id), isTrue);
      expect(session.dismissQueued(id), isFalse, reason: 'already gone');
      proc.emit(result());
      await pumpEventQueue();
      expect(sentTexts(), ['a']);
      expect(userItems(), ['a']);
    });

    test('an edited message is sent with its new text; editing to empty dismisses', () async {
      session.submit('a');
      session.submit('typo');
      session.submit('also drop');
      final [edit, drop] = session.queued;
      expect(session.editQueued(edit.id, 'fixed'), isTrue);
      expect(session.editQueued(drop.id, '   '), isTrue);
      expect(session.queued.map((m) => m.text), ['fixed']);
      proc.emit(result());
      await pumpEventQueue();
      expect(sentTexts(), ['a', 'fixed']);
    });

    test('a held queue sends nothing when the turn ends; release sends the head', () async {
      session.submit('a');
      session.submit('b');
      session.holdQueue();
      proc.emit(result());
      await pumpEventQueue();
      expect(session.busy, isFalse);
      expect(sentTexts(), ['a'], reason: 'held for an edit');

      // Idle but held: a new message queues behind rather than jumping ahead.
      session.submit('c');
      expect(sentTexts(), ['a']);
      expect(session.queued.map((m) => m.text), ['b', 'c']);

      session.releaseQueue();
      await pumpEventQueue();
      expect(sentTexts(), ['a', 'b']);
      expect(session.queued.map((m) => m.text), ['c']);
    });

    test('queuedStream replays the current queue and tracks changes', () async {
      final seen = <List<String>>[];
      session.submit('a');
      session.submit('b');
      session.queuedStream.listen((q) => seen.add([for (final m in q) m.text]));
      await pumpEventQueue();
      session.dismissQueued(session.queued.single.id);
      await pumpEventQueue();
      expect(seen, [
        ['b'],
        <String>[],
      ]);
    });

    test('process exit clears the queue — it can never be sent', () async {
      session.submit('a');
      session.submit('b');
      proc.exit.complete(1);
      await pumpEventQueue();
      expect(session.queued, isEmpty);
      expect(sentTexts(), ['a']);
    });
  });

  // T-618: with `--replay-user-messages` the CLI echoes each stdin user
  // message (isReplay, carrying the uuid we sent) when it takes it in — for a
  // message written mid-turn, at the next tool step (probed 2026-09-23).
  group('mid-turn delivery (T-618)', () {
    String result() => jsonEncode({'type': 'result', 'subtype': 'success'});
    List<Map> userWrites() => [
      for (final w in proc.writes)
        if ((jsonDecode(w) as Map)['type'] == 'user') jsonDecode(w) as Map,
    ];
    List<String> sentTexts() => [for (final w in userWrites()) (w['message'] as Map)['content'] as String];
    String uuidOf(String text) => userWrites().lastWhere((w) => (w['message'] as Map)['content'] == text)['uuid'] as String;
    String echo(String uuid, String text) => jsonEncode({
      'type': 'user',
      'isReplay': true,
      'uuid': uuid,
      'session_id': 's',
      'parent_tool_use_id': null,
      'timestamp': '2026-09-23T08:32:21.000Z',
      'message': {'role': 'user', 'content': text},
    });
    List<String> userItems() => [for (final i in items.whereType<UserMessage>()) i.text];

    setUp(() => session.deliverMidTurn = true);

    test('every user message is written with a uuid for its echo to carry', () async {
      session.submit('hi');
      expect(uuidOf('hi'), matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('mid-turn submit is written at once but only shows in the dock', () async {
      session.submit('first');
      session.submit('also this');
      await pumpEventQueue();
      expect(sentTexts(), ['first', 'also this']);
      expect(userItems(), ['first'], reason: 'not in the conversation until claude has it');
      final [m] = session.queued;
      expect(m.text, 'also this');
      expect(m.delivering, isTrue);
    });

    test('its echo renders it where it landed and clears it from the dock', () async {
      session.submit('first');
      session.submit('also this');
      proc.emit(assistantToolUse());
      proc.emit(echo(uuidOf('also this'), 'also this'));
      await pumpEventQueue();
      expect(userItems(), ['first', 'also this']);
      expect(session.queued, isEmpty);
      expect(items.last, isA<UserMessage>(), reason: 'after the tool call it was taken in at');
    });

    test('the echo of a message already on screen is dropped — no duplicate', () async {
      session.submit('first');
      proc.emit(echo(uuidOf('first'), 'first'));
      await pumpEventQueue();
      expect(userItems(), ['first']);
    });

    test('an echo we did not write is dropped', () async {
      proc.emit(echo('00000000-0000-4000-8000-000000000000', 'stranger'));
      await pumpEventQueue();
      expect(userItems(), isEmpty);
    });

    test('a delivering message can no longer be edited or dismissed', () async {
      session.submit('first');
      session.submit('too late');
      final id = session.queued.single.id;
      expect(session.dismissQueued(id), isFalse);
      expect(session.editQueued(id, 'changed'), isFalse);
      expect(session.queued.single.text, 'too late');
    });

    test('taken in after the turn ended, it starts the next turn', () async {
      session.submit('first');
      session.submit('late');
      proc.emit(result());
      await pumpEventQueue();
      expect(session.busy, isFalse);
      proc.emit(echo(uuidOf('late'), 'late'));
      await pumpEventQueue();
      expect(session.busy, isTrue);
      expect(userItems(), ['first', 'late']);
    });

    test('a held queue still holds; release delivers mid-turn', () async {
      session.submit('first');
      session.holdQueue();
      session.submit('waits');
      await pumpEventQueue();
      expect(sentTexts(), ['first']);
      expect(session.queued.single.delivering, isFalse);
      session.releaseQueue();
      await pumpEventQueue();
      expect(sentTexts(), ['first', 'waits']);
      expect(session.queued.single.delivering, isTrue);
    });

    test('a queue released at idle sends its head and delivers the rest', () async {
      session.submit('first');
      session.holdQueue();
      session.submit('b');
      session.submit('c');
      proc.emit(result());
      await pumpEventQueue();
      session.releaseQueue();
      await pumpEventQueue();
      expect(sentTexts(), ['first', 'b', 'c']);
      expect(userItems(), ['first', 'b'], reason: 'b started a turn; c waits for its echo');
      expect(session.queued.map((m) => (m.text, m.delivering)), [('c', true)]);
    });

    test('process exit clears delivering messages', () async {
      session.submit('first');
      session.submit('pending');
      proc.exit.complete(1);
      await pumpEventQueue();
      expect(session.queued, isEmpty);
    });
  });

  // T-244: the event shapes are the CLI's own SDK schema (2.1.280) —
  // `system/status` with `status: "compacting" | "requesting" | null`, a
  // closing status carrying `compact_result`, then `system/compact_boundary`.
  group('compaction (T-244)', () {
    String status(String? s, {String? result}) =>
        jsonEncode({'type': 'system', 'subtype': 'status', 'status': s, 'compact_result': ?result, 'uuid': 'u-${s ?? 'none'}', 'session_id': 'sess-1'});
    final boundary = jsonEncode({
      'type': 'system',
      'subtype': 'compact_boundary',
      'compact_metadata': {'trigger': 'manual', 'pre_tokens': 181234, 'post_tokens': 9120},
      'uuid': 'u-boundary',
      'session_id': 'sess-1',
    });
    // A manual /compact, start to finish, as the wire delivers it.
    final fixture = [
      status('compacting'),
      status(null, result: 'success'),
      boundary,
      jsonEncode({'type': 'result', 'subtype': 'success'}),
    ];

    test('a /compact run flips compacting on, then off when it finishes', () async {
      final seen = <bool>[];
      session.compactingStream.listen(seen.add);
      proc.emit(fixture[0]);
      await pumpEventQueue();
      expect(session.compacting, isTrue);

      for (final line in fixture.skip(1)) {
        proc.emit(line);
      }
      await pumpEventQueue();
      expect(session.compacting, isFalse);
      expect(seen, [false, true, false], reason: 'seed, start, end — no flicker');
      expect(items, isEmpty, reason: 'compaction events are not conversation items');
    });

    test('the boundary alone ends it (a dropped closing status cannot strand it)', () async {
      proc.emit(status('compacting'));
      proc.emit(boundary);
      await pumpEventQueue();
      expect(session.compacting, isFalse);
    });

    test('a result ends it', () async {
      proc.emit(status('compacting'));
      proc.emit(jsonEncode({'type': 'result', 'subtype': 'success'}));
      await pumpEventQueue();
      expect(session.compacting, isFalse);
    });

    test('a non-compacting status (requesting) ends it', () async {
      proc.emit(status('compacting'));
      proc.emit(status('requesting'));
      await pumpEventQueue();
      expect(session.compacting, isFalse);
    });

    test('a process exit ends it', () async {
      proc.emit(status('compacting'));
      await pumpEventQueue();
      proc.exit.complete(1);
      await pumpEventQueue();
      expect(session.compacting, isFalse);
    });
  });

  test('dispose kills the process', () async {
    await session.dispose();
    expect(proc.killed, isTrue);
  });

  test('promptedToolUseIds contains the tool_use_id after a can_use_tool arrives', () async {
    proc.emit(canUseTool('p1'));
    await pumpEventQueue();
    // promptedToolUseIds exposes the set of prompted tool use ids.
    expect(session.promptedToolUseIds, contains('toolu_1'));
  });

  test('rate_limit_event with a non-ISO resetsAt shows the raw string', () async {
    proc.emit(rateLimitEvent(status: 'rate_limited', resetsAt: 'soon'));
    await pumpEventQueue();
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
      final init = mproc.writes.map((w) => jsonDecode(w) as Map).firstWhere((m) => (m['request'] as Map?)?['subtype'] == 'initialize');
      expect((init['request'] as Map)['sdkMcpServers'], ['clide-team']);
    });

    test('answers mcp initialize with our serverInfo', () async {
      mproc.emit(
        mcpMessage('m1', {
          'method': 'initialize',
          'params': {'protocolVersion': '2025-11-25'},
          'jsonrpc': '2.0',
          'id': 0,
        }),
      );
      await pumpEventQueue();
      final r = mcpResponseOf(mproc.writes.last);
      expect((r['result'] as Map)['serverInfo'], {'name': 'clide-team', 'version': '9.9.9'});
    });

    test('answers tools/list with the server tools', () async {
      mproc.emit(mcpMessage('m2', {'method': 'tools/list', 'jsonrpc': '2.0', 'id': 1}));
      await pumpEventQueue();
      final r = mcpResponseOf(mproc.writes.last);
      final tools = (r['result'] as Map)['tools'] as List;
      expect(tools.single['name'], 'ping');
    });

    test('routes tools/call to the server and returns its result', () async {
      mproc.emit(
        mcpMessage('m3', {
          'method': 'tools/call',
          'params': {'name': 'ping', 'arguments': <String, dynamic>{}},
          'jsonrpc': '2.0',
          'id': 2,
        }),
      );
      await pumpEventQueue();
      expect(server.calls, ['ping']);
      final r = mcpResponseOf(mproc.writes.last);
      final content = (r['result'] as Map)['content'] as List;
      expect(content.single['text'], 'pong');
    });

    test('an mcp_message for an unknown server is answered with an error', () async {
      mproc.emit(mcpMessage('m4', {'method': 'tools/list', 'jsonrpc': '2.0', 'id': 3}, server: 'nope'));
      await pumpEventQueue();
      final r = mcpResponseOf(mproc.writes.last);
      expect(r['error'], isNotNull);
    });

    test('answers notifications/initialized with an empty result', () async {
      mproc.emit(mcpMessage('m5', {'method': 'notifications/initialized', 'jsonrpc': '2.0', 'id': 4}));
      await pumpEventQueue();
      final r = mcpResponseOf(mproc.writes.last);
      expect(r['result'], isA<Map>());
    });

    test('answers unknown MCP method with a JSON-RPC error -32601', () async {
      mproc.emit(mcpMessage('m6', {'method': 'resources/list', 'jsonrpc': '2.0', 'id': 5}));
      await pumpEventQueue();
      final r = mcpResponseOf(mproc.writes.last);
      expect((r['error'] as Map)['code'], -32601);
      expect((r['error'] as Map)['message'], contains('resources/list'));
    });
  });

  // T-361: nothing watched the process itself — a crashed claude just
  // looked thoughtful forever.
  group('process exit (T-361)', () {
    test('exit emits SessionEnd with code + stderr tail and clears busy', () async {
      final ends = <SessionEnd>[];
      session.endedStream.listen(ends.add);
      session.send('do something');
      await pumpEventQueue();
      expect(session.busy, isTrue, reason: 'a send marks the turn in flight');

      proc.stderr.addAll(['boom: stack', 'fatal: died']);
      proc.exit.complete(70);
      await pumpEventQueue();

      expect(session.busy, isFalse, reason: 'a dead process is not thinking');
      expect(ends, hasLength(1));
      expect(ends.single.exitCode, 70);
      expect(ends.single.stderrTail, ['boom: stack', 'fatal: died']);
      expect(session.end, same(ends.single), reason: 'late binders replay via the getter');
    });

    test('exit clears a pending prompt — it can never be answered', () async {
      final pendings = <ToolPrompt?>[];
      session.pendingPromptStream.listen(pendings.add);
      proc.emit(canUseTool('p1'));
      await pumpEventQueue();
      expect(session.pendingPrompt, isNotNull);

      proc.exit.complete(1);
      await pumpEventQueue();
      expect(session.pendingPrompt, isNull);
      expect(pendings.last, isNull, reason: 'the composer swaps back from the prompt UI');
    });

    test('a deliberate dispose suppresses the exit watch', () async {
      final p = _FakeProc();
      final s = StreamJsonSession(p)..start();
      await s.dispose();
      p.exit.complete(9); // the kill's exit must not surface as a crash
      await pumpEventQueue();
      expect(s.end, isNull);
    });
  });

  group('SessionEnd.reason (T-437)', () {
    test('is the last non-empty stderr line — the CLI error', () {
      const end = SessionEnd(exitCode: 1, stderrTail: ['warming up', '', 'Error: Session ID abc is already in use.', '  ']);
      expect(end.reason, 'Error: Session ID abc is already in use.');
    });

    test('is empty when stderr was silent', () {
      expect(const SessionEnd(exitCode: 1, stderrTail: []).reason, isEmpty);
      expect(const SessionEnd(exitCode: 1, stderrTail: ['', '   ']).reason, isEmpty);
    });

    test('caps a very long line so it cannot blow out the status line', () {
      final end = SessionEnd(exitCode: 1, stderrTail: ['x' * 500]);
      expect(end.reason.length, 201); // 200 chars + ellipsis
      expect(end.reason.endsWith('…'), isTrue);
    });
  });

  group('BoundedLineBuffer', () {
    test('keeps only the last cap lines', () {
      final b = BoundedLineBuffer(cap: 3);
      for (var i = 0; i < 5; i++) {
        b.add('line $i');
      }
      expect(b.lines, ['line 2', 'line 3', 'line 4']);
    });
  });

  group('workflow runs (T-416)', () {
    test('accumulates a run from system task_* events keyed by tool_use_id', () async {
      final p = _FakeProc();
      final session = StreamJsonSession(p)..start();
      final snapshots = <Map<String, WorkflowRun>>[];
      session.workflowsStream.listen(snapshots.add);

      p.emit(
        jsonEncode({
          'type': 'system',
          'subtype': 'task_started',
          'task_id': 'wy01fihjt',
          'tool_use_id': 'toolu_wf',
          'description': 'Two agents',
          'workflow_name': 'parallel-words',
        }),
      );
      p.emit(
        jsonEncode({
          'type': 'system',
          'subtype': 'task_progress',
          'tool_use_id': 'toolu_wf',
          'workflow_progress': [
            {'type': 'workflow_agent', 'index': 1, 'label': 'alpha', 'state': 'start'},
            {'type': 'workflow_agent', 'index': 2, 'label': 'beta', 'state': 'done'},
          ],
        }),
      );
      p.emit(jsonEncode({'type': 'system', 'subtype': 'task_notification', 'tool_use_id': 'toolu_wf', 'status': 'completed', 'summary': 'done'}));
      await pumpEventQueue();

      final run = session.workflows['toolu_wf'];
      expect(run, isNotNull);
      expect(run!.name, 'parallel-words');
      expect(run.agentCount, 2);
      expect(run.doneCount, 1);
      expect(run.done, isTrue);
      expect(run.summary, 'done');
      expect(snapshots, isNotEmpty);
    });

    test('a workflow system event produces no conversation item', () async {
      final p = _FakeProc();
      final session = StreamJsonSession(p)..start();
      final items = <ConversationItem>[];
      session.items.listen(items.add);
      p.emit(jsonEncode({'type': 'system', 'subtype': 'task_progress', 'tool_use_id': 'toolu_wf', 'workflow_progress': const []}));
      await pumpEventQueue();
      expect(items, isEmpty);
      expect(session.workflows.containsKey('toolu_wf'), isTrue);
    });
  });
}
