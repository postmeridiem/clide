/// T-54: the merged health + dock-toggle status-bar widget (D-87).
library;

import 'package:clide/builtin/default_layout/default_layout.dart';
import 'package:clide/builtin/output/output.dart';
import 'dart:ui';

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

bool _textIs(Object? w, String s) => w is ClideText && w.data == s;

void main() {
  late KernelFixture f;

  setUp(() async {
    // Seed builtin.output so the widget's own i18n lookups resolve — as they do
    // at boot in the real app. Otherwise "namespace not registered" warnings
    // land in the logRing this very widget counts, skewing the health badge.
    f = await KernelFixture.create(
      i18nCatalogs: {
        'builtin.output': {
          const Locale('en', 'US'): const {
            'dock.label': {'translation': 'Output'},
            'a11y.toggleDock': {'translation': 'toggle output dock'},
          },
        },
      },
    );
    f.services.extensions.register(DefaultLayoutExtension());
    await f.services.extensions.activate('builtin.default-layout');
  });
  tearDown(() => f.dispose());

  testWidgets('reads clean (green ✓), then shows the error count', (tester) async {
    await tester.pumpWidget(harness(f, const DockStatusItem()));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => _textIs(w, '✓')), findsOneWidget);

    f.services.logRing.add(LogRecord(level: LogLevel.error, source: 'x', message: 'boom', timestamp: DateTime.utc(2026)));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => _textIs(w, '✕ 1')), findsOneWidget);
  });

  testWidgets('shows a warn count when there are warnings but no errors', (tester) async {
    f.services.logRing.add(LogRecord(level: LogLevel.warn, source: 'x', message: 'w', timestamp: DateTime.utc(2026)));
    await tester.pumpWidget(harness(f, const DockStatusItem()));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => _textIs(w, '⚠ 1')), findsOneWidget);
  });

  testWidgets('tapping toggles the dock open', (tester) async {
    await tester.pumpWidget(harness(f, const DockStatusItem()));
    await tester.pumpAndSettle();
    expect(f.services.arrangement.isVisible(Slots.dock), isFalse);
    await tester.tap(find.byType(DockStatusItem));
    await tester.pumpAndSettle();
    expect(f.services.arrangement.isVisible(Slots.dock), isTrue);
    expect(find.byWidgetPredicate((w) => _textIs(w, '▼ Output ')), findsOneWidget);
  });
}
