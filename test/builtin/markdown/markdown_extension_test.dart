/// T-36 / D-50 behavior 4+5: MarkdownExtension reveals the context-panel reader
/// when a renderable .md opens in the editor, and leaves a non-renderable file
/// alone. (The viewer then mirrors the buffer live — see markdown_viewer_test.)
library;

import 'package:clide/builtin/markdown/src/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;

  setUp(() async {
    f = await KernelFixture.create();
    f.services.extensions.register(MarkdownExtension());
    await f.services.extensions.activate('builtin.markdown');
  });
  tearDown(() => f.dispose());

  void open(String path) {
    f.services.events.emit(DaemonEvent(subsystem: 'editor', kind: 'editor.opened', data: {'id': 'b1', 'path': path}, ts: DateTime.now().toUtc()));
  }

  test('contributes the markdown.viewer context-panel tab', () {
    expect(f.services.panels.tabsFor(Slots.contextPanel).any((t) => t.id == 'markdown.viewer'), isTrue);
  });

  test('opening a renderable .md reveals the markdown viewer', () async {
    // markdown.viewer is the default contextPanel tab; flip to a sentinel first
    // so the reveal is observable.
    f.services.panels.activateTab(Slots.contextPanel, 'sentinel');
    open('docs/notes.md');
    await pumpEventQueue();
    expect(f.services.panels.activeTabIn(Slots.contextPanel), 'markdown.viewer');
  });

  test('opening a non-renderable file does not reveal it (D-50 behavior 5)', () async {
    f.services.panels.activateTab(Slots.contextPanel, 'sentinel');
    open('lib/main.dart');
    await pumpEventQueue();
    expect(f.services.panels.activeTabIn(Slots.contextPanel), 'sentinel');
  });

  test('after deactivate, editor.opened no longer reveals the viewer', () async {
    await f.services.extensions.deactivate('builtin.markdown');
    f.services.panels.activateTab(Slots.contextPanel, 'sentinel');
    open('notes.md');
    await pumpEventQueue();
    expect(f.services.panels.activeTabIn(Slots.contextPanel), 'sentinel');
  });
}
