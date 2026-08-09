import 'package:clide/builtin/clide_companion/src/clide_face.dart';
import 'package:clide/builtin/clide_companion/src/clide_strip.dart';
import 'package:clide/builtin/clide_companion/src/face_state.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/widgets/src/spacing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  /// Drive the test surface to [width] before pumping.
  ///
  /// Required, not optional: the default test view is 800px and a wider
  /// `SizedBox` is **clamped** to it, so a "1000px" case would silently render
  /// at 800 and assert nothing about the wide end. The geometry reference calls
  /// this out for exactly this reason (T-239/T-241) and it caught a false pass
  /// here.
  void surfaceAt(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Services tree without the shared `harness()`, whose Overlay consumes
  /// `initialEntries` only on first build and would keep serving the original
  /// child on later pumps (see clide_face_test.dart for the full note).
  Widget at(double width, Widget child, {MediaQueryData media = const MediaQueryData()}) => Directionality(
    textDirection: TextDirection.ltr,
    child: ClideKernel(
      services: f.services,
      child: ClideTheme(
        controller: f.services.theme,
        child: MediaQuery(
          data: media,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 400,
              child: Column(
                children: [
                  const Expanded(child: SizedBox()),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // The context panel's own drag range, from the classic preset
  // (layout_preset.dart:19). These are the only widths the strip can actually
  // be given — 420 is where it sits until the user drags.
  const snapPoints = [220.0, 420.0, 1000.0];

  group('renders across the context panel width range', () {
    for (final width in const [220.0, 420.0, 700.0, 1000.0]) {
      testWidgets('at ${width.toInt()}px', (tester) async {
        surfaceAt(tester, width);
        await tester.pumpWidget(at(width, const ClideStrip(message: 'that one hurt', debugFreezeAt: Duration(seconds: 1), debugClockLabel: '04:20')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ClideFace), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('height', () {
    testWidgets('takes exactly the resting height from the column', (tester) async {
      // The strip's cost is height taken from every detail view in this column,
      // on every ticket, decision, file and graph — so it is pinned by a test
      // rather than left to drift.
      surfaceAt(tester, 600);
      await tester.pumpWidget(at(600, const ClideStrip(debugFreezeAt: Duration.zero)));
      await tester.pump();
      expect(tester.getSize(find.byType(ClideStrip)).height, kClideStripHeight);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('spans the full column width rather than sizing to content', (tester) async {
      surfaceAt(tester, 700);
      await tester.pumpWidget(at(700, const ClideStrip(debugFreezeAt: Duration.zero)));
      await tester.pump();
      expect(tester.getSize(find.byType(ClideStrip)).width, 700);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the face gets the full width, not a boxed-off region', () {
    testWidgets('the face fills the strip so rain spans it', (tester) async {
      // Density is read as how many columns are lit. Penning the field into a
      // narrow face gutter would cut ~45 columns to ~9 and undo the reason a
      // strip beat a rail (T-514), so the face is full-bleed with the glyphs
      // aligned left instead.
      surfaceAt(tester, 1000);
      await tester.pumpWidget(at(1000, const ClideStrip(message: 'hello', debugFreezeAt: Duration(seconds: 1))));
      await tester.pump();
      expect(tester.getSize(find.byType(ClideFace)).width, 1000);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('bubble', () {
    testWidgets('shows when there is a message and room for it', (tester) async {
      surfaceAt(tester, 700);
      await tester.pumpWidget(at(700, const ClideStrip(message: 'two call sites, not one', debugFreezeAt: Duration.zero)));
      await tester.pump();
      expect(find.text('two call sites, not one'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is absent when there is nothing to say', (tester) async {
      surfaceAt(tester, 700);
      await tester.pumpWidget(at(700, const ClideStrip(debugFreezeAt: Duration.zero)));
      await tester.pump();
      expect(find.byType(ClideFace), findsOneWidget);
      expect(find.text('two call sites, not one'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is dropped at the narrow end rather than rendered cramped', (tester) async {
      // At the 220px minimum there is not enough width for face and bubble
      // both; a squeezed bubble reads worse than none.
      surfaceAt(tester, 220);
      await tester.pumpWidget(at(220, const ClideStrip(message: 'that one hurt', debugFreezeAt: Duration.zero)));
      await tester.pump();
      expect(find.text('that one hurt'), findsNothing);
      expect(find.byType(ClideFace), findsOneWidget, reason: 'the face must survive the narrow case');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('appears and disappears at one width, not over a fuzzy band', (tester) async {
      // Pins the snap point itself. Dropping the bubble is the strip's only
      // responsive branch, so the width it flips at is a contract — a widget
      // that shows it at 265 and hides it at 267 is a different design.
      const flip = 266.0;
      for (final (width, expected) in const [(flip - 1, findsNothing), (flip, findsOneWidget)]) {
        surfaceAt(tester, width);
        await tester.pumpWidget(at(width, const ClideStrip(message: 'snap', debugFreezeAt: Duration.zero)));
        await tester.pump();
        expect(find.text('snap'), expected, reason: 'at ${width}px');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a long message is clipped rather than overflowing the strip', (tester) async {
      surfaceAt(tester, 700);
      await tester.pumpWidget(at(700, ClideStrip(message: 'a very long remark ' * 40, debugFreezeAt: Duration.zero)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ClideStrip)).height, kClideStripHeight);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('media queries', () {
    // Text zoom is workspace-wide and applied as a MediaQuery textScaler at the
    // root (`root_shell.dart:111`), so every surface below it gets scaled text
    // whether or not it asked. The strip's height is fixed, which makes it
    // exactly the kind of surface that overflows at the top of the range.
    for (final scale in const [TextZoom.minScale, 1.0, TextZoom.maxScale]) {
      for (final width in snapPoints) {
        testWidgets('text zoom ${scale}x at ${width.toInt()}px neither overflows nor changes the height', (tester) async {
          const message = 'that commit touched two call sites, not one — the second is in the daemon handler';
          surfaceAt(tester, width);
          await tester.pumpWidget(
            at(
              width,
              const ClideStrip(state: FaceState.speaking, message: message, debugFreezeAt: Duration(seconds: 1), debugClockLabel: '04:20'),
              media: MediaQueryData(textScaler: TextScaler.linear(scale)),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(ClideStrip)).height, kClideStripHeight);
          // Innermost DecoratedBox above the message is the bubble's frame; the
          // outer one is the strip itself.
          final bubble = find.ancestor(of: find.text(message), matching: find.byType(DecoratedBox));
          if (bubble.evaluate().isNotEmpty) {
            // Not implied by the absence of an exception: the bubble sits in a
            // Stack, which clips to its bounds without complaining. An overflow
            // here is silent truncation of what Clide said.
            expect(
              tester.getSize(bubble.first).height,
              lessThanOrEqualTo(kClideStripHeight - clideInsetStandard * 2),
              reason: 'the bubble is silently clipped at ${scale}x',
            );
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    for (final width in snapPoints) {
      testWidgets('reduced motion at ${width.toInt()}px settles instead of animating forever', (tester) async {
        // The gate that matters most: a perpetual ticker under
        // disableAnimations hangs pumpAndSettle for its full 10-minute timeout
        // and takes the whole suite with it.
        surfaceAt(tester, width);
        await tester.pumpWidget(
          at(
            width,
            const ClideStrip(state: FaceState.effort, busyFor: Duration(seconds: 9), message: 'still going'),
            media: const MediaQueryData(disableAnimations: true),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ClideFace), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('state pass-through', () {
    testWidgets('forwards state, gaze and busyFor to the face', (tester) async {
      surfaceAt(tester, 700);
      await tester.pumpWidget(
        at(700, const ClideStrip(state: FaceState.effort, gaze: Gaze.left, busyFor: Duration(seconds: 9), debugFreezeAt: Duration(seconds: 1))),
      );
      await tester.pump();
      final face = tester.widget<ClideFace>(find.byType(ClideFace));
      expect(face.state, FaceState.effort);
      expect(face.gaze, Gaze.left);
      expect(face.busyFor, const Duration(seconds: 9));
      expect(face.faceAlignX, -1, reason: 'the face must sit left, per the approved wireframe');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
