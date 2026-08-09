import 'package:clide/builtin/clide_companion/src/companion_settings.dart';
import 'package:test/test.dart';

/// A settings view over a plain map — the shape the kill switch has to be
/// readable in from the session layer, where there is no widget tree.
ClideCompanionSettings _from(Map<String, Object?> values) => ClideCompanionSettings((k) => values[k]);

void main() {
  group('the kill switch', () {
    test('disabling forbids a companion session', () {
      // The assertion the whole ticket exists for (D-107 commitment 1). Written
      // against the gate rather than against any session machinery, so it holds
      // before Epic D exists and becomes load-bearing the moment T-519 calls it.
      final off = _from({kCompanionEnabledKey: false});
      expect(off.mayRunSession, isFalse, reason: 'a disabled companion must not be allowed to spawn a session');
    });

    test('disabling also removes the strip, rather than muting it', () {
      // "Off is off for the repo": a hidden face that still spawns a process is
      // precisely the failure the switch exists to prevent, and a visible face
      // with no session would keep charging 112px of height for nothing.
      final off = _from({kCompanionEnabledKey: false});
      expect(off.stripVisible, isFalse);
      expect(off.mayRunSession, isFalse);
    });

    test('enabling permits it', () {
      final on = _from({kCompanionEnabledKey: true});
      expect(on.mayRunSession, isTrue);
      expect(on.stripVisible, isTrue);
    });

    test('minimising does not permit a session to be torn down silently', () {
      // Minimised is a *display* state; the session question is the enabled key
      // alone. T-528 additionally pauses ingest while minimised, but that is a
      // lifecycle decision, not a permission one — keep the two separable.
      final minimised = _from({kCompanionEnabledKey: true, kCompanionOpenKey: false});
      expect(minimised.mayRunSession, isTrue);
      expect(minimised.stripVisible, isTrue, reason: 'enabled decides existence; open decides display');
    });
  });

  group('defaults', () {
    test('unset reads as enabled and open', () {
      // The user's call: on initially, with per-repo scope carrying the safety
      // argument instead of an off default.
      final unset = _from(const {});
      expect(unset.enabled, isTrue);
      expect(unset.open, isTrue);
      expect(unset.frequency, CompanionFrequency.notable);
      expect(unset.suspendWhenMinimised, isTrue);
    });

    test('the constants and the empty read agree', () {
      // Guards the drift where a default is changed in one place: the schema's
      // defaultValue, the constant, and what an unset key reads as must be one
      // answer, or reset-to-default lands somewhere the code does not expect.
      expect(ClideCompanionSettings.defaults.enabled, kCompanionEnabledDefault);
      expect(ClideCompanionSettings.defaults.open, kCompanionOpenDefault);
      expect(ClideCompanionSettings.defaults.suspendWhenMinimised, kCompanionSuspendWhenMinimisedDefault);
    });

    test('a non-bool stored value falls back rather than throwing', () {
      // Settings files are user-editable JSON.
      final junk = _from({kCompanionEnabledKey: 'yes please'});
      expect(junk.enabled, kCompanionEnabledDefault);
    });
  });

  group('scope', () {
    test('the switch and the display state are per repository', () {
      // Per-repo is a decision, not an accident: a repo may be under terms
      // where a second stream out is not allowed while the next one over is
      // fine, and a machine-wide switch would impose the strictest answer on
      // all of them. The prefix is what the store keys scope off.
      expect(kCompanionEnabledKey, startsWith('project.'));
      expect(kCompanionOpenKey, startsWith('project.'));
      expect(kCompanionFrequencyKey, startsWith('project.'));
    });

    test('suspend-while-minimised is per machine', () {
      // Power behaviour belongs to the box, not to the work.
      expect(kCompanionSuspendWhenMinimisedKey, startsWith('app.'));
    });
  });

  group('frequency', () {
    test('parses its own names and falls back to notable', () {
      for (final f in CompanionFrequency.values) {
        expect(CompanionFrequency.parse(f.name), f);
      }
      expect(CompanionFrequency.parse('enthusiastic'), CompanionFrequency.notable);
      expect(CompanionFrequency.parse(null), CompanionFrequency.notable);
      expect(CompanionFrequency.parse(7), CompanionFrequency.notable);
    });

    test('is ordered least to most talkative', () {
      // The select renders in declaration order; a reordering that put "chatty"
      // in the middle would read as a bug in the picker.
      expect(CompanionFrequency.values, [CompanionFrequency.rare, CompanionFrequency.notable, CompanionFrequency.chatty]);
    });
  });
}
