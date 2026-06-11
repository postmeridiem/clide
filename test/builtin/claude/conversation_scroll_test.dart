/// T-297: when the bottom interaction zone resizes, the conversation re-anchors
/// to the tail (if pinned there) so content isn't left hidden behind the taller
/// box — and leaves a scrolled-up reader undisturbed.
///
/// T-368: the same gate applies to NEW ITEMS — they arrive on every streamed
/// token, and following the tail unconditionally yanked a scrolled-up reader
/// to the bottom for the whole reply.
library;

import 'dart:async';

import 'package:clide/builtin/claude/src/conversation_controller.dart';
import 'package:clide/builtin/claude/src/conversation_view.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

final _t = DateTime.utc(2026, 1, 1);
AssistantTextMessage _asst(String text, int i) => AssistantTextMessage(uuid: 'a$i', timestamp: _t, isSidechain: false, text: text);

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  ScrollPosition scrollPos(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  Future<(ConversationController, StreamController<ConversationItem>)> pump(WidgetTester tester, ValueNotifier<double> bottomH) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final stream = StreamController<ConversationItem>.broadcast();
    final c = ConversationController(stream: stream.stream);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      harness(
        f,
        SizedBox(
          width: 600,
          height: 600,
          child: Column(
            children: [
              Expanded(child: ConversationView(controller: c)),
              // Stand-in for the interaction zone (composer / prompt) whose height
              // changes; ValueListenableBuilder rebuilds just the box.
              ValueListenableBuilder<double>(
                valueListenable: bottomH,
                builder: (_, h, _) => SizedBox(height: h, width: 600),
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      stream.add(_asst('conversation line number $i', i));
    }
    await tester.pumpAndSettle();
    return (c, stream);
  }

  testWidgets('a growing bottom zone re-anchors the tail when pinned to bottom', (tester) async {
    final bottomH = ValueNotifier<double>(40);
    addTearDown(bottomH.dispose);
    await pump(tester, bottomH);

    final p = scrollPos(tester);
    expect(p.pixels, closeTo(p.maxScrollExtent, 1), reason: 'starts pinned to the tail');

    // The interaction zone grows (a permission prompt opened).
    bottomH.value = 220;
    await tester.pumpAndSettle();

    final p2 = scrollPos(tester);
    expect(p2.pixels, closeTo(p2.maxScrollExtent, 1), reason: 'still pinned after the zone grew');
  });

  testWidgets('a scrolled-up reader is not yanked when the zone resizes', (tester) async {
    final bottomH = ValueNotifier<double>(40);
    addTearDown(bottomH.dispose);
    await pump(tester, bottomH);

    // Scroll up, away from the tail.
    scrollPos(tester).jumpTo(30);
    await tester.pump();
    final before = scrollPos(tester).pixels;
    expect(before, closeTo(30, 1));

    bottomH.value = 220;
    await tester.pumpAndSettle();

    final after = scrollPos(tester);
    expect(after.pixels, closeTo(before, 1), reason: 'offset preserved; not re-anchored to bottom');
    expect(after.pixels, lessThan(after.maxScrollExtent - 8), reason: 'still not at the tail');
  });

  testWidgets('new streamed items keep following the tail when pinned', (tester) async {
    final bottomH = ValueNotifier<double>(40);
    addTearDown(bottomH.dispose);
    final (_, stream) = await pump(tester, bottomH);

    final p = scrollPos(tester);
    expect(p.pixels, closeTo(p.maxScrollExtent, 1), reason: 'starts pinned to the tail');

    for (var i = 40; i < 60; i++) {
      stream.add(_asst('streamed delta number $i', i));
    }
    await tester.pumpAndSettle();

    final p2 = scrollPos(tester);
    expect(p2.pixels, closeTo(p2.maxScrollExtent, 1), reason: 'still pinned after new items streamed in');
  });

  testWidgets('new streamed items do not yank a scrolled-up reader (T-368)', (tester) async {
    final bottomH = ValueNotifier<double>(40);
    addTearDown(bottomH.dispose);
    final (_, stream) = await pump(tester, bottomH);

    // Scroll up, away from the tail.
    scrollPos(tester).jumpTo(30);
    await tester.pump();
    final before = scrollPos(tester).pixels;
    expect(before, closeTo(30, 1));

    for (var i = 40; i < 60; i++) {
      stream.add(_asst('streamed delta number $i', i));
    }
    await tester.pumpAndSettle();

    final after = scrollPos(tester);
    expect(after.pixels, closeTo(before, 1), reason: 'reading position preserved while the reply streams');
    expect(after.pixels, lessThan(after.maxScrollExtent - 8), reason: 'still not at the tail');
  });
}
