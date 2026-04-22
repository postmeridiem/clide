import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    test('canonical modifier order is deterministic', () {
      final k = Keybinding.parse('alt+ctrl+shift+x');
      expect(k.modifiers, ['alt', 'ctrl', 'shift']);
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
  });
}
