import 'package:clide/builtin/canvas/src/canvas_painter.dart';
import 'package:clide/builtin/canvas/src/canvas_view.dart';
import 'package:clide/src/canvas/json_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Widget view(CanvasDoc doc, {void Function(String?)? onSelect, void Function(CanvasDoc)? onChanged, bool editable = true, double side = 400}) =>
      anchoredHarness(
        f,
        SizedBox(
          width: side,
          height: side,
          child: CanvasView(doc: doc, onSelect: onSelect, onChanged: onChanged, editable: editable),
        ),
      );

  /// The live painter — the view owns its working document, so this is how
  /// a test sees what it currently holds.
  CanvasPainter painterOf(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.descendant(of: find.byType(CanvasView), matching: find.byType(CustomPaint)))
      .map((p) => p.painter)
      .whereType<CanvasPainter>()
      .single;

  /// Two spread-out nodes: one node alone fills the padded viewport, which
  /// makes screen-space assertions degenerate.
  const twoNodes = CanvasDoc(
    nodes: [
      TextNode(id: 'a', x: 0, y: 0, width: 100, height: 100, text: 'a'),
      TextNode(id: 'b', x: 300, y: 300, width: 100, height: 100, text: 'b'),
    ],
  );

  group('hitTestCanvasNode', () {
    test('finds the card under the point; cards beat the group behind them', () {
      const doc = CanvasDoc(
        nodes: [
          GroupNode(id: 'g', x: 0, y: 0, width: 400, height: 400),
          TextNode(id: 't', x: 150, y: 150, width: 100, height: 100, text: 'hi'),
        ],
      );
      // 400×400 doc into an 800×600 canvas, scale 1.5, centred. The text node's
      // centre (200,200 in canvas coords) → the card wins over the group.
      const size = Size(800, 600);
      final vp = CanvasViewport.fit(size, CanvasBounds.of(doc));
      final centre = vp.rectOf(doc.nodes[1]).center;
      expect(hitTestCanvasNode(doc, centre, size), 't');
      // A point inside the group but outside the card hits the group.
      final groupOnly = vp.rectOf(doc.nodes[0]).topLeft + const Offset(4, 4);
      expect(hitTestCanvasNode(doc, groupOnly, size), 'g');
    });

    test('returns null off any node and on an empty doc', () {
      const doc = CanvasDoc(
        nodes: [TextNode(id: 't', x: 0, y: 0, width: 10, height: 10, text: '')],
      );
      expect(hitTestCanvasNode(doc, const Offset(-999, -999), const Size(400, 400)), isNull);
      expect(hitTestCanvasNode(const CanvasDoc(), Offset.zero, const Size(400, 400)), isNull);
    });
  });

  testWidgets('tapping a node selects it, tapping empty space clears it', (tester) async {
    String? picked = '__unset__';
    // One node fills the padded canvas, so its centre is the view centre.
    const doc = CanvasDoc(
      nodes: [TextNode(id: 'only', x: 0, y: 0, width: 100, height: 100, text: 'hi')],
    );
    await tester.pumpWidget(view(doc, onSelect: (id) => picked = id));
    await tester.pump();

    await tester.tap(find.byType(CanvasView)); // centre → the node
    expect(picked, 'only');

    await tester.tapAt(tester.getTopLeft(find.byType(CanvasView)) + const Offset(3, 3)); // padding → miss
    expect(picked, isNull);
  });

  testWidgets('dragging pans; a reverse drag restores the hit location', (tester) async {
    String? picked = '__unset__';
    // Two small, spread-out nodes so each renders small enough that a pan moves
    // it clear of its old screen spot (a single node would fill the pane).
    const doc = CanvasDoc(
      nodes: [
        TextNode(id: 'a', x: 0, y: 0, width: 60, height: 60, text: 'a'),
        TextNode(id: 'b', x: 400, y: 400, width: 60, height: 60, text: 'b'),
      ],
    );
    await tester.pumpWidget(view(doc, onSelect: (id) => picked = id));
    await tester.pump();
    final origin = tester.getTopLeft(find.byType(CanvasView));
    final size = tester.getSize(find.byType(CanvasView));
    final aSpot = origin + CanvasViewport.fit(size, CanvasBounds.of(doc)).rectOf(doc.nodes[0]).center;

    await tester.tapAt(aSpot);
    expect(picked, 'a'); // baseline hit

    await tester.drag(find.byType(CanvasView), const Offset(140, 0));
    await tester.pump();
    await tester.tapAt(aSpot);
    expect(picked, isNull); // node a panned away from its old spot

    await tester.drag(find.byType(CanvasView), const Offset(-140, 0)); // equal, opposite → net zero
    await tester.pump();
    await tester.tapAt(aSpot);
    expect(picked, 'a'); // panned back
  });

  testWidgets('a scroll signal zooms without throwing', (tester) async {
    const doc = CanvasDoc(
      nodes: [TextNode(id: 'a', x: 0, y: 0, width: 100, height: 100, text: '')],
    );
    await tester.pumpWidget(view(doc));
    await tester.pump();
    final centre = tester.getCenter(find.byType(CanvasView));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(centre));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pump();
    expect(find.byType(CanvasView), findsOneWidget);
  });

  testWidgets('an empty canvas takes a tap without throwing', (tester) async {
    await tester.pumpWidget(view(const CanvasDoc()));
    await tester.pump();
    await tester.tap(find.byType(CanvasView));
    expect(find.byType(CanvasView), findsOneWidget);
  });

  group('editing', () {
    /// Where a node sits on screen, given the view's frozen fit.
    Rect screenRect(WidgetTester tester, CanvasDoc doc, int index) {
      final origin = tester.getTopLeft(find.byType(CanvasView));
      final size = tester.getSize(find.byType(CanvasView));
      return CanvasViewport.fit(size, CanvasBounds.of(doc)).rectOf(doc.nodes[index]).shift(origin);
    }

    double scaleOf(WidgetTester tester, CanvasDoc doc) => CanvasViewport.fit(tester.getSize(find.byType(CanvasView)), CanvasBounds.of(doc)).scale;

    testWidgets('dragging a node moves it, pinning the other nodes', (tester) async {
      CanvasDoc? saved;
      await tester.pumpWidget(view(twoNodes, onChanged: (d) => saved = d));
      await tester.pump();
      final scale = scaleOf(tester, twoNodes);

      await tester.dragFrom(screenRect(tester, twoNodes, 0).center, const Offset(44, 22), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();

      final a = saved!.node('a')!;
      expect(a.x, closeTo(44 / scale, 0.01));
      expect(a.y, closeTo(22 / scale, 0.01));
      expect((a.width, a.height), (100.0, 100.0), reason: 'a move must not resize');
      expect((saved!.node('b')!.x, saved!.node('b')!.y), (300.0, 300.0));
    });

    testWidgets('onChanged fires once per gesture, not per frame', (tester) async {
      var calls = 0;
      await tester.pumpWidget(view(twoNodes, onChanged: (_) => calls++));
      await tester.pump();
      final start = screenRect(tester, twoNodes, 0).center;

      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(calls, 0, reason: 'mid-drag frames must not persist');
      await gesture.up();
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('dragging a corner handle resizes, pinning the opposite corner', (tester) async {
      CanvasDoc? saved;
      await tester.pumpWidget(view(twoNodes, onChanged: (d) => saved = d));
      await tester.pump();
      final scale = scaleOf(tester, twoNodes);
      final rect = screenRect(tester, twoNodes, 0);

      await tester.tapAt(rect.center); // handles only respond on the selection
      await tester.pump();
      await tester.dragFrom(rect.bottomRight, const Offset(44, 44), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();

      final a = saved!.node('a')!;
      expect((a.x, a.y), (0.0, 0.0), reason: 'the top-left corner is pinned');
      expect(a.width, closeTo(100 + 44 / scale, 0.01));
      expect(a.height, closeTo(100 + 44 / scale, 0.01));
    });

    testWidgets('the north-west handle moves the origin and shrinks the node', (tester) async {
      CanvasDoc? saved;
      await tester.pumpWidget(view(twoNodes, onChanged: (d) => saved = d));
      await tester.pump();
      final scale = scaleOf(tester, twoNodes);
      final rect = screenRect(tester, twoNodes, 0);

      await tester.tapAt(rect.center);
      await tester.pump();
      await tester.dragFrom(rect.topLeft, const Offset(22, 22), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();

      final a = saved!.node('a')!;
      expect(a.x, closeTo(22 / scale, 0.01));
      expect(a.y, closeTo(22 / scale, 0.01));
      expect(a.width, closeTo(100 - 22 / scale, 0.01));
      expect(a.x + a.width, closeTo(100, 0.01), reason: 'the bottom-right corner is pinned');
    });

    testWidgets('a resize stops at the minimum size instead of inverting', (tester) async {
      CanvasDoc? saved;
      await tester.pumpWidget(view(twoNodes, onChanged: (d) => saved = d));
      await tester.pump();
      final rect = screenRect(tester, twoNodes, 0);

      await tester.tapAt(rect.center);
      await tester.pump();
      // Far past the opposite edge — a node dragged inside-out would be
      // unselectable afterwards, so there'd be no way back.
      await tester.dragFrom(rect.bottomRight, const Offset(-400, -400), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();

      final a = saved!.node('a')!;
      expect((a.width, a.height), (20.0, 20.0));
      expect((a.x, a.y), (0.0, 0.0));
    });

    testWidgets('dragging empty space pans and leaves the document alone', (tester) async {
      var calls = 0;
      await tester.pumpWidget(view(twoNodes, onChanged: (_) => calls++));
      await tester.pump();
      final origin = tester.getTopLeft(find.byType(CanvasView));

      await tester.dragFrom(origin + const Offset(3, 3), const Offset(40, 0), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();

      expect(calls, 0);
      expect(painterOf(tester).doc.node('a')!.x, 0);
      expect(painterOf(tester).pan.dx, 40);
    });

    testWidgets('a non-editable view pans instead of moving a node, and draws no handles', (tester) async {
      var calls = 0;
      await tester.pumpWidget(view(twoNodes, editable: false, onChanged: (_) => calls++));
      await tester.pump();

      expect(painterOf(tester).showHandles, isFalse);
      await tester.dragFrom(screenRect(tester, twoNodes, 0).center, const Offset(40, 0), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();

      expect(calls, 0);
      expect(painterOf(tester).doc.node('a')!.x, 0, reason: 'the document is read-only');
      expect(painterOf(tester).pan.dx, 40);
    });

    testWidgets('a view with no onChanged is read-only even when editable', (tester) async {
      await tester.pumpWidget(view(twoNodes));
      await tester.pump();
      expect(painterOf(tester).showHandles, isFalse);
      await tester.dragFrom(screenRect(tester, twoNodes, 0).center, const Offset(40, 0), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();
      expect(painterOf(tester).doc.node('a')!.x, 0);
    });

    testWidgets('the viewport does not re-fit as a node is dragged', (tester) async {
      // Bounds are frozen when the doc is adopted. Re-deriving them per
      // paint would re-scale the canvas mid-drag, sliding it under the
      // cursor — so node 'b', which is not being dragged, must not move.
      await tester.pumpWidget(view(twoNodes, onChanged: (_) {}));
      await tester.pump();
      final before = painterOf(tester).bounds;

      // Drag 'a' well outside the original content bounds.
      await tester.dragFrom(screenRect(tester, twoNodes, 0).center, const Offset(-150, -150), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();

      expect(painterOf(tester).bounds, before);
      expect(painterOf(tester).doc.node('a')!.x, lessThan(0), reason: 'the node really did leave the original bounds');
    });

    testWidgets('the edited document echoing back keeps selection and pan', (tester) async {
      // The pane feeds onChanged straight back in as `doc`. That must not
      // read as "a new document" and reset the view.
      await tester.pumpWidget(anchoredHarness(f, const SizedBox(width: 400, height: 400, child: _EchoingCanvas(doc: twoNodes))));
      await tester.pump();
      final rect = screenRect(tester, twoNodes, 0);

      await tester.tapAt(rect.center);
      await tester.pump();
      expect(painterOf(tester).selected, 'a');

      await tester.dragFrom(rect.center, const Offset(30, 0), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();

      expect(painterOf(tester).selected, 'a', reason: 'selection survives the echo');
      expect(painterOf(tester).doc.node('a')!.x, greaterThan(0));
    });

    testWidgets('a genuinely new document resets zoom, pan and selection', (tester) async {
      // Swapped through a notifier, not a second pumpWidget: the shared
      // harness's Overlay only honours initialEntries on its first build,
      // so re-pumping would leave the original child mounted.
      final docs = ValueNotifier<CanvasDoc>(twoNodes);
      addTearDown(docs.dispose);
      await tester.pumpWidget(
        anchoredHarness(
          f,
          SizedBox(
            width: 400,
            height: 400,
            child: ValueListenableBuilder<CanvasDoc>(
              valueListenable: docs,
              builder: (_, doc, _) => CanvasView(doc: doc, onChanged: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tapAt(screenRect(tester, twoNodes, 0).center);
      await tester.dragFrom(tester.getTopLeft(find.byType(CanvasView)) + const Offset(3, 3), const Offset(40, 0), touchSlopX: 0, touchSlopY: 0);
      await tester.pump();
      expect(painterOf(tester).selected, 'a');
      expect(painterOf(tester).pan.dx, 40);

      docs.value = const CanvasDoc(
        nodes: [TextNode(id: 'z', x: 0, y: 0, width: 50, height: 50, text: 'z')],
      );
      await tester.pump();

      expect(painterOf(tester).selected, isNull);
      expect(painterOf(tester).pan, Offset.zero);
      expect(painterOf(tester).doc.node('z'), isNotNull);
    });
  });
}

/// Feeds every edit straight back in as the input document — what the pane
/// host does once persistence is wired.
class _EchoingCanvas extends StatefulWidget {
  const _EchoingCanvas({required this.doc});

  final CanvasDoc doc;

  @override
  State<_EchoingCanvas> createState() => _EchoingCanvasState();
}

class _EchoingCanvasState extends State<_EchoingCanvas> {
  late CanvasDoc _doc = widget.doc;

  @override
  Widget build(BuildContext context) => CanvasView(doc: _doc, onChanged: (d) => setState(() => _doc = d));
}
