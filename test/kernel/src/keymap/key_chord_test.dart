/// Unit tests for KeyChord parsing, equality, canonicalisation, and
/// fromKeyEvent.
library;

import 'package:clide/kernel/src/keymap/key_chord.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyChord.parse', () {
    test('single key without modifiers', () {
      final c = KeyChord.parse('enter');
      expect(c.modifiers, isEmpty);
      expect(c.key, LogicalKeyboardKey.enter);
      expect(c.canonical, 'enter');
    });

    test('modifier order is canonicalised', () {
      final a = KeyChord.parse('shift+ctrl+p');
      final b = KeyChord.parse('ctrl+shift+p');
      expect(a, b);
      expect(a.canonical, 'ctrl+shift+p');
    });

    test('cmd/meta/command/super/win all alias the meta modifier', () {
      for (final spec in ['cmd+a', 'meta+a', 'command+a', 'super+a', 'win+a']) {
        expect(KeyChord.parse(spec).modifiers, [KeyModifier.meta], reason: spec);
      }
    });

    test('punctuation keys are recognised by name or character', () {
      expect(KeyChord.parse('ctrl+slash').key, LogicalKeyboardKey.slash);
      expect(KeyChord.parse('ctrl+/').key, LogicalKeyboardKey.slash);
      expect(KeyChord.parse('ctrl+equal').key, LogicalKeyboardKey.equal);
      expect(KeyChord.parse('ctrl+=').key, LogicalKeyboardKey.equal);
    });

    test('parse is case-insensitive on modifiers + key name', () {
      final c = KeyChord.parse('CTRL+SHIFT+P');
      expect(c.modifiers, [KeyModifier.ctrl, KeyModifier.shift]);
      expect(c.key, LogicalKeyboardKey.keyP);
    });
  });

  group('KeyChord.parse — errors', () {
    test('empty string throws', () {
      expect(() => KeyChord.parse(''), throwsFormatException);
    });

    test('unknown modifier throws', () {
      expect(() => KeyChord.parse('hyper+a'), throwsFormatException);
    });

    test('unknown key throws', () {
      expect(() => KeyChord.parse('ctrl+definitely-not-a-key'), throwsFormatException);
    });

    test('trailing + (missing key) throws', () {
      expect(() => KeyChord.parse('ctrl+'), throwsFormatException);
    });
  });

  group('KeyChord display + canonical', () {
    test('display capitalises modifiers + key, joined with +', () {
      expect(KeyChord.parse('ctrl+shift+p').display, 'Ctrl+Shift+P');
      expect(KeyChord.parse('enter').display, 'ENTER');
    });

    test('each modifier renders its own display string', () {
      expect(KeyChord.parse('ctrl+a').display, 'Ctrl+A');
      expect(KeyChord.parse('alt+a').display, 'Alt+A');
      expect(KeyChord.parse('shift+a').display, 'Shift+A');
      expect(KeyChord.parse('meta+a').display, 'Cmd+A');
    });

    test('toString embeds the canonical form', () {
      expect(KeyChord.parse('ctrl+shift+p').toString(), 'KeyChord(ctrl+shift+p)');
    });
  });

  group('KeyChord equality + hashing', () {
    test('equal chords have equal hash codes', () {
      final a = KeyChord.parse('ctrl+shift+p');
      final b = KeyChord.parse('shift+ctrl+p');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different keys are not equal', () {
      expect(KeyChord.parse('ctrl+a'), isNot(KeyChord.parse('ctrl+b')));
    });

    test('different modifier sets are not equal', () {
      expect(KeyChord.parse('ctrl+a'), isNot(KeyChord.parse('alt+a')));
    });
  });

  group('KeyChord.fromKeyEvent', () {
    final kb = HardwareKeyboard.instance;
    tearDown(() => kb.clearState());

    test('returns null for non-KeyDown / non-Repeat events', () {
      final up = KeyUpEvent(physicalKey: PhysicalKeyboardKey.keyA, logicalKey: LogicalKeyboardKey.keyA, timeStamp: Duration.zero);
      expect(KeyChord.fromKeyEvent(up, kb), isNull);
    });

    test('returns null for a bare modifier press', () {
      final down = KeyDownEvent(physicalKey: PhysicalKeyboardKey.controlLeft, logicalKey: LogicalKeyboardKey.controlLeft, timeStamp: Duration.zero);
      expect(KeyChord.fromKeyEvent(down, kb), isNull);
    });

    test('maps a plain key down to a modifier-free chord', () {
      final down = KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyA, logicalKey: LogicalKeyboardKey.keyA, timeStamp: Duration.zero);
      final chord = KeyChord.fromKeyEvent(down, kb)!;
      expect(chord.modifiers, isEmpty);
      expect(chord.key, LogicalKeyboardKey.keyA);
    });

    test('records every held modifier in the resulting chord', () {
      // Press all four modifiers, then a non-modifier key.
      for (final m in [
        (PhysicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlLeft),
        (PhysicalKeyboardKey.altLeft, LogicalKeyboardKey.altLeft),
        (PhysicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftLeft),
        (PhysicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaLeft),
      ]) {
        kb.handleKeyEvent(KeyDownEvent(physicalKey: m.$1, logicalKey: m.$2, timeStamp: Duration.zero));
      }
      final down = KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyP, logicalKey: LogicalKeyboardKey.keyP, timeStamp: Duration.zero);
      final chord = KeyChord.fromKeyEvent(down, kb)!;
      expect(chord.key, LogicalKeyboardKey.keyP);
      expect(chord.modifiers.toSet(), {KeyModifier.ctrl, KeyModifier.alt, KeyModifier.shift, KeyModifier.meta});
      expect(chord.canonical, 'ctrl+alt+shift+meta+p');
    });
  });

  group('KeyChord bare modifier (T-341)', () {
    test('parse(modifier-name) yields a modifier-free chord on the modifier key', () {
      final c = KeyChord.parse('shift');
      expect(c.modifiers, isEmpty);
      expect(c.key, LogicalKeyboardKey.shift);
      expect(c.canonical, 'shift');
    });

    test('every modifier name (and its aliases) parses as a bare key', () {
      expect(KeyChord.parse('ctrl').key, LogicalKeyboardKey.control);
      expect(KeyChord.parse('control').key, LogicalKeyboardKey.control);
      expect(KeyChord.parse('alt').key, LogicalKeyboardKey.alt);
      expect(KeyChord.parse('option').key, LogicalKeyboardKey.alt);
      expect(KeyChord.parse('meta').key, LogicalKeyboardKey.meta);
      expect(KeyChord.parse('cmd').key, LogicalKeyboardKey.meta);
    });

    test('KeyChord.bareModifier equals the parsed form (lookup key for the double-tap)', () {
      expect(KeyChord.bareModifier(KeyModifier.shift), KeyChord.parse('shift'));
      expect(KeyChord.bareModifier(KeyModifier.meta), KeyChord.parse('cmd'));
    });

    test("parseSequence('shift shift') is a two-chord double-tap", () {
      final seq = KeyChord.parseSequence('shift shift');
      expect(seq, hasLength(2));
      expect(seq[0], KeyChord.bareModifier(KeyModifier.shift));
      expect(seq[1], KeyChord.bareModifier(KeyModifier.shift));
    });

    test('canonical round-trips through parse', () {
      for (final m in KeyModifier.values) {
        final c = KeyChord.bareModifier(m);
        expect(KeyChord.parse(c.canonical), c, reason: m.name);
      }
    });

    test('modifierForLogicalKey collapses left/right/generic variants', () {
      expect(KeyChord.modifierForLogicalKey(LogicalKeyboardKey.shiftLeft), KeyModifier.shift);
      expect(KeyChord.modifierForLogicalKey(LogicalKeyboardKey.shiftRight), KeyModifier.shift);
      expect(KeyChord.modifierForLogicalKey(LogicalKeyboardKey.shift), KeyModifier.shift);
      expect(KeyChord.modifierForLogicalKey(LogicalKeyboardKey.controlLeft), KeyModifier.ctrl);
      expect(KeyChord.modifierForLogicalKey(LogicalKeyboardKey.altRight), KeyModifier.alt);
      expect(KeyChord.modifierForLogicalKey(LogicalKeyboardKey.metaLeft), KeyModifier.meta);
      expect(KeyChord.modifierForLogicalKey(LogicalKeyboardKey.keyA), isNull);
    });
  });
}
