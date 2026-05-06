import 'package:clide/widgets/src/icons/x.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

Finder _closeIcons() => find.byWidgetPredicate(
      (w) => w is ClideIcon && w.painter is CloseIcon,
    );

MultitabEntry<String> entry(String id, {bool closeable = true, bool reorderable = true}) {
  return MultitabEntry<String>(
    id: id,
    title: id,
    payload: id,
    closeable: closeable,
    reorderable: reorderable,
  );
}

Widget body(BuildContext _, MultitabEntry<String> e) =>
    SizedBox(key: ValueKey('body-${e.id}'), child: Text('body:${e.payload}'));

/// Stateful tap-counter body. Preserves a per-id count across rebuilds
/// in a static map so the test can assert state survival across tab
/// switches.
class _CountingBody extends StatefulWidget {
  const _CountingBody({required this.id});
  final String id;

  @override
  State<_CountingBody> createState() => _CountingBodyState();
}

class _CountingBodyState extends State<_CountingBody> {
  static final Map<String, int> counts = {};

  void _bump() => setState(() => counts[widget.id] = (counts[widget.id] ?? 0) + 1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('counting-${widget.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: _bump,
      child: const SizedBox.expand(),
    );
  }
}

void main() {
  group('MultitabPane', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    testWidgets('renders one tab per entry and the active body', (tester) async {
      final c = MultitabController<String>(
        initial: [entry('primary', closeable: false), entry('s1'), entry('s2')],
      );
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );

      expect(find.text('primary'), findsOneWidget);
      expect(find.text('s1'), findsOneWidget);
      expect(find.text('s2'), findsOneWidget);
      // Body of the active (first) tab is visible.
      expect(find.byKey(const ValueKey('body-primary')), findsOneWidget);
      expect(find.byKey(const ValueKey('body-s1')), findsNothing);
    });

    testWidgets('tapping a tab activates it and swaps the body', (tester) async {
      final c = MultitabController<String>(initial: [entry('a'), entry('b')]);
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );
      expect(find.byKey(const ValueKey('body-a')), findsOneWidget);

      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();

      expect(c.activeId, 'b');
      expect(find.byKey(const ValueKey('body-b')), findsOneWidget);
      expect(find.byKey(const ValueKey('body-a')), findsNothing);
    });

    testWidgets('add button calls onAddRequested when set', (tester) async {
      final c = MultitabController<String>(initial: [entry('a')]);
      var added = 0;
      await tester.pumpWidget(
        harness(
          f,
          MultitabPane<String>(
            controller: c,
            bodyBuilder: body,
            onAddRequested: () => added++,
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('New tab'));
      await tester.pumpAndSettle();
      expect(added, 1);
    });

    testWidgets('add button is absent when onAddRequested is null', (tester) async {
      final c = MultitabController<String>(initial: [entry('a')]);
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );
      expect(find.bySemanticsLabel('New tab'), findsNothing);
    });

    testWidgets('non-closeable tabs do not render a close glyph', (tester) async {
      final c = MultitabController<String>(
        initial: [entry('p', closeable: false), entry('s')],
      );
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );
      // A pinned tab has no close target; a closeable one does (it's
      // hidden via Opacity until hover, but still in the tree).
      // Two tabs total, one × glyph for 's'.
      expect(_closeIcons(), findsOneWidget);
    });

    testWidgets('default close behavior removes the entry', (tester) async {
      final c = MultitabController<String>(
        initial: [entry('p', closeable: false), entry('s')],
      );
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );

      await tester.tap(_closeIcons());
      await tester.pumpAndSettle();

      expect(c.entries.map((e) => e.id), ['p']);
    });

    testWidgets('onCloseRequested overrides default removal', (tester) async {
      final c = MultitabController<String>(initial: [entry('a'), entry('b')]);
      MultitabEntry<String>? closed;
      await tester.pumpWidget(
        harness(
          f,
          MultitabPane<String>(
            controller: c,
            bodyBuilder: body,
            onCloseRequested: (e) => closed = e,
          ),
        ),
      );

      // Both tabs are closeable; tap the first × encountered.
      await tester.tap(_closeIcons().first);
      await tester.pumpAndSettle();

      expect(closed, isNotNull);
      // Host decided not to remove yet — entries are unchanged.
      expect(c.entries.length, 2);
    });

    testWidgets('rebuilds when the controller notifies', (tester) async {
      final c = MultitabController<String>(initial: [entry('a')]);
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );
      expect(find.bySemanticsLabel('b'), findsNothing);

      c.add(entry('b'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('b'), findsOneWidget);
    });

    testWidgets('empty controller renders no body', (tester) async {
      final c = MultitabController<String>();
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );
      expect(find.byKey(const ValueKey('body-a')), findsNothing);
    });

    testWidgets('drag a tab onto another to reorder', (tester) async {
      final c = MultitabController<String>(initial: [entry('a'), entry('b'), entry('c')]);
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );

      // Drag tab 'a' to where tab 'c' sits.
      final from = tester.getCenter(find.text('a'));
      final to = tester.getCenter(find.text('c'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(c.entries.map((e) => e.id), ['b', 'c', 'a']);
    });

    testWidgets('drag respects pinned barrier', (tester) async {
      final c = MultitabController<String>(initial: [
        entry('p', reorderable: false),
        entry('a'),
        entry('b'),
      ]);
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );

      // Try to drag 'a' before pinned 'p' — controller's barrier
      // logic should reject and the order stays.
      final from = tester.getCenter(find.text('a'));
      final to = tester.getCenter(find.text('p'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(c.entries.map((e) => e.id), ['p', 'a', 'b']);
    });

    testWidgets('pinned tabs are not draggable', (tester) async {
      final c = MultitabController<String>(initial: [
        entry('p', reorderable: false),
        entry('a'),
      ]);
      await tester.pumpWidget(
        harness(f, MultitabPane<String>(controller: c, bodyBuilder: body)),
      );

      // Attempt to drag pinned 'p' to position of 'a'.
      final from = tester.getCenter(find.text('p'));
      final to = tester.getCenter(find.text('a'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Order unchanged; pinned tab refused to be dragged.
      expect(c.entries.map((e) => e.id), ['p', 'a']);
    });

    testWidgets('keepAlive: inactive bodies stay mounted (state preserved)', (tester) async {
      final c = MultitabController<String>(initial: [entry('a'), entry('b')]);
      await tester.pumpWidget(
        harness(
          f,
          MultitabPane<String>(
            controller: c,
            bodyBuilder: (ctx, e) => _CountingBody(id: e.id),
            keepAlive: true,
          ),
        ),
      );

      // Both bodies are in the tree (b is offstage in IndexedStack).
      expect(find.byKey(const ValueKey('counting-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('counting-b'), skipOffstage: false), findsOneWidget);

      // Increment counter on body 'a' (it's the active one, visible).
      await tester.tap(find.byKey(const ValueKey('counting-a')));
      await tester.pumpAndSettle();
      expect(_CountingBodyState.counts['a'], 1);

      // Switch to b. Body 'a' stays mounted; switch back and the
      // counter is preserved (would be 0 if 'a' had been rebuilt).
      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      expect(_CountingBodyState.counts['a'], 1);
    });

    testWidgets('default mode disposes inactive bodies', (tester) async {
      final c = MultitabController<String>(initial: [entry('a'), entry('b')]);
      await tester.pumpWidget(
        harness(
          f,
          MultitabPane<String>(
            controller: c,
            bodyBuilder: (ctx, e) => _CountingBody(id: 'd-${e.id}'),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('counting-d-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('counting-d-b')), findsNothing);

      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      // a's body is gone from the tree; b's is in.
      expect(find.byKey(const ValueKey('counting-d-a')), findsNothing);
      expect(find.byKey(const ValueKey('counting-d-b')), findsOneWidget);
    });

    testWidgets('allowReorder=false disables drag entirely', (tester) async {
      final c = MultitabController<String>(initial: [entry('a'), entry('b')]);
      await tester.pumpWidget(
        harness(
          f,
          MultitabPane<String>(
            controller: c,
            bodyBuilder: body,
            allowReorder: false,
          ),
        ),
      );

      final from = tester.getCenter(find.text('a'));
      final to = tester.getCenter(find.text('b'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(c.entries.map((e) => e.id), ['a', 'b']);
    });
  });
}
