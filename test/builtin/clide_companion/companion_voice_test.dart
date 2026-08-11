import 'dart:async';
import 'dart:convert';

import 'package:clide/builtin/claude/src/session_orchestrator.dart';
import 'package:clide/builtin/claude/src/session_reader.dart';
import 'package:clide/builtin/claude/src/stream_json_session.dart';
import 'package:clide/builtin/clide_companion/src/companion_session.dart';
import 'package:clide/builtin/clide_companion/src/companion_voice.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _Proc extends StreamJsonProcess {
  final _ctl = StreamController<String>.broadcast();
  final _exit = Completer<int>();

  @override
  Stream<String> get lines => _ctl.stream;
  @override
  void writeLine(String line) {}
  @override
  Future<void> kill() async {}
  @override
  Future<int> get exitCode => _exit.future;

  void emit(Map<String, Object?> ev) => _ctl.add(jsonEncode(ev));

  /// Clide replying, in the shipped format: a face line then prose.
  void says(String raw, {String id = 'r1', bool synthetic = false}) => emit({
    'type': 'assistant',
    'message': {
      'id': id,
      'role': 'assistant',
      if (synthetic) 'model': '<synthetic>',
      'content': [
        {'type': 'text', 'text': raw},
      ],
    },
  });

  /// The digest we send him, echoed back on his own item stream.
  void weSaid(String text) => emit({
    'type': 'user',
    'message': {'role': 'user', 'content': text},
  });

  void die() => _exit.complete(1);

  /// The turn boundary, which is the only point his text can be trusted at.
  void endTurn() => emit({'type': 'result', 'is_error': false, 'stop_reason': 'end_turn'});
}

/// T-548 — the seam the strip renders. Two sources feed one face, and which of
/// them wins is the whole design: a declared mood that contradicted a fact would
/// be a lie the user can see.
void main() {
  late _Proc proc;
  late ClaudeSessionOrchestrator orch;
  late CompanionVoice voice;
  var moodEnabled = true;

  Future<void> boot() async {
    moodEnabled = true;
    proc = _Proc();
    orch = ClaudeSessionOrchestrator(processFactory: ({required sessionArgs, required cwd, env}) async => proc);
    await orch.spawn(
      SpawnSpec(
        id: kCompanionSessionId,
        role: 'companion',
        sessionId: 'c1',
        cwd: '/repo',
        visible: false,
        profile: SessionProfile.companion,
        systemPrompt: 'You are Clide.',
      ),
    );
    voice = CompanionVoice(
      reader: SessionReader(sessionId: kCompanionSessionId, orchestrator: orch),
      moodEnabled: () => moodEnabled,
    )..start();
  }

  setUp(boot);
  tearDown(() => voice.dispose());

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  group('only finished replies are rendered', () {
    test('a mid-stream fragment never reaches the bubble', () async {
      // Caught live: parsing each item as it arrived put `[idle` — an unclosed
      // face tag — straight into his mouth, which is exactly the failure the
      // kill condition names.
      for (final chunk in ['[', '[id', '[idle', '[idle]', '[idle]\nnearly there']) {
        proc.says(chunk, id: 'stream-1');
        await settle();
        expect(voice.say, isNull, reason: 'nothing may render until the turn ends; saw "\${voice.say}"');
      }

      proc.endTurn();
      await settle();
      expect(voice.face, FaceState.idle);
      expect(voice.say, 'nearly there');
    });

    test('the face still moves while he is composing', () async {
      // Only the words wait for the boundary — the expression comes from the
      // phase, so he looks like he is thinking while he is thinking.
      proc.emit({
        'type': 'stream_event',
        'event': {
          'type': 'content_block_start',
          'content_block': {'type': 'thinking'},
        },
      });
      await settle();
      expect(voice.face, FaceState.pensive);
    });
  });

  group('what he says', () {
    test('a face line and prose become an expression and a remark', () async {
      proc.says('[unimpressed]\nThe hook was being annoying about something.');
      proc.endTurn();
      await settle();

      expect(voice.face, FaceState.unimpressed);
      expect(voice.say, 'The hook was being annoying about something.');
    });

    test('a face alone changes the expression and says nothing', () async {
      proc.says('[watching]');
      proc.endTurn();
      await settle();

      expect(voice.face, FaceState.watching);
      expect(voice.say, isNull, reason: 'silence is his normal state, not an empty bubble');
    });

    test('the digest we sent him never comes back out of his mouth', () async {
      // His own session echoes what we say to him as user messages. Rendering
      // those would put the developer's own conversation in Clide's mouth.
      proc.weSaid('[observed] user: skip the changelog\n[observed] claude: Committed.');
      proc.endTurn();
      await settle();

      expect(voice.say, isNull);
    });

    test('silence does not wipe a remark that is still on screen', () async {
      proc.says('[concerned]\nThose accumulate.');
      proc.endTurn();
      await settle();
      proc.says('[idle]', id: 'r2');
      proc.endTurn();
      await settle();

      expect(voice.say, 'Those accumulate.', reason: 'he had nothing to add, which is not an instruction to clear');
      expect(voice.face, FaceState.idle, reason: 'but the face still follows what he named');
    });
  });

  group('mechanics beat mood', () {
    test('a dead session shows error however he last felt', () async {
      proc.says('[amused]\nthat is a good one');
      proc.endTurn();
      await settle();
      expect(voice.face, FaceState.amused);

      proc.die();
      await settle();

      expect(voice.face, FaceState.error, reason: 'a cheerful face on a dead session is a lie the user can see');
    });

    test('a request in flight shows pensive, not the last mood', () async {
      proc.says('[approving]\ngood');
      proc.endTurn();
      await settle();

      proc.emit({
        'type': 'stream_event',
        'event': {
          'type': 'content_block_start',
          'content_block': {'type': 'thinking'},
        },
      });
      await settle();

      expect(voice.face, FaceState.pensive);
    });
  });

  group('the kill condition', () {
    test('an unreadable face leaves the previous expression alone', () async {
      proc.says('[tired]\nlong day');
      proc.endTurn();
      await settle();
      expect(voice.face, FaceState.tired);

      proc.says('no face line at all', id: 'r2');
      proc.endTurn();
      await settle();

      expect(voice.face, FaceState.tired, reason: 'a snap to neutral is a glitch; an unchanged face reads as nothing new to feel');
    });

    test('an invented mood is neither rendered nor shown as text', () async {
      proc.says('[ecstatic]\nnice one');
      proc.endTurn();
      await settle();

      expect(voice.face, FaceState.idle, reason: 'the vocabulary is closed');
      expect(voice.say, 'nice one', reason: 'and the tag must not survive into the bubble');
    });

    test('synthetic prose is not him', () async {
      proc.says('[rage]\nnot mine', synthetic: true);
      proc.endTurn();
      await settle();

      expect(voice.say, isNull);
      expect(voice.face, FaceState.idle);
    });
  });

  group('an expression does not outlive its cause', () {
    test('the mood expires with the remark, not never', () async {
      // He could otherwise sit there unimpressed an hour after the thing that
      // annoyed him was fixed — an expression outliving its cause is a lie the
      // user can read, and worse than a neutral one because it looks deliberate.
      final voice = CompanionVoice(
        reader: SessionReader(sessionId: kCompanionSessionId, orchestrator: orch),
        moodEnabled: () => true,
        dwell: const Duration(milliseconds: 40),
      )..start();
      addTearDown(voice.dispose);

      proc.says('[unimpressed]\nThose accumulate.');
      proc.endTurn();
      await settle();
      expect(voice.face, FaceState.unimpressed);
      expect(voice.say, 'Those accumulate.');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(voice.say, isNull);
      expect(voice.face, FaceState.idle, reason: 'the mood should settle with the words it came with');
    });

    test('a silent mood expires too', () async {
      // A face he named without speaking is still a mood with a cause, and the
      // cause still passes.
      final voice = CompanionVoice(
        reader: SessionReader(sessionId: kCompanionSessionId, orchestrator: orch),
        moodEnabled: () => true,
        dwell: const Duration(milliseconds: 40),
      )..start();
      addTearDown(voice.dispose);

      proc.says('[tired]');
      proc.endTurn();
      await settle();
      expect(voice.face, FaceState.tired);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(voice.face, FaceState.idle);
    });
  });

  group('the mood setting', () {
    test('off falls back to his lifecycle and ignores what he named', () async {
      moodEnabled = false;
      proc.says('[rage]\nagain?');
      proc.endTurn();
      await settle();

      expect(voice.face, FaceState.idle, reason: 'off means expression comes from the session, not from him');
      expect(voice.say, 'again?', reason: 'but he is still allowed to speak');
    });

    test('applies live, without anything being respawned', () async {
      proc.says('[unimpressed]\nhm');
      proc.endTurn();
      await settle();
      expect(voice.face, FaceState.unimpressed);

      moodEnabled = false;
      expect(voice.face, FaceState.idle);

      moodEnabled = true;
      expect(voice.face, FaceState.unimpressed, reason: 'the mood is held, not discarded, while the setting is off');
    });
  });
}
