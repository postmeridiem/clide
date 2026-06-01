/// T-197: EditorExtension reveals its workspace tab when a buffer opens.
///
/// `editor.open` opens the buffer daemon-side and emits `editor.opened`,
/// but nothing else brings the editor tab to front over the Claude
/// pane. The extension's activate() listens for the editor lifecycle
/// events and activates the workspace tab.
library;

import 'package:clide/builtin/editor/src/extension.dart';
import 'package:clide/extension/extension.dart' show TabContribution;
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    f.services.panels.registerSlot(const SlotDefinition(id: Slots.workspace, position: SlotPosition.center));
    // A pre-existing workspace tab so 'editor.active' is NOT the default
    // active tab — the reveal must switch to it explicitly.
    f.services.panels.contribute(TabContribution(
      id: 'claude.primary',
      slot: Slots.workspace,
      title: 'Claude',
      build: (_) => const SizedBox(),
    ));
    f.services.extensions.register(EditorExtension());
    await f.services.extensions.activate('builtin.editor');
  });
  tearDown(() => f.dispose());

  void emitEditor(String kind, {String? id}) {
    f.services.events.emit(DaemonEvent(subsystem: 'editor', kind: kind, data: {'id': id}, ts: DateTime.now().toUtc()));
  }

  test('contributes editor.active but leaves Claude active by default', () {
    expect(f.services.panels.tabsFor(Slots.workspace).any((t) => t.id == 'editor.active'), isTrue);
    expect(f.services.panels.activeTabIn(Slots.workspace), 'claude.primary');
  });

  test('editor.opened reveals (activates) the editor tab', () async {
    emitEditor('editor.opened', id: 'b_1');
    await Future<void>.delayed(Duration.zero);
    expect(f.services.panels.activeTabIn(Slots.workspace), 'editor.active');
  });

  test('editor.active-changed also reveals the editor tab', () async {
    emitEditor('editor.active-changed', id: 'b_2');
    await Future<void>.delayed(Duration.zero);
    expect(f.services.panels.activeTabIn(Slots.workspace), 'editor.active');
  });

  test('a non-editor event leaves the active tab unchanged', () async {
    f.services.events.emit(DaemonEvent(subsystem: 'git', kind: 'changed', data: const {}, ts: DateTime.now().toUtc()));
    await Future<void>.delayed(Duration.zero);
    expect(f.services.panels.activeTabIn(Slots.workspace), 'claude.primary');
  });

  test('an unrelated editor event kind does not reveal', () async {
    emitEditor('editor.saved', id: 'b_1');
    await Future<void>.delayed(Duration.zero);
    expect(f.services.panels.activeTabIn(Slots.workspace), 'claude.primary');
  });

  test('after deactivate, editor events no longer reveal', () async {
    await f.services.extensions.deactivate('builtin.editor');
    emitEditor('editor.opened', id: 'b_9');
    await Future<void>.delayed(Duration.zero);
    expect(f.services.panels.activeTabIn(Slots.workspace), isNot('editor.active'));
  });
}
