import 'package:clide/src/svg/svg_document.dart';
import 'package:clide/widgets/src/draw/drawing_card.dart';
import 'package:clide/widgets/src/svg/svg_painter.dart';
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
}
