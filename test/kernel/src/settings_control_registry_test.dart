import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsControlRegistry', () {
    Widget builder(BuildContext _) => const SizedBox.shrink();

    test('register exposes a builder by id', () {
      final r = SettingsControlRegistry()..register('theme.picker', builder);
      expect(r.builderFor('theme.picker'), isNotNull);
      expect(r.builderFor('missing'), isNull);
    });

    test('duplicate id throws', () {
      final r = SettingsControlRegistry()..register('dup', builder);
      expect(() => r.register('dup', builder), throwsStateError);
    });

    test('unregister removes the builder', () {
      final r = SettingsControlRegistry()..register('x', builder);
      r.unregister('x');
      expect(r.builderFor('x'), isNull);
    });
  });
}
