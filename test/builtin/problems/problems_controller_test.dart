import 'package:clide/builtin/problems/src/problems_controller.dart';
import 'package:clide/src/env/supporter_binaries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('supporterToolProblems', () {
    test('flags a stale supporter-binary pin', () {
      final tools = SupporterBinaries(overrides: {'d2': '/gone/d2'}, exists: (_) => false);
      final ps = supporterToolProblems(tools);
      expect(ps.single.source, 'tools');
      expect(ps.single.message, contains('d2'));
      expect(ps.single.hint, isNotNull);
    });

    test('no problem when the configured path resolves', () {
      expect(supporterToolProblems(SupporterBinaries(overrides: {'d2': '/ok'}, exists: {'/ok'}.contains)), isEmpty);
    });

    test('no problem with no override or no resolver', () {
      expect(supporterToolProblems(SupporterBinaries(exists: (_) => false)), isEmpty);
      expect(supporterToolProblems(null), isEmpty);
    });
  });
}
