import 'package:clide/builtin/extensions_ui/extensions_ui.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ExtensionsUiExtension (T-456)', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    test('contributes an Extensions category backed by the notice control', () {
      final ext = ExtensionsUiExtension();
      final cat = ext.contributions.whereType<SettingsCategoryContribution>().firstWhere((c) => c.id == 'extensions').category;
      expect(cat.title, 'Extensions');
      final field = cat.sections.expand((s) => s.fields).single;
      expect(field.kind, SettingsFieldKind.custom);
      expect(field.customId, 'extensions.notice');
      expect(ext.contributions.whereType<SettingsControlContribution>().any((c) => c.customId == 'extensions.notice'), isTrue);
    });

    testWidgets('the notice explains that management arrives later', (tester) async {
      await tester.pumpWidget(harness(f, const SizedBox(width: 420, child: ExtensionsNotice())));
      expect(find.text('Extension management is coming'), findsOneWidget);
    });
  });
}
