import 'package:clide/builtin/claude/src/conversation_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async {
    f = await KernelFixture.create();
    // Let Clipboard.setData complete instead of throwing on the unmocked
    // platform channel, so ClideClipboard.writePlain reaches its history push.
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    f.dispose();
  });

  // Move a synthetic mouse over the card so the hover-revealed actions appear.
  Future<void> hoverCard(WidgetTester tester) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() => g.removePointer());
    await g.moveTo(tester.getCenter(find.byType(ConversationCard)));
    await tester.pump();
  }

  testWidgets('copy button (on hover) writes the copyText to the clipboard', (tester) async {
    await tester.pumpWidget(harness(
      f,
      const ConversationCard(
        accent: Color(0xFFFFFFFF),
        label: 'you',
        copyText: 'the raw message',
        body: Text('the raw message', textDirection: TextDirection.ltr),
      ),
    ));
    await tester.pump();
    expect(find.text('copy'), findsNothing); // hidden until hover

    await hoverCard(tester);
    expect(find.text('copy'), findsOneWidget);

    await tester.tap(find.text('copy'));
    // writePlain awaits the clipboard channel; let the real async settle.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(f.services.clipboard.readAs<String>(), 'the raw message');
  });

  testWidgets('collapsible card hides its body until expanded', (tester) async {
    await tester.pumpWidget(harness(
      f,
      const ConversationCard(
        variant: ConversationCardVariant.bordered,
        accent: Color(0xFFFFFFFF),
        label: 'result',
        collapsible: true,
        collapsedByDefault: true,
        body: Text('tool output here', textDirection: TextDirection.ltr),
      ),
    ));
    await tester.pump();
    expect(find.text('tool output here'), findsNothing); // collapsed

    await tester.tap(find.bySemanticsLabel('Expand'));
    await tester.pump();
    expect(find.text('tool output here'), findsOneWidget); // expanded
    expect(find.bySemanticsLabel('Collapse'), findsOneWidget);
  });

  testWidgets('a non-collapsible card always shows its body and no caret', (tester) async {
    await tester.pumpWidget(harness(
      f,
      const ConversationCard(
        accent: Color(0xFFFFFFFF),
        label: 'claude',
        body: Text('always visible', textDirection: TextDirection.ltr),
      ),
    ));
    await tester.pump();
    expect(find.text('always visible'), findsOneWidget);
    expect(find.bySemanticsLabel('Expand'), findsNothing);
    expect(find.bySemanticsLabel('Collapse'), findsNothing);
  });

  testWidgets('custom actions appear on hover and invoke', (tester) async {
    var forked = false;
    await tester.pumpWidget(harness(
      f,
      ConversationCard(
        accent: const Color(0xFFFFFFFF),
        label: 'claude',
        body: const Text('body', textDirection: TextDirection.ltr),
        actions: [MessageAction(label: 'fork', onInvoke: () => forked = true)],
      ),
    ));
    await tester.pump();
    expect(find.text('fork'), findsNothing);

    await hoverCard(tester);
    await tester.tap(find.text('fork'));
    await tester.pump();
    expect(forked, isTrue);
  });
}
