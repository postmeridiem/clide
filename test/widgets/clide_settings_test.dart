import 'package:clide/clide.dart' show IpcResponse;
import 'package:clide/extension/extension.dart' show CommandContribution;
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

  testWidgets('i18n.string returns the placeholder without a kernel (T-462)', (tester) async {
    late String s;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          s = ClideSettings.i18n.string(context, 'k', namespace: 'x', placeholder: 'Fallback');
          return const SizedBox();
        },
      ),
    );
    expect(s, 'Fallback');
  });

  testWidgets('i18n.interpolated applies replacers to the placeholder without a kernel', (tester) async {
    late String s;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          s = ClideSettings.i18n.interpolated(
            context,
            'k',
            namespace: 'x',
            placeholder: 'Hi {name}',
            replacers: [I18nReplacer(from: '{name}', replace: 'Jeroen')],
          );
          return const SizedBox();
        },
      ),
    );
    expect(s, 'Hi Jeroen');
  });

  testWidgets('localizedCommandTitle resolves titleKey, else falls back to the title (T-462)', (tester) async {
    final withKey = CommandContribution(
      id: 'a',
      command: 'a',
      title: 'Eng A',
      titleKey: 'cmd.a',
      i18nNamespace: 'x',
      run: (_) async => IpcResponse.ok(id: '', data: const {}),
    );
    final noKey = CommandContribution(
      id: 'b',
      command: 'b',
      title: 'Eng B',
      run: (_) async => IpcResponse.ok(id: '', data: const {}),
    );
    late String a;
    late String b;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          a = localizedCommandTitle(context, withKey); // no kernel → placeholder (the title)
          b = localizedCommandTitle(context, noKey);
          return const SizedBox();
        },
      ),
    );
    expect(a, 'Eng A');
    expect(b, 'Eng B');
  });
}
