/// Widget tests for ClideToast + ToastOverlay (T-50): render per severity,
/// manual dismiss, the live-region a11y contract, and the overlay reflecting
/// the ToastService queue. Toasts are shown sticky (Duration.zero) so no
/// auto-dismiss Timer is left pending at teardown.
library;

import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  Widget host(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: ClideKernel(
          services: f.services,
          child: ClideTheme(
            controller: f.services.theme,
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );

  testWidgets('renders the message and calls onDismiss when the × is tapped', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(host(ClideToast(
      entry: const ToastEntry(id: 1, message: 'Pushed to origin/main', severity: ToastSeverity.success),
      onDismiss: () => dismissed = true,
    )));
    await tester.pump(const Duration(milliseconds: 300)); // settle entrance

    expect(find.text('Pushed to origin/main'), findsOneWidget);
    // The dismiss × is the toast's only ClideTappable.
    await tester.tap(find.byType(ClideTappable));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('exposes the message as a live region (a11y)', (tester) async {
    await tester.pumpWidget(host(ClideToast(
      entry: const ToastEntry(id: 1, message: 'Heads up', severity: ToastSeverity.warning),
      onDismiss: () {},
    )));
    await tester.pump(const Duration(milliseconds: 300));

    // The message is wrapped in a live-region Semantics so screen readers
    // announce it when it appears.
    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true && w.properties.label == 'Heads up'),
      findsOneWidget,
    );
  });

  testWidgets('overlay renders a card per queued toast and dismiss removes one', (tester) async {
    await tester.pumpWidget(host(const SizedBox(
      width: 800,
      height: 600,
      child: Stack(children: [ToastOverlay()]),
    )));
    await tester.pump();
    expect(find.byType(ClideToast), findsNothing);

    f.services.toast.show('one', duration: Duration.zero);
    f.services.toast.show('two', severity: ToastSeverity.error, duration: Duration.zero);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ClideToast), findsNWidgets(2));
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);

    // Dismissing via the service updates the overlay (tap-to-dismiss is
    // covered by the ClideToast test above; here we assert reactivity).
    f.services.toast.dismiss(f.services.toast.entries.first.id);
    await tester.pump();
    expect(find.byType(ClideToast), findsNWidgets(1));
    expect(find.text('one'), findsNothing);
    expect(find.text('two'), findsOneWidget);
  });
}
