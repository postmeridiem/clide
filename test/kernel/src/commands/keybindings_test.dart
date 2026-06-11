import 'package:clide/kernel/kernel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Keybinding.parse + equality', () {
    test('parses single-key bindings', () {
      final k = Keybinding.parse('g');
      expect(k.key, 'g');
      expect(k.modifiers, isEmpty);
    });

    test('parses modifier chains case-insensitively', () {
      final a = Keybinding.parse('Ctrl+Shift+G');
      final b = Keybinding.parse('shift+ctrl+g');
      expect(a, equals(b));
      expect(a.canonical, 'ctrl+shift+g');
    });

    test('rejects empty string', () {
      expect(() => Keybinding.parse(''), throwsA(isA<ArgumentError>()));
    });

    test('rejects spec ending in `+` (missing key)', () {
      expect(() => Keybinding.parse('ctrl+'), throwsA(isA<ArgumentError>()));
    });

    test('canonical modifier order is deterministic', () {
      final k = Keybinding.parse('alt+ctrl+shift+x');
      expect(k.modifiers, ['alt', 'ctrl', 'shift']);
    });

    test('canonical of modifier-free binding is just the key', () {
      expect(Keybinding.parse('escape').canonical, 'escape');
    });

    test('hashCode matches for equal bindings, differs for distinct', () {
      final a = Keybinding.parse('ctrl+shift+g');
      final b = Keybinding.parse('Shift+Ctrl+G');
      final c = Keybinding.parse('ctrl+g');
      expect(a.hashCode, b.hashCode);
      expect(a.hashCode, isNot(c.hashCode));
    });

    test('toString embeds canonical form', () {
      expect(Keybinding.parse('ctrl+k').toString(), 'Keybinding(ctrl+k)');
    });
  });

  group('KeybindingResolver', () {
    test('bind + lookup round-trips', () {
      final r = KeybindingResolver();
      r.bind(Keybinding.parse('ctrl+shift+g'), 'git.commit');
      expect(r.commandFor(Keybinding.parse('ctrl+shift+g')), 'git.commit');
      expect(r.commandFor(Keybinding.parse('ctrl+g')), isNull);
    });

    test('unbind removes the mapping', () {
      final r = KeybindingResolver();
      final k = Keybinding.parse('ctrl+p');
      r.bind(k, 'palette.open');
      r.unbind(k);
      expect(r.commandFor(k), isNull);
    });

    test('entries exposes registered bindings', () {
      final r = KeybindingResolver();
      r.bind(Keybinding.parse('ctrl+p'), 'palette.open');
      r.bind(Keybinding.parse('ctrl+shift+p'), 'palette.commands');
      final commands = r.entries.map((e) => e.value).toSet();
      expect(commands, {'palette.open', 'palette.commands'});
    });
  });

  group('KeybindingResolver.fromKeyEvent', () {
    late HardwareKeyboard kb;
    setUp(() => kb = HardwareKeyboard.instance);
    tearDown(() => kb.clearState());

    test('returns null for KeyUpEvent', () {
      final up = KeyUpEvent(physicalKey: PhysicalKeyboardKey.keyG, logicalKey: LogicalKeyboardKey.keyG, timeStamp: Duration.zero);
      expect(KeybindingResolver.fromKeyEvent(up, kb), isNull);
    });

    test('returns null when logicalKey has no keyLabel', () {
      // A synthetic logical key with an unassigned id has an empty label.
      final unlabeled = LogicalKeyboardKey(0x1000fffff);
      final down = KeyDownEvent(physicalKey: PhysicalKeyboardKey.controlLeft, logicalKey: unlabeled, timeStamp: Duration.zero);
      expect(KeybindingResolver.fromKeyEvent(down, kb), isNull);
    });

    test('maps a plain KeyDownEvent to a modifier-free Keybinding', () {
      final down = KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyG, logicalKey: LogicalKeyboardKey.keyG, timeStamp: Duration.zero);
      final b = KeybindingResolver.fromKeyEvent(down, kb);
      expect(b, isNotNull);
      expect(b!.key, 'g');
      expect(b.modifiers, isEmpty);
    });

    test('includes every held modifier in the resulting Keybinding', () {
      // Simulate ctrl+shift+alt+meta held, then a keyG down.
      _holdModifier(PhysicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlLeft);
      _holdModifier(PhysicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftLeft);
      _holdModifier(PhysicalKeyboardKey.altLeft, LogicalKeyboardKey.altLeft);
      _holdModifier(PhysicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaLeft);

      final down = KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyG, logicalKey: LogicalKeyboardKey.keyG, timeStamp: Duration.zero);
      final b = KeybindingResolver.fromKeyEvent(down, kb)!;
      expect(b.key, 'g');
      expect(b.modifiers.toSet(), {'ctrl', 'shift', 'alt', 'cmd'});
    });
  });
}

void _holdModifier(PhysicalKeyboardKey physical, LogicalKeyboardKey logical) {
  HardwareKeyboard.instance.handleKeyEvent(KeyDownEvent(physicalKey: physical, logicalKey: logical, timeStamp: Duration.zero));
}
