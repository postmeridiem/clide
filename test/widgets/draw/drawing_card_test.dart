import 'package:clide/src/svg/svg_document.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:clide/widgets/src/clide_tappable.dart';
import 'package:clide/widgets/src/draw/drawing_card.dart';
import 'package:clide/widgets/src/svg/svg_painter.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() async => f.dispose());

  Widget card({String? label, String? description}) => SizedBox(
    width: 400,
    child: DrawingCard(
      document: buildSvgDocument('<svg viewBox="0 0 20 10"><rect width="20" height="10" fill="#FF0000"/></svg>'),
      label: label,
      description: description,
    ),
  );

  testWidgets('renders the SVG region with both captions', (tester) async {
    await tester.pumpWidget(anchoredHarness(f, card(label: 'Build pipeline', description: 'how it connects')));
    expect(find.byType(SvgView), findsOneWidget);
    expect(find.text('Build pipeline'), findsOneWidget);
    expect(find.text('how it connects'), findsOneWidget);
  });

  testWidgets('omits captions when label and description are absent', (tester) async {
    await tester.pumpWidget(anchoredHarness(f, card()));
    expect(find.byType(SvgView), findsOneWidget);
    expect(find.text('Build pipeline'), findsNothing);
  });

  testWidgets('renders per-object captions from data-* annotations (T-318)', (tester) async {
    final doc = buildSvgDocument(
      '<svg viewBox="0 0 100 50"><rect x="10" y="10" width="40" height="20" data-label="Node A" data-description="the entry point"/></svg>',
    );
    await tester.pumpWidget(anchoredHarness(f, SizedBox(width: 400, child: DrawingCard(document: doc))));
    await tester.pump();
    expect(find.text('Node A'), findsOneWidget);
    expect(find.text('the entry point'), findsOneWidget);
  });

  testWidgets('a source disclosure folds the d2 source under a collapser (T-494)', (tester) async {
    await tester.pumpWidget(
      anchoredHarness(
        f,
        SizedBox(
          width: 400,
          child: DrawingCard(
            document: buildSvgDocument('<svg viewBox="0 0 20 10"><rect width="20" height="10"/></svg>'),
            source: 'a -> b: hello',
            sourceLabel: 'view d2 source',
          ),
        ),
      ),
    );
    await tester.pump();
    // The disclosure header shows; the source is folded away until expanded.
    expect(find.text('view d2 source'), findsOneWidget);
    expect(find.text('a -> b: hello'), findsNothing);
    await tester.tap(find.text('view d2 source'));
    await tester.pumpAndSettle();
    expect(find.text('a -> b: hello'), findsOneWidget);
  });

  testWidgets('a data-lightbox element fires onLightbox when tapped (T-318)', (tester) async {
    var tapped = false;
    final doc = buildSvgDocument('<svg viewBox="0 0 100 50"><rect x="0" y="0" width="100" height="50" data-lightbox=""/></svg>');
    await tester.pumpWidget(
      anchoredHarness(
        f,
        SizedBox(
          width: 400,
          child: DrawingCard(document: doc, onLightbox: () => tapped = true),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(DrawingCard));
    expect(tapped, isTrue);
  });

  group('whole-card lightbox affordance (T-563)', () {
    // No data-lightbox anywhere: the default open target is the card itself.
    Widget openable(VoidCallback onLightbox) => SizedBox(
      width: 400,
      child: DrawingCard(document: buildSvgDocument('<svg viewBox="0 0 20 10"><rect width="20" height="10" fill="#FF0000"/></svg>'), onLightbox: onLightbox),
    );

    testWidgets('a tap anywhere on the drawing opens the lightbox', (tester) async {
      var opened = 0;
      await tester.pumpWidget(anchoredHarness(f, openable(() => opened++)));
      await tester.tap(find.byType(SvgView));
      expect(opened, 1);
    });

    testWidgets('carries a labelled semantics button whose tap action opens it', (tester) async {
      final handle = tester.ensureSemantics();
      var opened = 0;
      await tester.pumpWidget(anchoredHarness(f, openable(() => opened++)));
      expect(find.bySemanticsLabel('Open drawing in full view'), findsOneWidget);
      tester.semantics.tap(find.semantics.byLabel('Open drawing in full view'));
      expect(opened, 1);
      handle.dispose();
    });

    testWidgets('is keyboard-focusable and opens on Activate (Enter/Space)', (tester) async {
      var opened = 0;
      await tester.pumpWidget(anchoredHarness(f, openable(() => opened++)));
      final focus = tester.widget<Focus>(find.descendant(of: find.byType(ClideTappable), matching: find.byType(Focus)).first);
      focus.focusNode!.requestFocus();
      await tester.pump();
      expect(focus.focusNode!.hasFocus, isTrue);
      // The keymap binds Enter/Space to ActivateIntent; invoke it directly as
      // the collapser's a11y test does.
      Actions.invoke(focus.focusNode!.context!, const ActivateIntent());
      expect(opened, 1);
    });

    testWidgets('hovering lights the frame in the focus colour', (tester) async {
      await tester.pumpWidget(anchoredHarness(f, openable(() {})));
      final tokens = ClideSettings.theme.of(tester.element(find.byType(DrawingCard))).surface;
      Color frameColor() {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(ClideTappable),
            matching: find.byWidgetPredicate((w) => w is DecoratedBox && (w.decoration as BoxDecoration).color == tokens.panelBackground),
          ),
        );
        return ((box.decoration as BoxDecoration).border! as Border).top.color;
      }

      expect(frameColor(), tokens.panelBorder);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(SvgView)));
      await tester.pump();
      expect(frameColor(), tokens.globalFocus);
      // Leave, and let the tooltip's hover-delay timer run out.
      await mouse.moveTo(const Offset(-10, -10));
      await tester.pump(const Duration(seconds: 1));
      expect(frameColor(), tokens.panelBorder);
    });

    testWidgets('no onLightbox means no open target', (tester) async {
      await tester.pumpWidget(anchoredHarness(f, card()));
      expect(find.byType(ClideTappable), findsNothing);
    });
  });
}
