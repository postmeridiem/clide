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
import 'package:clide/builtin/claude/src/turn_signals.dart';
import 'package:clide/builtin/claude/src/workflow_run.dart';
import 'package:clide/src/util/value_stream.dart';

/// The claude subprocess, abstracted so tests drive it without spawning.
/// Fakes `extend` this and override what they drive; the defaults below
/// describe a process with no real child behind it.
abstract class StreamJsonProcess {
  /// stdout, one JSON event per line.
  Stream<String> get lines;

  /// Write one JSON message line to stdin.
  void writeLine(String line);

  /// Terminate the process.
  Future<void> kill();

  /// The last lines of the child's stderr, drained continuously so the pipe
  /// can never fill and block the child mid-turn (T-361). Default: none.
  List<String> get stderrTail => const [];

  /// Completes with the child's exit code, or null when there is no real
  /// process to watch (fakes that never "exit").
  Future<int>? get exitCode => null;
}

/// A bounded FIFO of the most recent lines — the stderr tail kept for
/// post-mortem diagnostics while the stream itself is drained and dropped.
class BoundedLineBuffer {
  BoundedLineBuffer({this.cap = 100});

  final int cap;
  final List<String> _lines = [];

  void add(String line) {
    _lines.add(line);
    if (_lines.length > cap) _lines.removeAt(0);
  }

  List<String> get lines => List.unmodifiable(_lines);
}

/// Production [StreamJsonProcess] backed by a real `claude` process.
class ClaudeStreamJsonProcess extends StreamJsonProcess {
  ClaudeStreamJsonProcess._(this._proc) {
    // Drain stderr from the moment the process exists — with --verbose the
    // CLI chats on stderr, and an undrained 64KB pipe blocks the child
    // mid-turn with zero diagnostics (T-361). Keep a tail for post-mortems.
    _proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(_stderr.add, onError: (Object _) {});
  }

  final Process _proc;
  final BoundedLineBuffer _stderr = BoundedLineBuffer();

  /// Spawn `claude` in stream-json mode. [sessionArgs] is `['--session-id', id]`
  /// for a new session or `['--resume', id]` to resume an existing one (T-161).
  static Future<ClaudeStreamJsonProcess> start({required List<String> sessionArgs, required String cwd, Map<String, String>? env}) async {
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
    // Await the process's ACTUAL death, not just the signal (T-437). clide
    // respawns the primary on the SAME deterministic --session-id right after
    // /clear; if the old process is still alive (or still flushing its
    // transcript) when the new one starts, claude 2.1.177 rejects the id with
    // "Session ID … is already in use" and the respawn exits 1. SIGTERM first
    // (claude cleans its session registry on it), escalate to SIGKILL if it
    // doesn't go, and only return once exitCode has resolved.
    _proc.kill();
    try {
      await _proc.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _proc.kill(ProcessSignal.sigkill);
      await _proc.exitCode;
    }
  }

  @override
  List<String> get stderrTail => _stderr.lines;

  @override
  Future<int> get exitCode => _proc.exitCode;
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

/// A model selectable for a session, from the `initialize` control_response's
/// `models[]` (T-408). Pure data, Flutter-free.
class ModelOption {
  const ModelOption({required this.value, required this.displayName, this.description = ''});

  /// The id/alias sent in `set_model` — e.g. `default`, `sonnet`, `opus`.
  final String value;

  /// Human label, e.g. `Sonnet`.
  final String displayName;

  /// One-line blurb shown muted next to the label.
  final String description;
}

/// Effort levels `claude --effort` accepts (probed against 2.1.175). There is
/// NO set_effort control subtype (probed: rejected), so changing effort
/// respawns the session with the flag — resume keeps the conversation (T-412).
/// Expressed as [ModelOption]s so the /effort picker reuses the /model card.
const List<ModelOption> kEffortLevels = [
  ModelOption(value: 'low', displayName: 'low', description: 'fastest, minimal thinking'),
  ModelOption(value: 'medium', displayName: 'medium', description: 'balanced'),
  ModelOption(value: 'high', displayName: 'high', description: 'thorough'),
  ModelOption(value: 'xhigh', displayName: 'xhigh', description: 'deeper reasoning'),
  ModelOption(value: 'max', displayName: 'max', description: 'maximum thinking budget'),
];

/// Permission modes for the /permissions picker (T-413), set over the
/// set_permission_mode control request. Bypass is last and explicit — the
/// footgun stays visible but never the default reach (T-181).
const List<ModelOption> kPermissionModes = [
  ModelOption(value: 'default', displayName: 'default', description: 'ask before sensitive tools'),
  ModelOption(value: 'acceptEdits', displayName: 'acceptEdits', description: 'auto-approve file edits'),
  ModelOption(value: 'plan', displayName: 'plan', description: 'read-only planning mode'),
  ModelOption(value: 'bypassPermissions', displayName: 'bypassPermissions', description: 'no prompts at all — careful'),
];

/// Fallback picker entries for when the `initialize` response hasn't arrived
/// (or carried no models): the stable aliases every claude build accepts
/// (T-408). `default` resets to the CLI's configured model.
const List<ModelOption> kFallbackModels = [
  ModelOption(value: 'default', displayName: 'Default', description: 'recommended — the CLI\'s configured model'),
  ModelOption(value: 'sonnet', displayName: 'Sonnet', description: 'fast, great for everyday tasks'),
  ModelOption(value: 'opus', displayName: 'Opus', description: 'most capable'),
  ModelOption(value: 'haiku', displayName: 'Haiku', description: 'fastest, lightweight'),
];

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
///
/// [quiet] marks a deliberate, user-initiated denial that the user already
/// understands (e.g. "Deny & simplify", T-340) — the resulting error tool-result
/// should fold to a muted card rather than shout as a red failure. Off by
/// default, so a genuine/unexpected denial still renders prominently.
final class DenyTool extends ToolDecision {
  const DenyTool(this.message, {this.quiet = false});
  final String message;
  final bool quiet;
  @override
  Map<String, dynamic> toJson() => {'behavior': 'deny', 'message': message};
}

/// Parses a [StreamJsonProcess]'s events into conversation items + status,
/// answers control-channel prompts, and sends user messages.
/// Terminal session end: the claude process exited (crash or otherwise).
/// Carries the exit code and the drained stderr tail for diagnostics.
class SessionEnd {
  const SessionEnd({required this.exitCode, required this.stderrTail});

  final int exitCode;
  final List<String> stderrTail;

  /// The most recent non-empty stderr line — the CLI's own error message when
  /// it dies (e.g. "Session ID … is already in use") — for surfacing in the
  /// pane so a non-zero exit is never an opaque "code 1" (T-437). Empty when
  /// stderr was silent; capped so a stray long line can't blow out the status
  /// line.
  String get reason {
    for (final line in stderrTail.reversed) {
      final t = line.trim();
      if (t.isEmpty) continue;
      return t.length > 200 ? '${t.substring(0, 200)}…' : t;
    }
    return '';
  }
}

class StreamJsonSession {
  StreamJsonSession(this._proc, {List<McpServer> mcpServers = const [], DateTime Function()? now}) : _mcpServers = mcpServers, _now = now ?? DateTime.now;

  final StreamJsonProcess _proc;

  /// In-process MCP servers hosted for this session over the control channel
  /// (T-170). Declared in the `initialize` handshake; their `mcp_message`
  /// round-trips are answered by [_handleMcpMessage].
  final List<McpServer> _mcpServers;
  final _items = StreamController<ConversationItem>.broadcast();
  // State, not events — replay-latest so a subscriber that binds after the
  // init event still sees the current status (T-386; root cause of T-274).
  final _statusCtl = ValueStream<SessionStatus>();
  final _sessionIdCtl = StreamController<String>.broadcast();
  StreamSubscription<String>? _sub;
  SessionStatus _status = const SessionStatus();
  String? _claudeSessionId;
  int _localSeq = 0;

  /// The `initialize` handshake's request id — its control_response carries
  /// the selectable `models[]` (T-408).
  String? _initRequestId;

  /// In-flight `set_model` request ids → the model the status held before the
  /// optimistic merge, so an error response can roll it back (T-408).
  final _pendingSetModel = <String, String?>{};

  List<ModelOption> _availableModels = const [];

  /// Models selectable for this session, from the `initialize` response.
  /// Empty until that response arrives (callers fall back to
  /// [kFallbackModels]).
  List<ModelOption> get availableModels => _availableModels;

  final _modelErrorCtl = StreamController<String>.broadcast();

  /// Errors from rejected `set_model` requests (e.g. an unknown model name),
  /// for the pane to surface (T-408).
  Stream<String> get modelErrors => _modelErrorCtl.stream;

  final _phaseCtl = ValueStream<TurnPhase>.seeded(TurnPhase.idle);

  /// What the model is doing inside the current turn (T-557).
  ///
  /// Replay-latest, so a late subscriber is not told `idle` while a turn runs.
  /// This is the honest thinking-versus-answering signal: the CLI streams a
  /// `thinking` content block before the `text` one, which clide previously
  /// discarded, leaving consumers to infer the split from the `partial-` uuid
  /// prefix — which does not mean what it looks like.
  Stream<TurnPhase> get phaseStream => _phaseCtl.stream;

  TurnPhase get phase => _phaseCtl.value;

  final _outcomeCtl = StreamController<TurnOutcome>.broadcast();

  /// How each turn ended (T-557). **No replay** — it is an event, not a state;
  /// a subscriber that missed one has missed it.
  Stream<TurnOutcome> get turnOutcomes => _outcomeCtl.stream;

  void _setPhase(TurnPhase p) {
    if (_phaseCtl.value == p) return;
    _phaseCtl.add(p);
  }

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
  final _pendingCtl = ValueStream<ToolPrompt?>.seeded(null);

  /// tool_use_ids that surfaced as a prompt — the view hides their raw
  /// tool-use card while pending (it shows as a prompt) but keeps the result.
  final _promptedToolUses = <String>{};

  /// Resolved outcome per prompted tool_use_id: true = allowed, false = denied.
  /// Absent = still pending. The view shows resolved tool-uses collapsed with a
  /// green/red border (D-78).
  final _toolUseOutcome = <String, bool>{};

  /// tool_use_ids whose error result should render folded + muted rather than as
  /// a loud red failure (T-340): expected, user-initiated denials (Deny &
  /// simplify, today) that the user already understands. The reusable extension
  /// point — add an id here at the moment you know its error is non-alarming.
  final _quietErrorToolUses = <String>{};

  /// Read-only views for the conversation view.
  Set<String> get promptedToolUseIds => _promptedToolUses;
  Map<String, bool> get toolUseOutcomes => _toolUseOutcome;
  Set<String> get quietErrorToolUseIds => _quietErrorToolUses;

  /// Live Workflow runs, keyed by their launching `Workflow` tool-use id
  /// (T-416). Accumulated from the out-of-band `system` task_* events the
  /// harness emits while a workflow runs in the background; the conversation
  /// card and the sidebar indicator both read this snapshot. Ephemeral — the
  /// events aren't in the resumed transcript, so this is empty on reload.
  final _workflows = <String, WorkflowRun>{};
  final _workflowsCtl = ValueStream<Map<String, WorkflowRun>>.seeded(const {});

  /// The current workflow runs, keyed by launching tool-use id.
  Map<String, WorkflowRun> get workflows => Map.unmodifiable(_workflows);

  /// Emits the workflow-run map whenever a `system` task event updates it.
  Stream<Map<String, WorkflowRun>> get workflowsStream => _workflowsCtl.stream;

  /// Whether a turn is in flight (between a send and claude's `result`). Drives
  /// the composer's Stop affordance.
  bool _busy = false;
  final _busyCtl = ValueStream<bool>.seeded(false);
  bool get busy => _busy;
  Stream<bool> get busyStream => _busyCtl.stream;

  DateTime? _busySince;

  /// When the turn in flight began, or null when idle (T-561).
  ///
  /// A fact about the session, so it is recorded where the fact happens rather
  /// than re-derived by whoever is watching. A consumer that stamped the rising
  /// edge itself would be right only if it were listening at the time — one
  /// binding mid-turn, or mounting after the app booted, would report elapsed
  /// time from when it *noticed*, which is a different and always-shorter number.
  DateTime? get busySince => _busySince;

  /// Injectable clock, so a test can assert the stamped instant rather than
  /// race it.
  final DateTime Function() _now;

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    // Only the rising edge is stamped: a turn keeps the instant it began for as
    // long as it runs, and idle has no turn to time.
    _busySince = value ? _now() : null;
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

  /// Non-null once the claude process has exited (T-361). Late binders read
  /// this; live listeners get [endedStream]. Never set by a deliberate
  /// [dispose] — only by the process dying underneath a live session.
  SessionEnd? get end => _end;
  SessionEnd? _end;
  final _endCtl = StreamController<SessionEnd>.broadcast();
  bool _disposed = false;

  /// Fires once when the process exits while the session is still live —
  /// a crashed/dead session must not just look thoughtful (T-361).
  Stream<SessionEnd> get endedStream => _endCtl.stream;

  /// Begin consuming the process's event stream.
  void start() {
    _sub = _proc.lines.listen(_onLine, onError: (Object _) {});
    // Watch the process itself: stdout EOF alone is ambiguous, the exit
    // code is not (T-361).
    final exit = _proc.exitCode;
    if (exit != null) unawaited(exit.then(_onExit));
    // The `initialize` handshake is side-effect-free (verified in the protocol
    // spike) and does double duty: declaring our in-process MCP servers is what
    // makes claude drive their JSON-RPC over `mcp_message` (T-170), and the
    // response's `models[]` feeds the /model picker (T-408).
    _initRequestId = 'init-${_localSeq++}';
    _proc.writeLine(
      jsonEncode({
        'type': 'control_request',
        'request_id': _initRequestId,
        'request': {
          'subtype': 'initialize',
          'hooks': <String, dynamic>{},
          'sdkMcpServers': [for (final s in _mcpServers) s.name],
        },
      }),
    );
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
    // Responses to OUR control requests: the initialize result (models) and
    // set_model acks/errors (T-408).
    if (ev['type'] == 'control_response') {
      _onControlResponse(ev);
      return;
    }
    // A `result` ends the turn — clear the busy/interruptible state and reset
    // streaming state so the next turn is fresh.
    if (ev['type'] == 'result') {
      _setBusy(false);
      _streamText.clear();
      _streamFinalized.clear();
      _streamingMsgId = null;
      // The turn is over however it went, so the phase resets before the
      // outcome is announced — a listener reacting to a failure should not find
      // the session still claiming to be answering.
      _setPhase(TurnPhase.idle);
      if (!_outcomeCtl.isClosed) _outcomeCtl.add(TurnOutcome.fromResult(ev));
    }

    // Token-by-token streaming: `stream_event` envelopes carry the in-progress
    // reply as Anthropic streaming deltas (T-168, shape confirmed by T-184).
    if (ev['type'] == 'stream_event') {
      _onStreamEvent(ev);
      return;
    }

    // Workflow run progress (T-416): the harness reports a backgrounded Workflow
    // tool's fan-out on out-of-band `system` task_* events keyed by the
    // launching tool-use id. Fold them into the run snapshot and notify; they
    // carry no conversation item, so don't fall through to the parser.
    if (isWorkflowSystemEvent(ev)) {
      _onWorkflowEvent(ev);
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
      case 'content_block_start':
        // The block's own type is the phase (T-557). Reading it here is what
        // makes thinking observable rather than inferred — the deltas that
        // follow carry no type of their own beyond `thinking_delta` /
        // `text_delta`, and the thinking ones were being dropped.
        final block = event['content_block'];
        final kind = block is Map ? block['type'] : null;
        if (kind == 'thinking') _setPhase(TurnPhase.thinking);
        if (kind == 'text') _setPhase(TurnPhase.answering);
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
        // `result` also resets this, but a turn that stops without one — an
        // interrupt, a dropped process — would otherwise leave the phase stuck
        // wherever it happened to be.
        _setPhase(TurnPhase.idle);
    }
  }

  /// Fold one workflow `system` task event into its run snapshot, keyed by the
  /// launching tool-use id, and publish the updated map (T-416).
  void _onWorkflowEvent(Map<String, dynamic> ev) {
    final id = ev['tool_use_id'] as String;
    final prior = _workflows[id] ?? WorkflowRun(toolUseId: id);
    _workflows[id] = prior.foldEvent(ev);
    _workflowsCtl.add(Map.unmodifiable(_workflows));
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
      _queue.add(
        ToolPrompt(
          promptId: rid,
          toolName: toolName,
          displayName: request['display_name'] as String? ?? toolName,
          description: request['description'] as String?,
          toolUseId: request['tool_use_id'] as String? ?? '',
          input: input,
          permissionSuggestions: (request['permission_suggestions'] as List?) ?? const [],
        ),
      );
      _pendingCtl.add(pendingPrompt);
      return; // awaits resolvePrompt
    }
    // An MCP JSON-RPC round-trip for one of our hosted servers (T-170).
    if (request['subtype'] == 'mcp_message') {
      unawaited(_handleMcpMessage(rid, request.cast<String, dynamic>()));
      return;
    }
    _proc.writeLine(
      jsonEncode({
        'type': 'control_response',
        'response': {'subtype': 'error', 'request_id': rid, 'error': 'Unsupported control request subtype: ${request['subtype']}'},
      }),
    );
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
    _proc.writeLine(
      jsonEncode({
        'type': 'control_response',
        'response': {
          'subtype': 'success',
          'request_id': rid,
          'response': {'mcp_response': mcpResponse},
        },
      }),
    );
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
    if (prompt.toolUseId.isNotEmpty) {
      _toolUseOutcome[prompt.toolUseId] = decision is AllowTool;
      if (decision is DenyTool && decision.quiet) _quietErrorToolUses.add(prompt.toolUseId);
    }
    _proc.writeLine(
      jsonEncode({
        'type': 'control_response',
        'response': {'subtype': 'success', 'request_id': promptId, 'response': decision.toJson()},
      }),
    );
    if (decision is AllowTool) {
      // Approving ExitPlanMode leaves plan mode. The CLI performs the
      // transition itself on the approval, so we don't send a
      // set_permission_mode control request — we just sync our tracked status
      // (exits to 'default', matching Claude Code) so the permission-mode
      // indicator and composer reflect the change (T-337).
      if (prompt.toolName == 'ExitPlanMode') {
        _mergeStatus(const SessionStatus(permissionMode: 'default'));
      }
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
    _proc.writeLine(
      jsonEncode({
        'type': 'user',
        'message': {'role': 'user', 'content': text},
      }),
    );
    _items.add(UserMessage(uuid: 'local-${_localSeq++}', timestamp: DateTime.now(), isSidechain: false, text: text));
    _setBusy(true);
  }

  /// Inject a clide-local notice card into the conversation — nothing is sent
  /// to claude. Used by the slash-command router for TUI-only commands
  /// (T-411); renders as the muted synthetic "clide" card.
  void addLocalNotice(String text) {
    _items.add(AssistantTextMessage(uuid: 'local-${_localSeq++}', timestamp: DateTime.now(), isSidechain: false, text: text, synthetic: true));
  }

  /// Record the effort level this session was spawned with (`--effort`,
  /// T-412). The wire never reports effort, so the spawner tells the status
  /// what it set; the status line / sidebar read it from [SessionStatus].
  void noteEffort(String level) => _mergeStatus(SessionStatus(effort: level));

  /// Interrupt the running turn (the escape hatch for a runaway — D-78). Sends
  /// the `interrupt` control_request; claude cancels the current turn and ends
  /// it with a `result`, which clears [busy]. Safe to call when idle.
  void interrupt() {
    _proc.writeLine(
      jsonEncode({
        'type': 'control_request',
        'request_id': 'interrupt-${_localSeq++}',
        'request': {'subtype': 'interrupt'},
      }),
    );
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
    _proc.writeLine(
      jsonEncode({
        'type': 'control_request',
        'request_id': 'set-perm-${_localSeq++}',
        'request': {'subtype': 'set_permission_mode', 'mode': mode},
      }),
    );
    // Optimistically reflect the change so the badge / status line update
    // immediately (T-250) — the control_request emits no status event, and a
    // fresh system/init only arrives later. The next init reconciles if the
    // process ends up in a different mode.
    _mergeStatus(SessionStatus(permissionMode: mode));
  }

  /// Set the model for subsequent turns (T-408). Sends a `set_model`
  /// control_request; [model] is an alias (`sonnet`, `opus`) or full id, and
  /// `default` resets to the CLI's configured model. The status merges
  /// optimistically (mirroring [setPermissionMode]); an error response rolls
  /// it back and surfaces on [modelErrors].
  void setModel(String model) {
    final rid = 'set-model-${_localSeq++}';
    _pendingSetModel[rid] = _status.model;
    _proc.writeLine(
      jsonEncode({
        'type': 'control_request',
        'request_id': rid,
        'request': {'subtype': 'set_model', 'model': model},
      }),
    );
    // `default` resolves to a model only the CLI knows — leave the status to
    // the next assistant event in that case.
    if (model != 'default') _mergeStatus(SessionStatus(model: model));
  }

  /// A `control_response` to one of our requests: capture the initialize
  /// result's `models[]`, and roll back + surface a rejected set_model (T-408).
  void _onControlResponse(Map<String, dynamic> ev) {
    final resp = ev['response'];
    if (resp is! Map) return;
    final rid = resp['request_id'] as String?;
    if (rid == null) return;
    final isError = resp['subtype'] == 'error';
    if (rid == _initRequestId && !isError) {
      final result = resp['response'];
      final models = result is Map ? result['models'] : null;
      if (models is List) {
        _availableModels = List.unmodifiable([
          for (final m in models)
            if (m is Map && m['value'] is String)
              ModelOption(
                value: m['value'] as String,
                displayName: m['displayName'] as String? ?? m['value'] as String,
                description: m['description'] as String? ?? '',
              ),
        ]);
      }
      return;
    }
    if (_pendingSetModel.containsKey(rid)) {
      final previous = _pendingSetModel.remove(rid);
      if (isError) {
        if (previous != null) _mergeStatus(SessionStatus(model: previous));
        _modelErrorCtl.add(resp['error'] as String? ?? 'model change rejected');
      }
    }
  }

  /// The process exited under a live session. Flip every "in flight"
  /// surface off so the pane reflects reality instead of spinning forever.
  void _onExit(int code) {
    if (_disposed || _end != null) return;
    _end = SessionEnd(exitCode: code, stderrTail: _proc.stderrTail);
    _setBusy(false);
    // A prompt pending against a dead process can never be answered —
    // clear it so the composer comes back.
    if (_queue.isNotEmpty) {
      _queue.clear();
      _pendingCtl.add(null);
    }
    _endCtl.add(_end!);
  }

  /// Idempotent: the conversation controller's [dispose] fires this
  /// unawaited while a caller (the orchestrator's [ClaudeSessionOrchestrator.close])
  /// awaits it to know the process is truly dead (T-437). Caching the future
  /// makes both paths share one teardown rather than killing/closing twice.
  Future<void> dispose() => _disposeFuture ??= _dispose();
  Future<void>? _disposeFuture;

  Future<void> _dispose() async {
    _disposed = true; // deliberate teardown — suppress the exit-watch path
    await _sub?.cancel();
    await _proc.kill(); // awaits the process's real exit (T-437)
    await _items.close();
    await _statusCtl.close();
    await _workflowsCtl.close();
    await _sessionIdCtl.close();
    await _pendingCtl.close();
    await _busyCtl.close();
    await _endCtl.close();
    await _modelErrorCtl.close();
    await _phaseCtl.close();
    await _outcomeCtl.close();
  }
}
