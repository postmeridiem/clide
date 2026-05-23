/// Tests for the per-session status strip (T-145): formatters and the
/// widget's render of model · permission-mode · context.
library;

import 'package:clide/builtin/claude/src/claude_status_strip.dart';
import 'package:clide/builtin/claude/src/transcript_reader.dart';
import 'package:clide/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  group('status formatters', () {
    test('shortModelLabel strips the claude- prefix and dots the version', () {
      expect(shortModelLabel('claude-opus-4-7'), 'opus 4.7');
      expect(shortModelLabel('claude-sonnet-4-6'), 'sonnet 4.6');
      expect(shortModelLabel('weird'), 'weird');
    });

    test('permissionModeLabel humanises CC modes', () {
      expect(permissionModeLabel('acceptEdits'), 'accept-edits');
      expect(permissionModeLabel('bypassPermissions'), 'bypass');
      expect(permissionModeLabel('plan'), 'plan');
      expect(permissionModeLabel('default'), 'default');
      expect(permissionModeLabel('something-new'), 'something-new');
    });

    test('formatTokenCount uses k / M / raw', () {
      expect(formatTokenCount(500), '500');
      expect(formatTokenCount(765000), '765k');
      expect(formatTokenCount(1200000), '1.2M');
    });
  });

  group('ClaudeStatusStrip', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    testWidgets('renders model, mode, and context', (tester) async {
      await tester.pumpWidget(harness(
        f,
        const ClaudeStatusStrip(
          status: SessionStatus(model: 'claude-opus-4-7', permissionMode: 'acceptEdits', contextTokens: 765000),
        ),
      ));
      expect(find.textContaining('opus 4.7'), findsOneWidget);
      expect(find.textContaining('accept-edits'), findsOneWidget);
      expect(find.textContaining('765k ctx'), findsOneWidget);
    });

    testWidgets('empty status renders nothing', (tester) async {
      await tester.pumpWidget(harness(f, const ClaudeStatusStrip(status: SessionStatus())));
      expect(find.byType(ClideText), findsNothing);
    });
  });
}
