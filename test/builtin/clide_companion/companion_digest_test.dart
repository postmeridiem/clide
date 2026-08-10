import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_digest.dart';
import 'package:test/test.dart';

/// Drives the digest through a REAL session parser rather than hand-built items,
/// so what is asserted is what the wire actually produces — including the
/// `partial-` rewrite, which is the one behaviour a hand-rolled fixture would
/// have got wrong.
class _Proc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();

  @override
  Stream<String> get lines => _ctl.stream;
  @override
  void writeLine(String line) {}
  @override
  Future<void> kill() async {}

  void emit(Map<String, Object?> ev) => _ctl.add(jsonEncode(ev));

  /// Assistant prose, as the CLI sends it.
  void prose(String text, {String id = 'a1', bool synthetic = false}) => emit({
    'type': 'assistant',
    'message': {
      'id': id,
      'role': 'assistant',
      if (synthetic) 'model': '<synthetic>',
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
  });

  /// A tool call — the thing the boundary exists to exclude.
  void toolUse(String name, Map<String, Object?> input, {String id = 't1'}) => emit({
    'type': 'assistant',
    'message': {
      'id': 'm-$id',
      'role': 'assistant',
      'content': [
        {'type': 'tool_use', 'id': id, 'name': name, 'input': input},
      ],
    },
  });

  /// A tool result coming back — where file contents and command output live.
  void toolResult(String content, {String id = 't1'}) => emit({
    'type': 'user',
    'message': {
      'role': 'user',
      'content': [
        {'type': 'tool_result', 'tool_use_id': id, 'content': content},
      ],
    },
  });

  void thinking(String text) => emit({
    'type': 'assistant',
    'message': {
      'id': 'th1',
      'role': 'assistant',
      'content': [
        {'type': 'thinking', 'thinking': text},
      ],
    },
  });

  void endTurn() => emit({'type': 'result', 'is_error': false, 'stop_reason': 'end_turn'});
}

void main() {
  late _Proc proc;
  late ClaudeSessionOrchestrator orch;
  late SessionReader reader;
  late CompanionDigest digest;
  late List<String> sent;
  var ingesting = true;

  Future<void> boot() async {
    ingesting = true;
    sent = [];
    proc = _Proc();
    orch = ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async => proc);
    await orch.spawn(const SpawnSpec(id: kPrimarySessionId, role: 'primary', sessionId: 'p', cwd: '/repo'));
    reader = SessionReader.primary(orchestrator: orch)..start();
    digest = CompanionDigest(source: reader, ingesting: () => ingesting)..start();
    digest.lines.listen(sent.add);
  }

  setUp(boot);
  tearDown(() {
    digest.dispose();
    reader.dispose();
  });

  /// Let the stream chain settle.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  ManagedSession session() => orch.byId(kPrimarySessionId)!;

  group('the allow-list', () {
    test('a prompt and its prose become one exchange', () async {
      session().session.send('add a null check');
      proc.prose('Added, with a test for the empty case.');
      proc.endTurn();
      await settle();

      expect(sent, ['[observed] user: add a null check\n[observed] claude: Added, with a test for the empty case.']);
    });

    test('tool calls, results and thinking never reach him', () async {
      // D-107 commitment 3: this is where file contents, paths, credentials and
      // command output live. The boundary is the feature.
      session().session.send('read the config and fix it');
      proc.thinking('The user wants me to look at ~/.aws/credentials first.');
      proc.toolUse('Read', {'file_path': '/home/jeroen/.aws/credentials'});
      proc.toolResult('aws_secret_access_key = wJalrXUtnFEMI/K7MDENG');
      proc.prose('Fixed it.');
      proc.endTurn();
      await settle();

      expect(sent, hasLength(1));
      expect(sent.single, contains('Fixed it.'));
      expect(sent.single, isNot(contains('credentials')));
      expect(sent.single, isNot(contains('wJalrXUtnFEMI')));
      expect(sent.single, isNot(contains('Read')));
    });

    test('a turn of pure tool work produces no line at all', () async {
      // Absence is silence. Not an empty prompt, not "nothing to report".
      session().session.send('run the formatter');
      proc.toolUse('Bash', {'command': 'dart format .'});
      proc.toolResult('Formatted 884 files');
      proc.endTurn();
      await settle();

      expect(sent, hasLength(1), reason: 'the prompt itself is still content — it is what the developer said');
      expect(sent.single, '[observed] user: run the formatter');
    });

    test('synthetic prose — the CLI or clide talking locally — is dropped', () async {
      // Clide remarking on clide's own notices is the tooling-narration failure
      // the whole surface exists to avoid.
      session().session.send('/usage');
      proc.prose('Your limit resets at 18:00.', synthetic: true);
      proc.endTurn();
      await settle();

      expect(sent.single, isNot(contains('18:00')));
    });
  });

  group('one line per completed exchange', () {
    test('a streamed message and its final rewrite collapse into one', () async {
      // The trap Epic B's audit found: `partial-` means "came through the
      // streaming path", not "still arriving", and the final event is rewritten
      // carrying the same uuid. Emitting per item would send this a dozen times.
      session().session.send('explain it');
      for (final chunk in ['It', 'It only', 'It only fails', 'It only fails on an idle machine.']) {
        proc.prose(chunk, id: 'stream-1');
      }
      proc.endTurn();
      await settle();

      expect(sent, hasLength(1));
      expect(sent.single, endsWith('It only fails on an idle machine.'), reason: 'the last version of the text wins');
    });

    test('nothing is emitted until the turn ends', () async {
      session().session.send('do it');
      proc.prose('Working on it.');
      await settle();
      expect(sent, isEmpty, reason: 'a digest mid-turn asks him to comment on an unfinished thought');

      proc.endTurn();
      await settle();
      expect(sent, hasLength(1));
    });

    test('two turns are two lines, and the second does not repeat the first', () async {
      session().session.send('first');
      proc.prose('one', id: 'a');
      proc.endTurn();
      await settle();

      session().session.send('second');
      proc.prose('two', id: 'b');
      proc.endTurn();
      await settle();

      expect(sent, hasLength(2));
      expect(sent[1], isNot(contains('first')));
      expect(sent[1], isNot(contains('one')));
    });
  });

  group('pausing drops rather than buffers', () {
    test('nothing seen while paused is replayed on resume', () async {
      // T-528's semantics: a minimised stretch is conversation he genuinely did
      // not see. Replaying it would make the pause a lie and bury him in backlog
      // exactly when he became visible again.
      ingesting = false;
      session().session.send('while you were away');
      proc.prose('secret business');
      proc.endTurn();
      await settle();
      expect(sent, isEmpty);

      ingesting = true;
      session().session.send('and now');
      proc.prose('back to it', id: 'b');
      proc.endTurn();
      await settle();

      expect(sent, hasLength(1));
      expect(sent.single, isNot(contains('while you were away')));
      expect(sent.single, contains('and now'));
    });

    test('a pause mid-turn keeps only what was actually watched', () async {
      session().session.send('watched');
      ingesting = false;
      proc.prose('missed this');
      ingesting = true;
      proc.prose('saw this', id: 'b');
      proc.endTurn();
      await settle();

      expect(sent.single, contains('watched'));
      expect(sent.single, contains('saw this'));
      expect(sent.single, isNot(contains('missed this')));
    });
  });

  group('absence is silence', () {
    test('a turn ending with nothing admissible sends no prompt', () async {
      proc.endTurn();
      await settle();
      expect(sent, isEmpty);
    });

    test('repeated empty turns stay silent', () async {
      for (var i = 0; i < 3; i++) {
        proc.endTurn();
      }
      await settle();
      expect(sent, isEmpty, reason: 'a heartbeat is exactly what this rule forbids');
    });
  });
}
