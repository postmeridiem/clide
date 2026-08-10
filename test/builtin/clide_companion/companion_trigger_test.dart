import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:clide/builtin/clide_companion/src/prompt/companion_trigger.dart';
import 'package:test/test.dart';

/// T-547 — the trigger is the cost control. Every prompt sent draws on the same
/// quota pool already rate-limiting the developer's own session, so what is
/// asserted here is mostly what does NOT get sent.
void main() {
  late DateTime clock;
  late CompanionFrequency freq;
  late CompanionTrigger trigger;

  setUp(() {
    clock = DateTime(2026, 8, 10, 9);
    freq = CompanionFrequency.notable;
    trigger = CompanionTrigger(frequency: () => freq, now: () => clock);
  });

  void advance(Duration d) => clock = clock.add(d);

  /// A substantial completed turn, past every trivial floor and pacing gap.
  bool substantial() => trigger.admit(TriggerReason.turnFinished, ran: const Duration(seconds: 30));

  group('frequency decides what qualifies', () {
    test('rare hears failures and long runs, never an ordinary turn', () {
      freq = CompanionFrequency.rare;
      expect(trigger.admit(TriggerReason.turnFinished, ran: const Duration(minutes: 1)), isFalse);
      advance(const Duration(hours: 1));
      expect(trigger.admit(TriggerReason.turnFailed), isTrue);
    });

    test('notable skips a trivial turn but takes a substantial one', () {
      // Asking about a two-second lookup spends a turn to be told nothing.
      expect(trigger.admit(TriggerReason.turnFinished, ran: const Duration(seconds: 2)), isFalse);
      expect(substantial(), isTrue);
    });

    test('chatty takes even the trivial one', () {
      freq = CompanionFrequency.chatty;
      expect(trigger.admit(TriggerReason.turnFinished, ran: const Duration(seconds: 1)), isTrue);
    });

    test('a failure is worth asking about at every setting', () {
      for (final f in CompanionFrequency.values) {
        freq = f;
        trigger = CompanionTrigger(frequency: () => freq, now: () => clock);
        expect(trigger.admit(TriggerReason.turnFailed), isTrue, reason: '$f dropped a failure');
      }
    });
  });

  group('debounce', () {
    test('two signals for one occurrence produce one prompt', () {
      // "Turn finished" and "commit landed" can arrive within a second of each
      // other, and two remarks about one event reads as a malfunction.
      expect(substantial(), isTrue);
      advance(const Duration(seconds: 1));
      expect(trigger.admit(TriggerReason.turnFailed), isFalse);
    });
  });

  group('pacing', () {
    test('notable will not be asked twice inside a minute', () {
      expect(substantial(), isTrue);
      advance(const Duration(seconds: 45));
      expect(substantial(), isFalse);
      advance(const Duration(seconds: 20));
      expect(substantial(), isTrue);
    });

    test('rare is paced far wider', () {
      freq = CompanionFrequency.rare;
      expect(trigger.admit(TriggerReason.turnFailed), isTrue);
      advance(const Duration(minutes: 5));
      expect(trigger.admit(TriggerReason.turnFailed), isFalse, reason: 'rare means rare, even for failures');
      advance(const Duration(minutes: 6));
      expect(trigger.admit(TriggerReason.turnFailed), isTrue);
    });

    test('a burst of activity cannot become a burst of prompts', () {
      // The backstop the ticket asks for: max_tokens bounds one reply, nothing
      // bounded replies per minute.
      freq = CompanionFrequency.chatty;
      var sent = 0;
      for (var i = 0; i < 60; i++) {
        if (trigger.admit(TriggerReason.turnFinished, ran: const Duration(seconds: 1))) sent++;
        advance(const Duration(seconds: 1));
      }
      expect(sent, lessThanOrEqualTo(7), reason: 'a minute of frantic turns produced $sent prompts');
    });
  });

  group('the long-run threshold', () {
    test('fires once, not once per check', () {
      // A threshold that re-arms is a metronome.
      expect(trigger.admit(TriggerReason.longRun), isTrue);
      for (var i = 0; i < 5; i++) {
        advance(const Duration(minutes: 2));
        expect(trigger.admit(TriggerReason.longRun), isFalse);
      }
    });

    test('re-arms on the next turn', () {
      expect(trigger.admit(TriggerReason.longRun), isTrue);
      advance(const Duration(minutes: 30));
      trigger.turnStarted();
      expect(trigger.admit(TriggerReason.longRun), isTrue);
    });
  });

  group('state changes are not events', () {
    test('the vocabulary has no member for them', () {
      // A session starting, ending, being minimised or coming back are things
      // the tooling did. The signals are all conveniently to hand, which is
      // exactly how an ambient surface becomes a nuisance — so the omission is
      // encoded in the enum rather than left to a comment.
      expect(TriggerReason.values, [TriggerReason.turnFinished, TriggerReason.turnFailed, TriggerReason.longRun]);
    });
  });
}
