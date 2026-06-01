/// T-207: the status-bar mode indicator shows `-- MODE --` while the Vim
/// layer is enabled and renders nothing otherwise.
library;

import 'package:clide/builtin/vim/vim.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  late VimModeService mode;

  setUp(() async {
    f = await KernelFixture.create();
    mode = VimModeService(f.services.keymap);
  });
  tearDown(() {
    mode.dispose();
    return f.dispose();
  });

  testWidgets('renders nothing while disabled', (tester) async {
    await tester.pumpWidget(harness(f, VimModeIndicator(service: mode)));
    await tester.pumpAndSettle();
    expect(find.textContaining('NORMAL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the active mode and updates on transition', (tester) async {
    mode.enabled = true;
    await tester.pumpWidget(harness(f, VimModeIndicator(service: mode)));
    await tester.pumpAndSettle();
    expect(find.text('-- NORMAL --'), findsOneWidget);

    mode.enterInsert();
    await tester.pumpAndSettle();
    expect(find.text('-- INSERT --'), findsOneWidget);
    expect(find.text('-- NORMAL --'), findsNothing);

    mode.enterVisual();
    await tester.pumpAndSettle();
    expect(find.text('-- VISUAL --'), findsOneWidget);
  });

  testWidgets('disabling hides the indicator', (tester) async {
    mode.enabled = true;
    await tester.pumpWidget(harness(f, VimModeIndicator(service: mode)));
    await tester.pumpAndSettle();
    expect(find.text('-- NORMAL --'), findsOneWidget);

    mode.enabled = false;
    await tester.pumpAndSettle();
    expect(find.textContaining('NORMAL'), findsNothing);
  });
}
