/// Tails Claude Code's transcript JSONL and emits parsed conversation items.
///
/// Data layer only — no UI. Feeds native Claude rendering (epic T-132).
///
/// # Path convention
/// Claude Code stores transcripts at:
///   `~/.claude/projects/<munged-cwd>/<session-id>.jsonl`
/// where `munged-cwd = absolutePath.replaceAll('/', '-')` (leading `-` kept).
/// Subagent transcripts live under:
///   `<munged-cwd>/<session-id>/subagents/agent-<id>.jsonl`
///
/// # Session discovery
/// The caller supplies a workspace path. [TranscriptReader] resolves the
/// munged directory and picks the newest `.jsonl` by mtime. It polls mtime
/// and switches to a newer file if one appears (e.g. the user starts a new
/// Claude Code session).
///
/// # Streaming
/// The stream uses an append-only byte-cursor so it never re-processes bytes
/// it has already seen. Each iteration:
///   1. Reads from the cursor position to EOF.
///   2. Splits on newlines.
///   3. Parses each line as JSON and emits any recognised [ConversationItem].
///
/// # Version drift-guard
/// If the envelope `version` field has an unfamiliar major version the reader
/// warns via [onWarn] (or stderr if omitted) and degrades gracefully — it
/// parses whatever it can and skips the rest rather than crashing.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

/// Discriminated union of conversation items the reader can emit.
sealed class ConversationItem {
  const ConversationItem({required this.uuid, required this.timestamp, required this.isSidechain, this.parentUuid, this.parentToolUseId});

  final String uuid;
  final DateTime timestamp;
  final bool isSidechain;

  /// The uuid of this record's predecessor in its chain (from the transcript
  /// envelope's `parentUuid`), or null when absent/empty. A sidechain prompt
  /// branches off the assistant message that issued its spawning Agent/Task
  /// tool-use, so this links the prompt to the right Agent card (T-263).
  final String? parentUuid;

  /// The `parent_tool_use_id` from the stream-json wire (T-338): the tool-use
  /// id of the Agent/Task call that spawned this sub-agent message. Stream-json
  /// tags every sidechain item with it — the transcript JSONL instead uses
  /// [isSidechain] + [parentUuid]. When present it routes the item straight to
  /// its Agent card by tool-use id, no uuid-chain walk needed, and on its own
  /// marks the item as a sidechain message.
  final String? parentToolUseId;
}

/// A user-typed message (plain text, possibly multi-part).
final class UserMessage extends ConversationItem {
  const UserMessage({
    required super.uuid,
    required super.timestamp,
    required super.isSidechain,
    super.parentUuid,
    super.parentToolUseId,
    required this.text,
    this.injected = false,
  });

  /// The concatenated text of all `text` parts in the content array.
  final String text;

  /// True when this "user" message was injected by the harness (a skill load,
  /// a slash-command expansion, a system reminder) rather than typed by the
  /// user — the view de-emphasises these (D-78).
  final bool injected;

  @override
  String toString() => 'UserMessage(${_shortId(uuid)}, ${text.length} chars${injected ? ', injected' : ''})';
}

/// A tool-result delivered from the host back to Claude as a user message.
final class ToolResultMessage extends ConversationItem {
  const ToolResultMessage({
    required super.uuid,
    required super.timestamp,
    required super.isSidechain,
    super.parentUuid,
    super.parentToolUseId,
    required this.toolUseId,
    required this.content,
    required this.isError,
  });

  final String toolUseId;
  final String content;
  final bool isError;

  @override
  String toString() => 'ToolResultMessage(toolUseId=$toolUseId, isError=$isError)';
}

/// Plain text from an assistant turn.
final class AssistantTextMessage extends ConversationItem {
  const AssistantTextMessage({
    required super.uuid,
    required super.timestamp,
    required super.isSidechain,
    super.parentUuid,
    super.parentToolUseId,
    required this.text,
    this.synthetic = false,
  });

  final String text;

  /// CLI-local output, not the model: the wire marks it `model: "<synthetic>"`
  /// (a forwarded local command's response — /usage output, "/x isn't
  /// available in this environment", …). clide-injected notices use it too.
  /// Rendered as a muted "clide" card, never coral Claude prose (T-411).
  final bool synthetic;

  @override
  String toString() => 'AssistantTextMessage(${_shortId(uuid)}, ${text.length} chars${synthetic ? ', synthetic' : ''})';
}

/// Extended thinking block from an assistant turn.
final class AssistantThinkingMessage extends ConversationItem {
  const AssistantThinkingMessage({
    required super.uuid,
    required super.timestamp,
    required super.isSidechain,
    super.parentUuid,
    super.parentToolUseId,
    required this.thinking,
  });

  final String thinking;

  @override
  String toString() => 'AssistantThinkingMessage(${_shortId(uuid)}, ${thinking.length} chars)';
}

/// A tool-use invocation in an assistant turn.
final class AssistantToolUse extends ConversationItem {
  const AssistantToolUse({
    required super.uuid,
    required super.timestamp,
    required super.isSidechain,
    super.parentUuid,
    super.parentToolUseId,
    required this.toolUseId,
    required this.name,
    required this.input,
  });

  /// Tool invocation id (matches the [ToolResultMessage.toolUseId]).
  final String toolUseId;

  /// Tool name, e.g. `"Bash"` or `"Read"`.
  final String name;

  /// Raw decoded input map.
  final Map<String, dynamic> input;

  @override
  String toString() => 'AssistantToolUse(name=$name, id=$toolUseId)';
}

/// A locally-injected image card (T-249). Not parsed from the transcript —
/// driven into the conversation by `clide image show <path>` (D-6 parity) and
/// rendered display-only per D-78. [path] is an absolute, on-disk file the
/// driver has already resolved (workspace-relative paths are resolved before
/// injection); [caption] is an optional one-line label.
final class ImageMessage extends ConversationItem {
  const ImageMessage({required super.uuid, required super.timestamp, required super.isSidechain, required this.path, this.caption});

  /// Absolute path to the image file on disk.
  final String path;

  /// Optional caption shown under the image.
  final String? caption;

  @override
  String toString() => 'ImageMessage($path${caption != null ? ', "$caption"' : ''})';
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Safe short UUID prefix for use in [toString] methods.
String _shortId(String uuid) => uuid.length >= 8 ? uuid.substring(0, 8) : uuid;

// ---------------------------------------------------------------------------
// Reader
// ---------------------------------------------------------------------------

/// On first attach to a session file, read at most this many recent
/// bytes (not the whole file) — an active transcript can be many MB and
/// parsing it all synchronously would freeze the UI. Appends after that
/// stream incrementally.
const _defaultInitialTailBytes = 256 * 1024;

/// Chunks at least this large are parsed in a background isolate; smaller
/// ones parse inline. Streaming appends are small, so this keeps the
/// off-thread parse to the initial-tail case that actually janks a frame.
const _isolateParseThreshold = 64 * 1024;

/// Known major transcript versions.
const _knownMajorVersions = {1, 2};

/// Record types to skip (do not emit as conversation items).
const _skipTypes = {'attachment', 'system', 'last-prompt', 'permission-mode', 'file-history-snapshot', 'queue-operation'};

/// Tails Claude Code's transcript JSONL and emits [ConversationItem]s.
///
/// Call [stream] to obtain the live stream. Dispose with [dispose] when done.
class TranscriptReader {
  /// Creates a reader for [workspacePath].
  ///
  /// [pollInterval] controls how often the reader polls for new data and
  /// session switches (default 500 ms).
  ///
  /// [onWarn] receives warning messages from the version drift-guard.
  /// If omitted, warnings are written to stderr.
  TranscriptReader(
    this.workspacePath, {
    Duration pollInterval = const Duration(milliseconds: 500),
    void Function(String)? onWarn,
    String? projectsBase,
    int? initialTailBytes,
    String? file,
  }) : _pollInterval = pollInterval,
       _onWarn = onWarn ?? _defaultWarn,
       _projectsBase = projectsBase ?? _defaultProjectsBase(),
       _initialTailBytes = initialTailBytes ?? _defaultInitialTailBytes,
       _explicitFile = file;

  final String workspacePath;
  final Duration _pollInterval;
  final void Function(String) _onWarn;

  /// Max bytes of recent history to read when first attaching to a
  /// session file (overridable for tests).
  final int _initialTailBytes;

  /// Base dir holding the per-workspace transcript dirs. Defaults to
  /// `~/.claude/projects`; overridable so tests point the real reader at a
  /// temp directory instead of the user's home.
  final String _projectsBase;

  /// When set, tail this exact file instead of discovering the newest
  /// `.jsonl` in the munged dir. Used for teammate subagent transcripts
  /// (T-139), whose path the team observer resolves explicitly.
  final String? _explicitFile;

  static String _defaultProjectsBase() {
    final home = Platform.environment['HOME'] ?? '';
    return home.isNotEmpty ? '$home/.claude/projects' : '.claude/projects';
  }

  StreamController<ConversationItem>? _controller;
  final StreamController<SessionStatus> _statusController = StreamController<SessionStatus>.broadcast();
  SessionStatus _status = const SessionStatus();
  Timer? _timer;
  String? _currentPath;
  int _cursor = 0;

  static void _defaultWarn(String msg) => stderr.writeln('[TranscriptReader] $msg');

  // ---------------------------------------------------------------------------
  // Path resolution
  // ---------------------------------------------------------------------------

  /// Resolves `<projectsBase>/<munged-cwd>`.
  String _mungedDir() {
    final munged = workspacePath.replaceAll('/', '-');
    return '$_projectsBase/$munged';
  }

  /// Finds the newest `.jsonl` by mtime inside [dir], or null if none exist.
  static Future<String?> _newestJsonl(String dir) async {
    final d = Directory(dir);
    if (!await d.exists()) return null;

    FileStat? bestStat;
    String? bestPath;

    await for (final entity in d.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.jsonl')) continue;
      final stat = await entity.stat();
      if (bestStat == null || stat.modified.isAfter(bestStat.modified)) {
        bestStat = stat;
        bestPath = entity.path;
      }
    }
    return bestPath;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// A broadcast stream of [ConversationItem]s from the active transcript.
  ///
  /// The stream is created lazily on first call. Subsequent calls return the
  /// same stream. Call [dispose] to cancel polling and close the stream.
  Stream<ConversationItem> get stream {
    _controller ??= _start();
    return _controller!.stream;
  }

  /// Live [SessionStatus] updates (model / permission-mode / context
  /// tokens), emitted only when a value changes (T-145). Starts polling
  /// too, so a status-only consumer still drives the tail.
  Stream<SessionStatus> get statusStream {
    _controller ??= _start();
    return _statusController.stream;
  }

  /// Cancels polling and closes the underlying stream.
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    unawaited(_statusController.close());
    await _controller?.close();
    _controller = null;
  }

  // ---------------------------------------------------------------------------
  // Internal — polling
  // ---------------------------------------------------------------------------

  StreamController<ConversationItem> _start() {
    final controller = StreamController<ConversationItem>.broadcast();
    _scheduleNext(controller);
    return controller;
  }

  void _scheduleNext(StreamController<ConversationItem> controller) {
    _timer = Timer(_pollInterval, () async {
      if (controller.isClosed) return;
      await _tick(controller);
      if (!controller.isClosed) _scheduleNext(controller);
    });
  }

  Future<void> _tick(StreamController<ConversationItem> controller) async {
    // A pane/teammate reader tails one fixed file; otherwise discover the
    // newest session `.jsonl` in the munged dir.
    final newest = _explicitFile ?? await _newestJsonl(_mungedDir());
    if (newest == null) return;
    // An explicit file may not exist yet (claude writes it shortly after
    // spawn) — wait for it rather than throwing in the poll loop.
    if (!await File(newest).exists()) return;

    if (newest != _currentPath) {
      // New session file. Start from the recent tail rather than byte 0:
      // an active transcript can be many MB (thousands of records), and
      // parsing the whole thing synchronously on first attach freezes the
      // UI. Read at most [_initialTailBytes] of recent history, then stream
      // appends. A partial first line (from landing mid-record) simply
      // fails to JSON-parse and is skipped. Older scrollback is a future
      // load-more concern.
      _currentPath = newest;
      final length = await File(newest).length();
      _cursor = length > _initialTailBytes ? length - _initialTailBytes : 0;
    }

    await _tail(controller, newest);
  }

  Future<void> _tail(StreamController<ConversationItem> controller, String path) async {
    final file = File(path);
    final length = await file.length();
    if (length <= _cursor) return; // no new bytes

    final String chunk;
    final raf = await file.open();
    try {
      await raf.setPosition(_cursor);
      final newBytes = await raf.read(length - _cursor);
      _cursor = length;
      chunk = utf8.decode(newBytes, allowMalformed: true);
    } finally {
      await raf.close();
    }
    if (controller.isClosed) return;

    // Parse off the UI isolate only when the chunk is big enough to jank a
    // frame — the initial tail read (up to [_initialTailBytes]) is the case
    // that froze the app. Streaming appends are small (a message at a time);
    // parsing those inline avoids spawning a one-shot isolate every poll
    // tick, which is pure overhead and adds latency under load.
    final parsed = chunk.length >= _isolateParseThreshold ? await Isolate.run(() => parseTranscriptChunk(chunk)) : parseTranscriptChunk(chunk);
    if (controller.isClosed) return;
    for (final w in parsed.warnings) {
      _onWarn(w);
    }
    for (final item in parsed.items) {
      if (controller.isClosed) break;
      controller.add(item);
    }

    // Fold this chunk's status deltas into the running status; emit only
    // on change so listeners (the status strip) don't churn.
    final merged = _status.merge(parsed.status);
    if (merged != _status) {
      _status = merged;
      if (!_statusController.isClosed) _statusController.add(_status);
    }
  }

  /// Parse a single JSONL line into its items (forwarding any version
  /// warnings to [onWarn]). Public so tests exercise the real parser.
  List<ConversationItem> parseLine(String line) {
    final parsed = parseTranscriptChunk(line);
    for (final w in parsed.warnings) {
      _onWarn(w);
    }
    return parsed.items;
  }
}

/// Live per-session status surfaced for the status strip / sidebar
/// (T-145, T-168). All fields nullable — a chunk only carries what it saw,
/// and the reader [merge]s deltas into a running status.
class SessionStatus {
  const SessionStatus({this.model, this.permissionMode, this.contextTokens, this.cost, this.contextWindow, this.rateLimitInfo, this.effort});

  /// Assistant `message.model`, e.g. `claude-opus-4-7`.
  final String? model;

  /// Latest `permissionMode` (default / acceptEdits / plan / bypassPermissions).
  final String? permissionMode;

  /// Input context-window tokens in the most recent assistant turn
  /// (input + cache-read + cache-creation). A count, not a percentage —
  /// the transcript doesn't carry the model's context limit.
  final int? contextTokens;

  /// Cumulative cost in USD from the `result` event's `total_cost_usd`
  /// field (T-168). Null until the first result event arrives.
  final double? cost;

  /// The model's context-window size in tokens from the `result` event's
  /// `modelUsage.<model>.contextWindow` (T-168). Null until first result.
  final int? contextWindow;

  /// Latest rate-limit info string from `rate_limit_event`, e.g.
  /// `"rate limited — resets 14:32"` (T-168). Null when not rate-limited.
  final String? rateLimitInfo;

  /// The session's effort level (`--effort`, T-412). The wire never reports
  /// it — clide records what it spawned with via [StreamJsonSession.noteEffort];
  /// null means the CLI default (settings.json `effortLevel`).
  final String? effort;

  bool get isEmpty =>
      model == null && permissionMode == null && contextTokens == null && cost == null && contextWindow == null && rateLimitInfo == null && effort == null;

  /// Overlay [other]'s non-null fields onto this one.
  SessionStatus merge(SessionStatus other) => SessionStatus(
    model: other.model ?? model,
    permissionMode: other.permissionMode ?? permissionMode,
    contextTokens: other.contextTokens ?? contextTokens,
    cost: other.cost ?? cost,
    contextWindow: other.contextWindow ?? contextWindow,
    rateLimitInfo: other.rateLimitInfo ?? rateLimitInfo,
    effort: other.effort ?? effort,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionStatus &&
      other.model == model &&
      other.permissionMode == permissionMode &&
      other.contextTokens == contextTokens &&
      other.cost == cost &&
      other.contextWindow == contextWindow &&
      other.rateLimitInfo == rateLimitInfo &&
      other.effort == effort;

  @override
  int get hashCode => Object.hash(model, permissionMode, contextTokens, cost, contextWindow, rateLimitInfo, effort);
}

/// Result of [parseTranscriptChunk]: items, version-drift warnings, and
/// the latest [SessionStatus] deltas seen in the chunk.
typedef ParsedChunk = ({List<ConversationItem> items, List<String> warnings, SessionStatus status});

class _StatusAcc {
  String? model;
  String? permissionMode;
  int? contextTokens;
  double? cost;
  int? contextWindow;
  String? rateLimitInfo;
  SessionStatus toStatus() => SessionStatus(
    model: model,
    permissionMode: permissionMode,
    contextTokens: contextTokens,
    cost: cost,
    contextWindow: contextWindow,
    rateLimitInfo: rateLimitInfo,
  );
}

// ---------------------------------------------------------------------------
// Parsing — pure + isolate-safe. Top-level (no instance state) so it can run
// via Isolate.run. Malformed JSON and skip/unknown types are dropped; an
// unfamiliar major `version` adds a warning but parsing still proceeds.
// ---------------------------------------------------------------------------

ParsedChunk parseTranscriptChunk(String chunk) {
  final items = <ConversationItem>[];
  final warnings = <String>[];
  final status = _StatusAcc();
  for (final raw in chunk.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    _parseLineInto(line, items, warnings, status);
  }
  return (items: items, warnings: warnings, status: status.toStatus());
}

void _parseLineInto(String line, List<ConversationItem> out, List<String> warnings, _StatusAcc status) {
  Map<String, dynamic> envelope;
  try {
    envelope = (jsonDecode(line) as Map).cast<String, dynamic>();
  } catch (_) {
    return; // malformed JSON — skip silently
  }

  final rawVersion = envelope['version'] as String?;
  if (rawVersion != null) {
    final dotIdx = rawVersion.indexOf('.');
    final majorStr = dotIdx > 0 ? rawVersion.substring(0, dotIdx) : rawVersion;
    final major = int.tryParse(majorStr);
    if (major != null && !_knownMajorVersions.contains(major)) {
      warnings.add(
        'unfamiliar transcript version "$rawVersion" (major=$major); '
        'parsing will degrade gracefully',
      );
    }
  }

  final type = envelope['type'] as String?;
  if (type == null) return;

  // Status extraction runs for skip-types too (permission-mode is skipped
  // as an item but carries the current mode).
  if (type == 'permission-mode') {
    final pm = envelope['permissionMode'] as String?;
    if (pm != null && pm.isNotEmpty) status.permissionMode = pm;
  }

  if (_skipTypes.contains(type)) return;

  final uuid = envelope['uuid'] as String? ?? '';
  final rawParent = envelope['parentUuid'] as String?;
  final parentUuid = (rawParent != null && rawParent.isNotEmpty) ? rawParent : null;
  // Stream-json tags sub-agent messages with `parent_tool_use_id` (the spawning
  // Agent/Task tool-use), not the transcript's isSidechain/parentUuid (T-338).
  // Treat its presence as a sidechain marker so the fold + de-emphasis kick in.
  final rawParentTool = envelope['parent_tool_use_id'] as String?;
  final parentToolUseId = (rawParentTool != null && rawParentTool.isNotEmpty) ? rawParentTool : null;
  final isSidechain = (envelope['isSidechain'] as bool? ?? false) || parentToolUseId != null;

  DateTime timestamp;
  try {
    timestamp = DateTime.parse(envelope['timestamp'] as String? ?? '');
  } catch (_) {
    timestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  switch (type) {
    case 'user':
      _parseUserInto(envelope, uuid, timestamp, isSidechain, parentUuid, parentToolUseId, out);
    case 'assistant':
      _parseAssistantInto(envelope, uuid, timestamp, isSidechain, parentUuid, parentToolUseId, out);
      _extractAssistantStatus(envelope, status);
    default:
      break; // unknown type — degrade gracefully
  }
}

/// Capture model + context tokens from an assistant turn's message.
void _extractAssistantStatus(Map<String, dynamic> envelope, _StatusAcc status) {
  final message = envelope['message'] as Map?;
  if (message == null) return;
  final model = message['model'] as String?;
  // "<synthetic>" marks CLI-local output (a forwarded local command's
  // response) — not a model switch; it must not clobber the tracked model.
  if (model != null && model.isNotEmpty && model != kSyntheticModel) status.model = model;
  final usage = message['usage'] as Map?;
  if (usage != null) {
    int n(String k) => (usage[k] as num?)?.toInt() ?? 0;
    status.contextTokens = n('input_tokens') + n('cache_read_input_tokens') + n('cache_creation_input_tokens');
  }
}

void _parseUserInto(
  Map<String, dynamic> envelope,
  String uuid,
  DateTime timestamp,
  bool isSidechain,
  String? parentUuid,
  String? parentToolUseId,
  List<ConversationItem> out,
) {
  final message = envelope['message'] as Map?;
  if (message == null) return;
  final content = message['content'];

  // Harness-injected user messages (skill loads, slash-command expansions,
  // system reminders) — `isSynthetic` on the stream-json wire, `isMeta` in the
  // transcript. The view de-emphasises these (D-78).
  final injected = envelope['isSynthetic'] == true || envelope['isMeta'] == true;

  if (content is String) {
    if (content.isNotEmpty) {
      out.add(
        UserMessage(
          uuid: uuid,
          timestamp: timestamp,
          isSidechain: isSidechain,
          parentUuid: parentUuid,
          parentToolUseId: parentToolUseId,
          text: content,
          injected: injected,
        ),
      );
    }
    return;
  }
  if (content is! List) return;

  final textParts = <String>[];
  for (final item in content) {
    if (item is! Map) continue;
    switch (item['type'] as String?) {
      case 'text':
        final text = item['text'] as String? ?? '';
        if (text.isNotEmpty) textParts.add(text);
      case 'tool_result':
        final rawContent = item['content'];
        out.add(
          ToolResultMessage(
            uuid: uuid,
            timestamp: timestamp,
            isSidechain: isSidechain,
            parentUuid: parentUuid,
            parentToolUseId: parentToolUseId,
            toolUseId: item['tool_use_id'] as String? ?? '',
            content: rawContent is String ? rawContent : jsonEncode(rawContent),
            isError: item['is_error'] as bool? ?? false,
          ),
        );
      default:
        break;
    }
  }
  if (textParts.isNotEmpty) {
    out.add(UserMessage(uuid: uuid, timestamp: timestamp, isSidechain: isSidechain, parentUuid: parentUuid, text: textParts.join('\n'), injected: injected));
  }
}

/// The model marker on CLI-local output (forwarded local-command responses).
const String kSyntheticModel = '<synthetic>';

void _parseAssistantInto(
  Map<String, dynamic> envelope,
  String uuid,
  DateTime timestamp,
  bool isSidechain,
  String? parentUuid,
  String? parentToolUseId,
  List<ConversationItem> out,
) {
  final message = envelope['message'] as Map?;
  if (message == null) return;
  final content = message['content'];
  if (content is! List) return;
  final synthetic = (message['model'] as String?) == kSyntheticModel;

  for (final item in content) {
    if (item is! Map) continue;
    switch (item['type'] as String?) {
      case 'text':
        final text = item['text'] as String? ?? '';
        if (text.isNotEmpty) {
          out.add(
            AssistantTextMessage(
              uuid: uuid,
              timestamp: timestamp,
              isSidechain: isSidechain,
              parentUuid: parentUuid,
              parentToolUseId: parentToolUseId,
              text: text,
              synthetic: synthetic,
            ),
          );
        }
      case 'thinking':
        final thinking = item['thinking'] as String? ?? '';
        if (thinking.isNotEmpty) {
          out.add(
            AssistantThinkingMessage(
              uuid: uuid,
              timestamp: timestamp,
              isSidechain: isSidechain,
              parentUuid: parentUuid,
              parentToolUseId: parentToolUseId,
              thinking: thinking,
            ),
          );
        }
      case 'tool_use':
        final rawInput = item['input'];
        out.add(
          AssistantToolUse(
            uuid: uuid,
            timestamp: timestamp,
            isSidechain: isSidechain,
            parentUuid: parentUuid,
            parentToolUseId: parentToolUseId,
            toolUseId: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            input: rawInput is Map ? rawInput.cast<String, dynamic>() : <String, dynamic>{},
          ),
        );
      default:
        break;
    }
  }
}
