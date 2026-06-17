import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

SettingsCategory _cat(String id, {String? title, int priority = 0}) => SettingsCategory(id: id, title: title ?? id, priority: priority, sections: const []);

void main() {
  group('SettingsRegistry', () {
    test('register exposes categories sorted by (priority, title)', () {
      final r = SettingsRegistry();
      r.register(_cat('b', title: 'Beta', priority: 10));
      r.register(_cat('a', title: 'Alpha', priority: 10));
      r.register(_cat('z', title: 'Zeta', priority: 0));

      expect(r.categories.map((c) => c.id).toList(), ['z', 'a', 'b']);
    });

    test('byId resolves a registered category', () {
      final r = SettingsRegistry()..register(_cat('editor', title: 'Editor'));
      expect(r.byId('editor')?.title, 'Editor');
      expect(r.byId('missing'), isNull);
    });

    test('duplicate id throws (rolls activation back)', () {
      final r = SettingsRegistry()..register(_cat('dup'));
      expect(() => r.register(_cat('dup')), throwsStateError);
    });

    test('notifies on register and unregister', () {
      final r = SettingsRegistry();
      var n = 0;
      r.addListener(() => n++);
      r.register(_cat('x'));
      expect(n, 1);
      r.unregister('x');
      expect(n, 2);
      expect(r.categories, isEmpty);
    });

    test('unregister of an unknown id is a no-op (no notify)', () {
      final r = SettingsRegistry();
      var n = 0;
      r.addListener(() => n++);
      r.unregister('nope');
      expect(n, 0);
    });
  });
}
