/// T-252: ClideLightbox — full-screen zoom/pan overlay primitive.
library;

import 'package:clide/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

bool _textHas(Object? w, String s) => w is ClideText && w.data.contains(s);

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Widget box(VoidCallback onDismiss) => MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: ClideLightbox(onDismiss: onDismiss, child: const SizedBox(width: 200, height: 150)),
      );

  testWidgets('renders the zoom hint and an InteractiveViewer', (tester) async {
    await tester.pumpWidget(harness(f, box(() {})));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byWidgetPredicate((w) => _textHas(w, 'Esc to close')), findsOneWidget);
  });

  testWidgets('Esc dismisses', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(harness(f, box(() => dismissed = true)));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('the close button dismisses', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(harness(f, box(() => dismissed = true)));
    await tester.pumpAndSettle();
    await tester.tap(find.ancestor(of: find.byType(ClideIcon), matching: find.byType(GestureDetector)));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('double-tap resets without dismissing', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(harness(f, box(() => dismissed = true)));
    await tester.pumpAndSettle();
    final viewer = find.byType(InteractiveViewer);
    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    expect(dismissed, isFalse);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('a tap on the dimmed canvas dismisses; a tap on the image does not (T-309)', (tester) async {
    final img = (await tester.runAsync(() => createTestImage(width: 100, height: 100)))!; // 1:1; real async
    var dismissed = false;
    await tester.pumpWidget(harness(
      f,
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: ClideLightbox(onDismiss: () => dismissed = true, child: RawImage(image: img, fit: BoxFit.contain)),
      ),
    ));
    await tester.pumpAndSettle();

    // The 94% box is ~752×564; a 1:1 image fits to 564×564 centred, leaving
    // ~94px side margins. A tap in the left margin is dimmed canvas → dismiss.
    final r = tester.getRect(find.byType(InteractiveViewer));
    await tester.tapAt(Offset(r.left + 10, r.center.dy));
    await tester.pump(const Duration(milliseconds: 350)); // past the double-tap delay
    expect(dismissed, isTrue);

    // A tap on the image itself does not dismiss.
    dismissed = false;
    await tester.tapAt(r.center);
    await tester.pump(const Duration(milliseconds: 350));
    expect(dismissed, isFalse);
  });

  testWidgets('scroll wheel zooms in and out', (tester) async {
    await tester.pumpWidget(harness(f, box(() {})));
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.byType(InteractiveViewer));
    final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(center);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100))); // in
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100))); // out
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
