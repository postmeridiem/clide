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

  Widget view(CanvasDoc doc, {void Function(String?)? onSelect, double side = 400}) => anchoredHarness(
    f,
    SizedBox(
      width: side,
      height: side,
      child: CanvasView(doc: doc, onSelect: onSelect),
    ),
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
}
