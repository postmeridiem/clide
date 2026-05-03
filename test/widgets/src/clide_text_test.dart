import 'package:clide/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ClideText', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() async => f.dispose());

    testWidgets('renders the given string', (tester) async {
      await tester.pumpWidget(harness(f, const ClideText('hello world')));
      expect(find.text('hello world'), findsOneWidget);
    });

    testWidgets('default color is globalForeground token', (tester) async {
      await tester.pumpWidget(harness(f, const ClideText('x')));
      final text = tester.widget<Text>(find.byType(Text));
      final tokens = f.services.theme.current.surface;
      expect(text.style!.color, tokens.globalForeground);
    });

    testWidgets('muted mode uses globalTextMuted', (tester) async {
      await tester.pumpWidget(harness(f, const ClideText('x', muted: true)));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, f.services.theme.current.surface.globalTextMuted);
    });

    testWidgets('explicit color wins over tokens', (tester) async {
      await tester.pumpWidget(harness(f, const ClideText('x', color: Color(0xFFAABBCC))));
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.style!.color, const Color(0xFFAABBCC));
    });
  });
}
