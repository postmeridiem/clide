/// T-459: the workspace editor top split must collapse cleanly when the
/// editor closes — no orphaned drag handle or empty region left over the
/// primary (Claude) pane.
///
/// This covers the render seam: given `arrangement.editorOpen`, the
/// `_WorkspaceSlot` either shows the split (editor body + drag handle over the
/// primary pane) or collapses to just the primary pane. The event seam that
/// flips `editorOpen` on the last buffer close is covered by the registry +
/// editor-extension tests.
library;

import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/shell/slot_host.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    // Stand-in workspace tabs: the real Claude pane / EditorView pull in PTY +
    // tree-sitter FFI, which the split-collapse contract doesn't need.
    f.services.panels.contribute(
      TabContribution(
        id: 'claude.primary',
        slot: Slots.workspace,
        title: 'Claude',
        priority: 90,
        build: (_) => const SizedBox(key: ValueKey('claude-body')),
      ),
    );
    f.services.panels.contribute(
      TabContribution(
        id: 'editor.active',
        slot: Slots.workspace,
        title: 'Editor',
        priority: 80,
        build: (_) => const SizedBox(key: ValueKey('editor-body')),
      ),
    );
  });
  tearDown(() => f.dispose());

  Finder dragHandle() => find.bySemanticsLabel('Editor split');

  testWidgets('editor top split collapses to the primary pane when the editor closes (T-459)', (tester) async {
    // Editor open + active: the split shows the editor body, the drag handle,
    // and the primary pane below.
    f.services.panels.activateTab(Slots.workspace, 'editor.active');
    f.services.arrangement.openEditor();
    await tester.pumpWidget(harness(f, const SlotHost(slot: Slots.workspace)));
    await tester.pump();

    expect(dragHandle(), findsOneWidget, reason: 'split should render its resize handle while the editor is open');
    expect(find.byKey(const ValueKey('editor-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('claude-body')), findsOneWidget);

    // Close the editor → the top split must drop out entirely, leaving only the
    // primary pane (no leftover drag handle / empty region).
    f.services.arrangement.closeEditor();
    await tester.pump();

    expect(dragHandle(), findsNothing, reason: 'collapsed split must not leave a drag handle behind');
    expect(find.byKey(const ValueKey('editor-body')), findsNothing, reason: 'closed editor body must not linger');
    expect(find.byKey(const ValueKey('claude-body')), findsOneWidget, reason: 'primary pane fills the column');
  });

  testWidgets('no split when the editor was never opened — primary pane only', (tester) async {
    f.services.panels.activateTab(Slots.workspace, 'claude.primary');
    await tester.pumpWidget(harness(f, const SlotHost(slot: Slots.workspace)));
    await tester.pump();

    expect(dragHandle(), findsNothing);
    expect(find.byKey(const ValueKey('claude-body')), findsOneWidget);
  });
}
