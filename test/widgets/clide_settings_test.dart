import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ClideSettings.fonts facade (D-101): reads the active families from a
/// [ClideSettingsScope], or the bundled defaults outside one.
void main() {
  testWidgets('fonts fall back to the bundled defaults without a scope', (tester) async {
    late String mono;
    late String ui;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          mono = ClideSettings.fonts.monoOf(context);
          ui = ClideSettings.fonts.uiOf(context);
          return const SizedBox();
        },
      ),
    );
    expect(mono, clideMonoFamily);
    expect(ui, clideUiFamily);
  });

  testWidgets('a scope provides the active families, read live', (tester) async {
    late String mono;
    late String ui;
    await tester.pumpWidget(
      ClideSettingsScope(
        ui: 'Inter',
        mono: 'FiraMono',
        child: Builder(
          builder: (context) {
            mono = ClideSettings.fonts.monoOf(context);
            ui = ClideSettings.fonts.uiOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(mono, 'FiraMono');
    expect(ui, 'Inter');
  });
}
