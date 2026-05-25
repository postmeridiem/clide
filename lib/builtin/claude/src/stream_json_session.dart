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
final class AllowTool extends ToolDecision {
  const AllowTool(this.updatedInput);
  final Map<String, dynamic> updatedInput;
  @override
  Map<String, dynamic> toJson() => {'behavior': 'allow', 'updatedInput': updatedInput};
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
  StreamJsonSession(this._proc);

  final StreamJsonProcess _proc;
  final _items = StreamController<ConversationItem>.broadcast();
  final _statusCtl = StreamController<SessionStatus>.broadcast();
  StreamSubscription<String>? _sub;
  SessionStatus _status = const SessionStatus();
  int _localSeq = 0;

  /// Prompts awaiting a [resolvePrompt] decision, in arrival order. The head
  /// is the one currently shown in the composer zone.
  final _queue = <ToolPrompt>[];
  final _pendingCtl = StreamController<ToolPrompt?>.broadcast();

  /// The prompt currently awaiting a decision (queue head), or null.
  ToolPrompt? get pendingPrompt => _queue.isEmpty ? null : _queue.first;

  /// Emits the current pending prompt (or null) whenever it changes — the
  /// composer zone swaps between the prompt UI and the text input on this.
  Stream<ToolPrompt?> get pendingPromptStream => _pendingCtl.stream;

  /// Conversation items, in arrival order (assistant turns + the local echo
  /// of the user's own messages).
  Stream<ConversationItem> get items => _items.stream;

  /// Session status (model / permission-mode / context tokens), on change.
  Stream<SessionStatus> get statusStream => _statusCtl.stream;

  /// Begin consuming the process's event stream.
  void start() {
    _sub = _proc.lines.listen(_onLine, onError: (Object _) {});
  }

  void _onLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return;
    final Map<String, dynamic> ev;
    try {
      ev = (jsonDecode(trimmed) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    // Control-channel requests (permission asks, AskUserQuestion) must be
    // routed out of the normal event stream and answered (D-78).
    if (ev['type'] == 'control_request') {
      _onControlRequest(ev);
      return;
    }
    // Items + assistant model/tokens reuse the transcript parser (identical
    // message.content shapes).
    final parsed = parseTranscriptChunk(trimmed);
    for (final item in parsed.items) {
      _items.add(item);
    }
    // The `init` event carries permission mode (no `permission-mode` record
    // exists in stream-json); fold it in alongside the parsed deltas.
    _mergeStatus(parsed.status.merge(_statusFromEvent(ev)));
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
      _queue.add(ToolPrompt(
        promptId: rid,
        toolName: toolName,
        displayName: request['display_name'] as String? ?? toolName,
        description: request['description'] as String?,
        toolUseId: request['tool_use_id'] as String? ?? '',
        input: input,
      ));
      _pendingCtl.add(pendingPrompt);
      return; // awaits resolvePrompt
    }
    _proc.writeLine(jsonEncode({
      'type': 'control_response',
      'response': {'subtype': 'error', 'request_id': rid, 'error': 'Unsupported control request subtype: ${request['subtype']}'},
    }));
  }

  /// Answer a [ToolPrompt] over the control channel, by its
  /// [ToolPrompt.promptId]. No-op if unknown or already resolved. Advances the
  /// queue so the next pending prompt (if any) surfaces.
  void resolvePrompt(String promptId, ToolDecision decision) {
    final before = _queue.length;
    _queue.removeWhere((p) => p.promptId == promptId);
    if (_queue.length == before) return; // unknown / already resolved
    _proc.writeLine(jsonEncode({
      'type': 'control_response',
      'response': {'subtype': 'success', 'request_id': promptId, 'response': decision.toJson()},
    }));
    _pendingCtl.add(pendingPrompt);
  }

  SessionStatus _statusFromEvent(Map<String, dynamic> j) {
    if (j['type'] == 'system' && j['subtype'] == 'init') {
      return SessionStatus(model: j['model'] as String?, permissionMode: j['permissionMode'] as String?);
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
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _proc.kill();
    await _items.close();
    await _statusCtl.close();
    await _pendingCtl.close();
  }
}
