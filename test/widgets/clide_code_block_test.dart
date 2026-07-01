import 'package:clide/kernel/src/syntax/syntax_result.dart' show SyntaxSpan;
import 'package:clide/kernel/src/theme/tokens.dart' show SurfaceTokens;
import 'package:clide/widgets/src/clide_code_block.dart';
import 'package:clide/widgets/src/clide_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';
import '../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  Future<SurfaceTokens> pumpForTokens(WidgetTester tester) async {
    late SurfaceTokens tokens;
    await tester.pumpWidget(
      anchoredHarness(
        f,
        Builder(
          builder: (ctx) {
            tokens = ClideSettings.theme.of(ctx).surface;
            return const SizedBox();
          },
        ),
      ),
    );
    return tokens;
  }

  testWidgets('renders plain source when no language is given', (tester) async {
    await tester.pumpWidget(anchoredHarness(f, const ClideCodeBlock(source: 'hello world')));
    await tester.pump();
    expect(find.byType(ClideCodeBlock), findsOneWidget);
  });

  testWidgets('renders plain source for an unknown language (no grammar)', (tester) async {
    await tester.pumpWidget(anchoredHarness(f, const ClideCodeBlock(source: 'x = 1', language: 'nolang')));
    await tester.pump();
    expect(find.byType(ClideCodeBlock), findsOneWidget);
  });

  testWidgets('buildHighlightedSpan maps byte spans to char ranges across multi-byte + surrogate chars', (tester) async {
    final tokens = await pumpForTokens(tester);
    // 'h😀é' — h=1 byte, 😀=surrogate pair (4 bytes / 2 code units), é=2 bytes.
    // Spans on the h (bytes 0–1) and the é (bytes 5–7); the emoji gap is filled
    // as plain text. The children must reconstruct the whole source — no bytes
    // dropped or mis-mapped.
    const src = 'h😀é';
    final span = buildHighlightedSpan(
      src,
      const [SyntaxSpan(start: 0, end: 1, role: 'keyword'), SyntaxSpan(start: 5, end: 7, role: 'string')],
      const TextStyle(),
      tokens,
    );
    final joined = span.children!.map((c) => (c as TextSpan).text ?? '').join();
    expect(joined, src);
  });

  testWidgets('buildHighlightedSpan clips overlapping spans without duplicating text', (tester) async {
    final tokens = await pumpForTokens(tester);
    final span = buildHighlightedSpan(
      'abcd',
      const [SyntaxSpan(start: 0, end: 3, role: 'a'), SyntaxSpan(start: 1, end: 4, role: 'b')], // overlap
      const TextStyle(),
      tokens,
    );
    final joined = span.children!.map((c) => (c as TextSpan).text ?? '').join();
    expect(joined, 'abcd');
  });
}
