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
  const ConversationItem({required this.uuid, required this.timestamp, required this.isSidechain});

  final String uuid;
  final DateTime timestamp;
  final bool isSidechain;
}

/// A user-typed message (plain text, possibly multi-part).
final class UserMessage extends ConversationItem {
  const UserMessage({
    required super.uuid,
    required super.timestamp,
    required super.isSidechain,
    required this.text,
  });

  /// The concatenated text of all `text` parts in the content array.
  final String text;

  @override
  String toString() => 'UserMessage(${_shortId(uuid)}, ${text.length} chars)';
}

/// A tool-result delivered from the host back to Claude as a user message.
final class ToolResultMessage extends ConversationItem {
  const ToolResultMessage({
    required super.uuid,
    required super.timestamp,
    required super.isSidechain,
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
    required this.text,
  });

  final String text;

  @override
  String toString() => 'AssistantTextMessage(${_shortId(uuid)}, ${text.length} chars)';
}

/// Extended thinking block from an assistant turn.
final class AssistantThinkingMessage extends ConversationItem {
  const AssistantThinkingMessage({
    required super.uuid,
    required super.timestamp,
    required super.isSidechain,
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
const _skipTypes = {
  'attachment',
  'system',
  'last-prompt',
  'permission-mode',
  'file-history-snapshot',
  'queue-operation',
};

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
  })  : _pollInterval = pollInterval,
        _onWarn = onWarn ?? _defaultWarn,
        _projectsBase = projectsBase ?? _defaultProjectsBase(),
        _initialTailBytes = initialTailBytes ?? _defaultInitialTailBytes;

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

  static String _defaultProjectsBase() {
    final home = Platform.environment['HOME'] ?? '';
    return home.isNotEmpty ? '$home/.claude/projects' : '.claude/projects';
  }

  StreamController<ConversationItem>? _controller;
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

  /// Cancels polling and closes the underlying stream.
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
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
    final dir = _mungedDir();

    // Discover or refresh the active session file.
    final newest = await _newestJsonl(dir);
    if (newest == null) return;

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

/// Result of [parseTranscriptChunk]: parsed items + version-drift warnings.
typedef ParsedChunk = ({List<ConversationItem> items, List<String> warnings});

// ---------------------------------------------------------------------------
// Parsing — pure + isolate-safe. Top-level (no instance state) so it can run
// via Isolate.run. Malformed JSON and skip/unknown types are dropped; an
// unfamiliar major `version` adds a warning but parsing still proceeds.
// ---------------------------------------------------------------------------

ParsedChunk parseTranscriptChunk(String chunk) {
  final items = <ConversationItem>[];
  final warnings = <String>[];
  for (final raw in chunk.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    _parseLineInto(line, items, warnings);
  }
  return (items: items, warnings: warnings);
}

void _parseLineInto(String line, List<ConversationItem> out, List<String> warnings) {
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
      warnings.add('unfamiliar transcript version "$rawVersion" (major=$major); '
          'parsing will degrade gracefully');
    }
  }

  final type = envelope['type'] as String?;
  if (type == null || _skipTypes.contains(type)) return;

  final uuid = envelope['uuid'] as String? ?? '';
  final isSidechain = envelope['isSidechain'] as bool? ?? false;

  DateTime timestamp;
  try {
    timestamp = DateTime.parse(envelope['timestamp'] as String? ?? '');
  } catch (_) {
    timestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  switch (type) {
    case 'user':
      _parseUserInto(envelope, uuid, timestamp, isSidechain, out);
    case 'assistant':
      _parseAssistantInto(envelope, uuid, timestamp, isSidechain, out);
    default:
      break; // unknown type — degrade gracefully
  }
}

void _parseUserInto(
  Map<String, dynamic> envelope,
  String uuid,
  DateTime timestamp,
  bool isSidechain,
  List<ConversationItem> out,
) {
  final message = envelope['message'] as Map?;
  if (message == null) return;
  final content = message['content'];

  if (content is String) {
    if (content.isNotEmpty) {
      out.add(UserMessage(uuid: uuid, timestamp: timestamp, isSidechain: isSidechain, text: content));
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
        out.add(ToolResultMessage(
          uuid: uuid,
          timestamp: timestamp,
          isSidechain: isSidechain,
          toolUseId: item['tool_use_id'] as String? ?? '',
          content: rawContent is String ? rawContent : jsonEncode(rawContent),
          isError: item['is_error'] as bool? ?? false,
        ));
      default:
        break;
    }
  }
  if (textParts.isNotEmpty) {
    out.add(UserMessage(uuid: uuid, timestamp: timestamp, isSidechain: isSidechain, text: textParts.join('\n')));
  }
}

void _parseAssistantInto(
  Map<String, dynamic> envelope,
  String uuid,
  DateTime timestamp,
  bool isSidechain,
  List<ConversationItem> out,
) {
  final message = envelope['message'] as Map?;
  if (message == null) return;
  final content = message['content'];
  if (content is! List) return;

  for (final item in content) {
    if (item is! Map) continue;
    switch (item['type'] as String?) {
      case 'text':
        final text = item['text'] as String? ?? '';
        if (text.isNotEmpty) {
          out.add(AssistantTextMessage(uuid: uuid, timestamp: timestamp, isSidechain: isSidechain, text: text));
        }
      case 'thinking':
        final thinking = item['thinking'] as String? ?? '';
        if (thinking.isNotEmpty) {
          out.add(AssistantThinkingMessage(uuid: uuid, timestamp: timestamp, isSidechain: isSidechain, thinking: thinking));
        }
      case 'tool_use':
        final rawInput = item['input'];
        out.add(AssistantToolUse(
          uuid: uuid,
          timestamp: timestamp,
          isSidechain: isSidechain,
          toolUseId: item['id'] as String? ?? '',
          name: item['name'] as String? ?? '',
          input: rawInput is Map ? rawInput.cast<String, dynamic>() : <String, dynamic>{},
        ));
      default:
        break;
    }
  }
}
