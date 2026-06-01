/// T-197: EditorExtension opens the workspace editor split when a buffer
/// opens and collapses it when the last one closes.
///
/// The workspace renders its editor split off `arrangement.editorOpen`
/// (not the active tab), so the extension must flip that flag — otherwise
/// `editor.open` opens the buffer daemon-side but nothing appears over
/// the Claude pane.
library;

import 'package:clide/builtin/editor/src/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    f.services.extensions.register(EditorExtension());
    await f.services.extensions.activate('builtin.editor');
  });
  tearDown(() => f.dispose());

  void emitEditor(String kind, {String? id}) {
    f.services.events.emit(DaemonEvent(subsystem: 'editor', kind: kind, data: {'id': id}, ts: DateTime.now().toUtc()));
  }

  test('contributes the editor.active workspace tab', () {
    expect(f.services.panels.tabsFor(Slots.workspace).any((t) => t.id == 'editor.active'), isTrue);
  });

  test('editor.opened opens the editor split', () async {
    expect(f.services.arrangement.editorOpen, isFalse);
    emitEditor('editor.opened', id: 'b_1');
    await Future<void>.delayed(Duration.zero);
    expect(f.services.arrangement.editorOpen, isTrue);
  });

  test('editor.active-changed with a buffer keeps the split open', () async {
    emitEditor('editor.active-changed', id: 'b_2');
    await Future<void>.delayed(Duration.zero);
    expect(f.services.arrangement.editorOpen, isTrue);
  });

  test('editor.active-changed with a null id collapses the split', () async {
    emitEditor('editor.opened', id: 'b_1');
    await Future<void>.delayed(Duration.zero);
    expect(f.services.arrangement.editorOpen, isTrue);

    emitEditor('editor.active-changed', id: null);
    await Future<void>.delayed(Duration.zero);
    expect(f.services.arrangement.editorOpen, isFalse);
  });

  test('a non-editor event does not open the split', () async {
    f.services.events.emit(DaemonEvent(subsystem: 'git', kind: 'changed', data: const {}, ts: DateTime.now().toUtc()));
    await Future<void>.delayed(Duration.zero);
    expect(f.services.arrangement.editorOpen, isFalse);
  });

  test('after deactivate, editor events no longer open the split', () async {
    await f.services.extensions.deactivate('builtin.editor');
    emitEditor('editor.opened', id: 'b_9');
    await Future<void>.delayed(Duration.zero);
    expect(f.services.arrangement.editorOpen, isFalse);
  });
}
