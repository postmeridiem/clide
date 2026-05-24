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

/// Parses a [StreamJsonProcess]'s events into conversation items + status,
/// and sends user messages.
class StreamJsonSession {
  StreamJsonSession(this._proc);

  final StreamJsonProcess _proc;
  final _items = StreamController<ConversationItem>.broadcast();
  final _statusCtl = StreamController<SessionStatus>.broadcast();
  StreamSubscription<String>? _sub;
  SessionStatus _status = const SessionStatus();
  int _localSeq = 0;

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
    // Items + assistant model/tokens reuse the transcript parser (identical
    // message.content shapes).
    final parsed = parseTranscriptChunk(trimmed);
    for (final item in parsed.items) {
      _items.add(item);
    }
    // The `init` event carries permission mode (no `permission-mode` record
    // exists in stream-json); fold it in alongside the parsed deltas.
    _mergeStatus(parsed.status.merge(_statusFromEvent(trimmed)));
  }

  SessionStatus _statusFromEvent(String line) {
    Object? j;
    try {
      j = jsonDecode(line);
    } catch (_) {
      return const SessionStatus();
    }
    if (j is! Map) return const SessionStatus();
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
  }
}
