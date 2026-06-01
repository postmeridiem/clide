/// Drives a `claude` process in stream-json mode (T-165, D-77).
///
/// Instead of running an interactive TUI in tmux and tailing the transcript
/// file, clide spawns `claude --input-format stream-json --output-format
/// stream-json --verbose`, reads its line-delimited JSON events, and turns
/// them into the same [ConversationItem] / [SessionStatus] stream the
/// transcript reader produced — so the conversation view, controller, and
/// status surface are reused unchanged. User input is written to the
/// process stdin as a stream-json user message.
///
/// The event-stream parsing reuses [parseTranscriptChunk]: stream-json
/// `assistant` / `user` events carry the same `message.content` block shapes
/// as transcript records. Status fields the transcript parser doesn't read
/// (permission mode on the `init` event) are pulled here.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/claude/src/transcript_reader.dart';

/// The claude subprocess, abstracted so tests drive it without spawning.
abstract class StreamJsonProcess {
  /// stdout, one JSON event per line.
  Stream<String> get lines;

  /// Write one JSON message line to stdin.
  void writeLine(String line);

  /// Terminate the process.
  Future<void> kill();
}

/// Production [StreamJsonProcess] backed by a real `claude` process.
class ClaudeStreamJsonProcess implements StreamJsonProcess {
  ClaudeStreamJsonProcess._(this._proc);

  final Process _proc;

  /// Spawn `claude` in stream-json mode. [sessionArgs] is `['--session-id', id]`
  /// for a new session or `['--resume', id]` to resume an existing one (T-161).
  static Future<ClaudeStreamJsonProcess> start({
    required List<String> sessionArgs,
    required String cwd,
    Map<String, String>? env,
  }) async {
    final proc = await Process.start(
      'claude',
      [
        '--input-format',
        'stream-json',
        '--output-format',
        'stream-json',
        '--verbose',
        // Route permission asks + AskUserQuestion to us over the control
        // channel as `can_use_tool` requests. Without `stdio` the CLI silently
        // auto-denies anything needing approval (D-78).
        '--permission-prompt-tool',
        'stdio',
        // Emit partial assistant messages as they stream in so the view
        // can update in real time (T-168).
        '--include-partial-messages',
        ...sessionArgs,
      ],
      workingDirectory: cwd,
      environment: env,
    );
    return ClaudeStreamJsonProcess._(proc);
  }

  @override
  Stream<String> get lines => _proc.stdout.transform(utf8.decoder).transform(const LineSplitter());

  @override
  void writeLine(String line) => _proc.stdin.writeln(line);

  @override
  Future<void> kill() async {
    _proc.kill();
  }
}

/// An in-process MCP server clide hosts for a session, entirely over the
/// stream-json control channel — no subprocess, no `--mcp-config`, no socket
/// (T-170, D-77).
///
/// Registration: the session lists this server's [name] in the `initialize`
/// control_request's `sdkMcpServers`. claude then drives the MCP JSON-RPC
/// handshake (`initialize` → `notifications/initialized` → `tools/list`) and
/// each `tools/call` as `mcp_message` control_requests, which the session
/// answers with the JSON-RPC result wrapped in `response.response.mcp_response`.
/// claude exposes the tools to the model as `mcp__<name>__<tool>` and gates each
/// call through the normal `can_use_tool` channel. Verified live against claude
/// 2.1.150 — see docs/spikes/cc-stream-json-control-protocol-2.1.150.md §6.
///
/// Implementations stay Flutter-free (this whole module runs under `dart test`).
abstract class McpServer {
  /// Server name; claude addresses it as `server_name` and exposes its tools
  /// as `mcp__<name>__<tool>`.
  String get name;

  /// Reported in the `initialize` result's `serverInfo.version`.
  String get version;

  /// Tool definitions returned for `tools/list` — each
  /// `{name, description, inputSchema}`.
  List<Map<String, dynamic>> get tools;

  /// Run a `tools/call`. Returns an MCP result object
  /// (`{content: [{type: 'text', text: ...}], isError: bool}`).
  Future<Map<String, dynamic>> callTool(String name, Map<String, dynamic> arguments);
}

/// An interactive prompt Claude is blocked on, from the stream-json control
/// channel (a `can_use_tool` control_request) — a tool needing permission, or
/// an `AskUserQuestion`. Pure data; the decision goes back via
/// [StreamJsonSession.resolvePrompt]. Not a conversation item — prompts are
/// *interaction*, surfaced in the composer zone, not the transcript (D-78).
class ToolPrompt {
  const ToolPrompt({
    required this.promptId,
    required this.toolName,
    required this.displayName,
    required this.input,
    this.description,
    this.toolUseId = '',
    this.permissionSuggestions = const [],
  });

  /// The control_request `request_id` — the key passed to [StreamJsonSession.resolvePrompt].
  final String promptId;

  /// The gated `tool_use_id` (matches the preceding assistant tool_use).
  final String toolUseId;

  /// Tool being requested, e.g. `Write` or `AskUserQuestion`.
  final String toolName;

  /// Human label (`display_name`), falls back to [toolName].
  final String displayName;

  /// Optional one-line summary (`description`).
  final String? description;

  /// The tool's proposed input — echoed back (possibly modified) on allow.
  final Map<String, dynamic> input;

  /// Permission-rule suggestions from the request (e.g. a `setMode` /
  /// `localSettings` entry). Non-empty → an "allow & don't ask again" path is
  /// available; echo a chosen entry back as `updatedPermissions` (D-78).
  final List<dynamic> permissionSuggestions;

  /// AskUserQuestion is answered through the same channel (D-78).
  bool get isQuestion => toolName == 'AskUserQuestion';
}

/// A decision returned for a [ToolPrompt] over the control channel (D-78).
sealed class ToolDecision {
  const ToolDecision();
  Map<String, dynamic> toJson();
}

/// Allow the tool. [updatedInput] is REQUIRED by the protocol — pass the
/// request's input unchanged to allow as-is, or modified to alter the call.
/// For AskUserQuestion, include the `answers` map (question text → label).
///
/// [updatedPermissions] echoes a permission suggestion back to skip future
/// prompts ("don't ask again"). [followUpNote] is NOT part of the protocol —
/// the protocol has no allow-with-message — so the session sends it as a
/// separate user message right after allowing (D-78).
final class AllowTool extends ToolDecision {
  const AllowTool(this.updatedInput, {this.updatedPermissions, this.followUpNote});
  final Map<String, dynamic> updatedInput;
  final List<dynamic>? updatedPermissions;
  final String? followUpNote;
  @override
  Map<String, dynamic> toJson() => {
        'behavior': 'allow',
        'updatedInput': updatedInput,
        if (updatedPermissions != null && updatedPermissions!.isNotEmpty) 'updatedPermissions': updatedPermissions,
      };
}

/// Deny the tool with a user-facing [message] (required by the protocol).
final class DenyTool extends ToolDecision {
  const DenyTool(this.message);
  final String message;
  @override
  Map<String, dynamic> toJson() => {'behavior': 'deny', 'message': message};
}

/// Parses a [StreamJsonProcess]'s events into conversation items + status,
/// answers control-channel prompts, and sends user messages.
class StreamJsonSession {
  StreamJsonSession(this._proc, {List<McpServer> mcpServers = const []}) : _mcpServers = mcpServers;

  final StreamJsonProcess _proc;

  /// In-process MCP servers hosted for this session over the control channel
  /// (T-170). Declared in the `initialize` handshake; their `mcp_message`
  /// round-trips are answered by [_handleMcpMessage].
  final List<McpServer> _mcpServers;
  final _items = StreamController<ConversationItem>.broadcast();
  final _statusCtl = StreamController<SessionStatus>.broadcast();
  final _sessionIdCtl = StreamController<String>.broadcast();
  StreamSubscription<String>? _sub;
  SessionStatus _status = const SessionStatus();
  String? _claudeSessionId;
  int _localSeq = 0;

  /// Token-by-token streaming state (T-168, wire shape verified by T-184).
  ///
  /// With `--include-partial-messages`, claude emits the in-progress reply as
  /// `stream_event` envelopes wrapping Anthropic streaming deltas
  /// (`message_start` → `content_block_delta{text_delta}` → …), interleaved
  /// with the final per-block `assistant` events. We accumulate the streaming
  /// text per message id and emit a placeholder item with a stable
  /// `partial-<message.id>` uuid so the controller upserts it in place as it
  /// grows. The final text `assistant` event then reuses that same uuid to
  /// finalise the placeholder; tool_use / thinking blocks keep their own uuids
  /// and append in order. See docs/spikes (§ stream_event) for the captured
  /// shape.
  final _streamText = <String, String>{};

  /// Message ids whose streamed text placeholder has already been finalised by
  /// a real (single-text-block) `assistant` event — so a rare second text
  /// block for the same message appends normally instead of overwriting it.
  final _streamFinalized = <String>{};

  /// The message id currently streaming (`content_block_delta` events carry no
  /// message id, so we track the one announced by the last `message_start`).
  String? _streamingMsgId;

  /// Prompts awaiting a [resolvePrompt] decision, in arrival order. The head
  /// is the one currently shown in the composer zone.
  final _queue = <ToolPrompt>[];
  final _pendingCtl = StreamController<ToolPrompt?>.broadcast();

  /// tool_use_ids that surfaced as a prompt — the view hides their raw
  /// tool-use card while pending (it shows as a prompt) but keeps the result.
  final _promptedToolUses = <String>{};

  /// Resolved outcome per prompted tool_use_id: true = allowed, false = denied.
  /// Absent = still pending. The view shows resolved tool-uses collapsed with a
  /// green/red border (D-78).
  final _toolUseOutcome = <String, bool>{};

  /// Read-only views for the conversation view.
  Set<String> get promptedToolUseIds => _promptedToolUses;
  Map<String, bool> get toolUseOutcomes => _toolUseOutcome;

  /// Whether a turn is in flight (between a send and claude's `result`). Drives
  /// the composer's Stop affordance.
  bool _busy = false;
  final _busyCtl = StreamController<bool>.broadcast();
  bool get busy => _busy;
  Stream<bool> get busyStream => _busyCtl.stream;

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    _busyCtl.add(value);
  }

  /// The prompt currently awaiting a decision (queue head), or null.
  ToolPrompt? get pendingPrompt => _queue.isEmpty ? null : _queue.first;

  /// Emits the current pending prompt (or null) whenever it changes — the
  /// composer zone swaps between the prompt UI and the text input on this.
  Stream<ToolPrompt?> get pendingPromptStream => _pendingCtl.stream;

  /// Conversation items, in arrival order (assistant turns + the local echo
  /// of the user's own messages).
  Stream<ConversationItem> get items => _items.stream;

  /// The claude-assigned session id, resolved from the first event that carries
  /// `session_id` (the `init` event). For a session started with `--session-id`
  /// this equals the id we passed; for a `--fork-session` branch (T-185) it is
  /// the NEW id claude minted, which the orchestrator folds back into the
  /// [ManagedSession]. Null until the init event arrives.
  String? get claudeSessionId => _claudeSessionId;

  /// Fires once with the resolved [claudeSessionId] when the init event lands.
  Stream<String> get sessionIdResolved => _sessionIdCtl.stream;

  /// Session status (model / permission-mode / context tokens), on change.
  Stream<SessionStatus> get statusStream => _statusCtl.stream;

  /// The latest known status — the current value [statusStream] last emitted.
  SessionStatus get status => _status;

  /// Begin consuming the process's event stream.
  void start() {
    _sub = _proc.lines.listen(_onLine, onError: (Object _) {});
    // Declaring our in-process MCP servers in the `initialize` handshake is what
    // makes claude drive their JSON-RPC over `mcp_message` (T-170). Only sent
    // when we actually host a server, so a plain session is unchanged.
    if (_mcpServers.isNotEmpty) {
      _proc.writeLine(jsonEncode({
        'type': 'control_request',
        'request_id': 'init-${_localSeq++}',
        'request': {
          'subtype': 'initialize',
          'hooks': <String, dynamic>{},
          'sdkMcpServers': [for (final s in _mcpServers) s.name],
        },
      }));
    }
  }

  void _onLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return;
    Map<String, dynamic> ev;
    try {
      ev = (jsonDecode(trimmed) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    // Capture the claude-assigned session id from the first event that carries
    // it (the init event). For a --fork-session branch this is the NEW id, which
    // the orchestrator folds back into the ManagedSession (T-185).
    if (_claudeSessionId == null) {
      final sid = ev['session_id'];
      if (sid is String && sid.isNotEmpty) {
        _claudeSessionId = sid;
        _sessionIdCtl.add(sid);
      }
    }
    // Control-channel requests (permission asks, AskUserQuestion) must be
    // routed out of the normal event stream and answered (D-78).
    if (ev['type'] == 'control_request') {
      _onControlRequest(ev);
      return;
    }
    // A `result` ends the turn — clear the busy/interruptible state and reset
    // streaming state so the next turn is fresh.
    if (ev['type'] == 'result') {
      _setBusy(false);
      _streamText.clear();
      _streamFinalized.clear();
      _streamingMsgId = null;
    }

    // Token-by-token streaming: `stream_event` envelopes carry the in-progress
    // reply as Anthropic streaming deltas (T-168, shape confirmed by T-184).
    if (ev['type'] == 'stream_event') {
      _onStreamEvent(ev);
      return;
    }

    // Finalise a streamed reply: when the real text `assistant` event for a
    // message we streamed arrives, reuse the placeholder's `partial-<id>` uuid
    // so the controller replaces the placeholder in place rather than appending
    // a duplicate. Only a single-text-block event finalises (tool_use/thinking
    // blocks are separate events that keep their own uuids and append in order);
    // a second text block for the same id also appends normally.
    if (ev['type'] == 'assistant') {
      final message = ev['message'];
      final msgId = message is Map ? message['id'] as String? : null;
      final content = message is Map ? message['content'] : null;
      final isSingleText = content is List && content.length == 1 && content.single is Map && (content.single as Map)['type'] == 'text';
      if (msgId != null && _streamText.containsKey(msgId) && !_streamFinalized.contains(msgId) && isSingleText) {
        ev = {...ev, 'uuid': 'partial-$msgId'};
        _streamFinalized.add(msgId);
      }
    }

    // Items + assistant model/tokens reuse the transcript parser (identical
    // message.content shapes). Parse the possibly-rewritten event.
    final parsed = parseTranscriptChunk(jsonEncode(ev));
    for (final item in parsed.items) {
      _items.add(item);
    }
    // The `init` event carries permission mode (no `permission-mode` record
    // exists in stream-json); fold it in alongside the parsed deltas.
    _mergeStatus(parsed.status.merge(_statusFromEvent(ev)));
  }

  /// Handle a `stream_event` (a wrapped Anthropic streaming delta). We render
  /// only assistant *text* token-by-token: `message_start` announces the id,
  /// `content_block_delta{text_delta}` grows it. Each tick emits a placeholder
  /// item with a stable `partial-<id>` uuid so the controller upserts in place;
  /// the final `assistant` event finalises it (see [_onLine]). Thinking and
  /// tool_use blocks are left to render from their final `assistant` events.
  void _onStreamEvent(Map<String, dynamic> ev) {
    final event = ev['event'];
    if (event is! Map) return;
    switch (event['type']) {
      case 'message_start':
        final msg = event['message'];
        final id = msg is Map ? msg['id'] as String? : null;
        if (id != null) {
          _streamingMsgId = id;
          _streamText[id] = '';
          _streamFinalized.remove(id);
        }
      case 'content_block_delta':
        final delta = event['delta'];
        final msgId = _streamingMsgId;
        if (delta is Map && delta['type'] == 'text_delta' && msgId != null) {
          final text = (_streamText[msgId] ?? '') + (delta['text'] as String? ?? '');
          _streamText[msgId] = text;
          final synthetic = {
            'type': 'assistant',
            'message': {
              'id': msgId,
              'role': 'assistant',
              'content': [
                {'type': 'text', 'text': text},
              ],
            },
            'uuid': 'partial-$msgId',
          };
          final parsed = parseTranscriptChunk(jsonEncode(synthetic));
          for (final item in parsed.items) {
            _items.add(item);
          }
        }
      case 'message_stop':
        _streamingMsgId = null;
    }
  }

  /// Handle an inbound `control_request`. `can_use_tool` becomes a [ToolPrompt]
  /// item the UI resolves; every other subtype is answered with an error so
  /// the turn never hangs waiting on us (D-78).
  void _onControlRequest(Map<String, dynamic> ev) {
    final rid = ev['request_id'] as String?;
    final request = ev['request'];
    if (rid == null || request is! Map) return;
    if (request['subtype'] == 'can_use_tool') {
      final toolName = request['tool_name'] as String? ?? '';
      final input = (request['input'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final tuid = request['tool_use_id'] as String? ?? '';
      if (tuid.isNotEmpty) _promptedToolUses.add(tuid);
      _queue.add(ToolPrompt(
        promptId: rid,
        toolName: toolName,
        displayName: request['display_name'] as String? ?? toolName,
        description: request['description'] as String?,
        toolUseId: request['tool_use_id'] as String? ?? '',
        input: input,
        permissionSuggestions: (request['permission_suggestions'] as List?) ?? const [],
      ));
      _pendingCtl.add(pendingPrompt);
      return; // awaits resolvePrompt
    }
    // An MCP JSON-RPC round-trip for one of our hosted servers (T-170).
    if (request['subtype'] == 'mcp_message') {
      unawaited(_handleMcpMessage(rid, request.cast<String, dynamic>()));
      return;
    }
    _proc.writeLine(jsonEncode({
      'type': 'control_response',
      'response': {'subtype': 'error', 'request_id': rid, 'error': 'Unsupported control request subtype: ${request['subtype']}'},
    }));
  }

  /// Answer an `mcp_message` control_request: dispatch its JSON-RPC to the named
  /// hosted [McpServer] and reply with the result under `response.mcp_response`
  /// (T-170). Every request — including notifications — is answered, or claude's
  /// turn stalls waiting on us.
  Future<void> _handleMcpMessage(String rid, Map<String, dynamic> request) async {
    final serverName = request['server_name'] as String?;
    final message = (request['message'] as Map?)?.cast<String, dynamic>();
    final server = _mcpServerNamed(serverName);
    final Map<String, dynamic> mcpResponse;
    if (server == null || message == null) {
      mcpResponse = {
        'jsonrpc': '2.0',
        'id': message?['id'],
        'error': {'code': -32601, 'message': 'Unknown MCP server: $serverName'},
      };
    } else {
      mcpResponse = await _dispatchMcp(server, message);
    }
    _proc.writeLine(jsonEncode({
      'type': 'control_response',
      'response': {
        'subtype': 'success',
        'request_id': rid,
        'response': {'mcp_response': mcpResponse}
      },
    }));
  }

  McpServer? _mcpServerNamed(String? name) {
    for (final s in _mcpServers) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Map one MCP JSON-RPC method to its response object. The framing (envelope,
  /// protocol version, capabilities) lives here so a CC drift is a one-file fix.
  Future<Map<String, dynamic>> _dispatchMcp(McpServer server, Map<String, dynamic> msg) async {
    final method = msg['method'] as String?;
    final id = msg['id'];
    switch (method) {
      case 'initialize':
        final params = (msg['params'] as Map?)?.cast<String, dynamic>();
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': params?['protocolVersion'] ?? '2025-11-25',
            'capabilities': {
              'tools': {'listChanged': false},
            },
            'serverInfo': {'name': server.name, 'version': server.version},
          },
        };
      case 'notifications/initialized':
        return {'jsonrpc': '2.0', 'id': id ?? 0, 'result': <String, dynamic>{}};
      case 'tools/list':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {'tools': server.tools},
        };
      case 'tools/call':
        final params = (msg['params'] as Map?)?.cast<String, dynamic>() ?? const {};
        final toolName = params['name'] as String? ?? '';
        final args = (params['arguments'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final result = await server.callTool(toolName, args);
        return {'jsonrpc': '2.0', 'id': id, 'result': result};
      default:
        return {
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32601, 'message': 'Method not found: $method'},
        };
    }
  }

  /// Answer a [ToolPrompt] over the control channel, by its
  /// [ToolPrompt.promptId]. No-op if unknown or already resolved. Advances the
  /// queue so the next pending prompt (if any) surfaces.
  void resolvePrompt(String promptId, ToolDecision decision) {
    final idx = _queue.indexWhere((p) => p.promptId == promptId);
    if (idx < 0) return; // unknown / already resolved
    final prompt = _queue.removeAt(idx);
    if (prompt.toolUseId.isNotEmpty) _toolUseOutcome[prompt.toolUseId] = decision is AllowTool;
    _proc.writeLine(jsonEncode({
      'type': 'control_response',
      'response': {'subtype': 'success', 'request_id': promptId, 'response': decision.toJson()},
    }));
    if (decision is AllowTool) {
      // The prompt card is ephemeral (it vanishes once resolved), so leave a
      // compact record of an answered question in the conversation log (D-78).
      if (prompt.isQuestion) {
        final answers = decision.updatedInput['answers'];
        if (answers is Map && answers.isNotEmpty) {
          final summary = answers.entries.map((e) => '${e.key} → ${e.value}').join('; ');
          _items.add(UserMessage(uuid: 'local-${_localSeq++}', timestamp: DateTime.now(), isSidechain: false, text: '✓ answered: $summary'));
        }
      }
      // The protocol has no allow-with-message, so an allow note rides as a
      // follow-up user message right after the approval (D-78).
      if (decision.followUpNote?.trim().isNotEmpty ?? false) send(decision.followUpNote!.trim());
    }
    _pendingCtl.add(pendingPrompt);
  }

  SessionStatus _statusFromEvent(Map<String, dynamic> j) {
    switch (j['type'] as String?) {
      case 'system':
        if (j['subtype'] == 'init') {
          return SessionStatus(model: j['model'] as String?, permissionMode: j['permissionMode'] as String?);
        }
      case 'result':
        // Extract cumulative cost and context-window size from the result event
        // (T-168). `total_cost_usd` is the turn cost. `modelUsage.<model>.contextWindow`
        // is the model's context limit in tokens (e.g. 1_000_000 for claude-opus-4-7[1m]).
        final costRaw = j['total_cost_usd'];
        final cost = costRaw is num ? costRaw.toDouble() : null;
        int? contextWindow;
        final modelUsage = j['modelUsage'];
        if (modelUsage is Map) {
          for (final entry in modelUsage.values) {
            if (entry is Map) {
              final cw = entry['contextWindow'];
              if (cw is num) {
                contextWindow = cw.toInt();
                break; // first model entry wins
              }
            }
          }
        }
        if (cost != null || contextWindow != null) {
          return SessionStatus(cost: cost, contextWindow: contextWindow);
        }
      case 'rate_limit_event':
        // Surface the rate-limit status as a compact string (T-168).
        final info = j['rate_limit_info'];
        if (info is Map) {
          final status = info['status'] as String?;
          // `resetsAt` may arrive as a unix-epoch number (seconds) or an
          // ISO string depending on the claude build — accept both.
          final resetsRaw = info['resetsAt'];
          DateTime? resetsTime;
          String? resetsText;
          if (resetsRaw is num) {
            resetsTime = DateTime.fromMillisecondsSinceEpoch((resetsRaw * 1000).round(), isUtc: true);
          } else if (resetsRaw is String) {
            resetsTime = DateTime.tryParse(resetsRaw);
            resetsText = resetsRaw;
          }
          if (status != null) {
            String label = 'rate limited';
            if (resetsTime != null) {
              final t = resetsTime.toLocal();
              label = 'rate limited — resets ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            } else if (resetsText != null) {
              label = 'rate limited — resets $resetsText';
            }
            return SessionStatus(rateLimitInfo: label);
          }
        }
    }
    return const SessionStatus();
  }

  void _mergeStatus(SessionStatus delta) {
    if (delta.isEmpty) return;
    final next = _status.merge(delta);
    if (next != _status) {
      _status = next;
      _statusCtl.add(next);
    }
  }

  /// Send [text] to claude as a stream-json user message, and echo it locally
  /// so it renders immediately (stream-json doesn't replay stdin without
  /// `--replay-user-messages`).
  void send(String text) {
    _proc.writeLine(jsonEncode({
      'type': 'user',
      'message': {'role': 'user', 'content': text},
    }));
    _items.add(UserMessage(
      uuid: 'local-${_localSeq++}',
      timestamp: DateTime.now(),
      isSidechain: false,
      text: text,
    ));
    _setBusy(true);
  }

  /// Interrupt the running turn (the escape hatch for a runaway — D-78). Sends
  /// the `interrupt` control_request; claude cancels the current turn and ends
  /// it with a `result`, which clears [busy]. Safe to call when idle.
  void interrupt() {
    _proc.writeLine(jsonEncode({
      'type': 'control_request',
      'request_id': 'interrupt-${_localSeq++}',
      'request': {'subtype': 'interrupt'},
    }));
  }

  /// Set the session's permission mode (T-181, D-77). Sends a
  /// `set_permission_mode` control_request; fire-and-forget, mirroring
  /// [interrupt]. [mode] must be one of the claude-recognised strings:
  /// `default`, `acceptEdits`, `plan`, `bypassPermissions`.
  ///
  /// The safe trio (default → acceptEdits → plan → default) is cycled by the
  /// cockpit badge's plain click; bypassPermissions is reachable only via a
  /// confirmed shift-click (T-181).
  void setPermissionMode(String mode) {
    _proc.writeLine(jsonEncode({
      'type': 'control_request',
      'request_id': 'set-perm-${_localSeq++}',
      'request': {'subtype': 'set_permission_mode', 'mode': mode},
    }));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _proc.kill();
    await _items.close();
    await _statusCtl.close();
    await _sessionIdCtl.close();
    await _pendingCtl.close();
    await _busyCtl.close();
  }
}
