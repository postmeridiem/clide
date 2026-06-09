/// Tests for ImageThumbnail (T-236 / T-254): a bounded, keyboard-activatable
/// image preview that opens the lightbox and degrades gracefully.
library;

import 'package:clide/builtin/claude/src/image_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('ImageThumbnail', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    testWidgets('carries an a11y label from the file name', (tester) async {
      await tester.pumpWidget(harness(f, const ImageThumbnail(path: '/tmp/clide/paste-9.png')));
      await tester.pump();
      expect(find.bySemanticsLabel('Image paste-9.png'), findsOneWidget);
    });

    testWidgets('a missing file degrades to a placeholder without throwing', (tester) async {
      await tester.pumpWidget(harness(f, const ImageThumbnail(path: '/no/such/file.png')));
      await tester.pumpAndSettle();
      expect(find.byType(ImageThumbnail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping opens the lightbox via the dialog router', (tester) async {
      await tester.pumpWidget(harness(f, const ImageThumbnail(path: '/no/such/file.png')));
      await tester.pump();
      expect(f.services.dialog.isOpen, isFalse);

      await tester.tap(find.byType(ImageThumbnail));
      await tester.pump();

      expect(f.services.dialog.isOpen, isTrue);
    });
  });
}
