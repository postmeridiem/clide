/// CanvasExtension (T-322) contributes the canvas pane into the workspace
/// slot and routes `selection` messages (openWorkspaceFile,
/// `clide ui open canvas [path]`) into app-scoped document tabs — the
/// diff/T-233 pattern.
library;

import 'package:clide/builtin/canvas/canvas.dart';
import 'package:clide/extension/extension.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';

/// Drain the broadcast-stream microtask hop between a bus publish/emit and
/// the extension's listener. Plain `test` body — no fake-async zone, so a
/// zero-duration timer fires normally.
Future<void> deliver() => Future<void>.delayed(Duration.zero);

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  test('declares one workspace tab with the canvas.view identity', () {
    final tabs = CanvasExtension().contributions.whereType<TabContribution>().toList();
    expect(tabs, hasLength(1));
    final t = tabs.single;
    expect(t.id, 'canvas.view');
    expect(t.slot, Slots.workspace);
    expect(t.title, 'Canvas');
    expect(t.titleKey, 'tab.title');
    expect(t.i18nNamespace, 'builtin.canvas');
  });

  test('registers into the workspace slot once activated', () async {
    f.services.extensions.register(CanvasExtension());
    await f.services.extensions.activate('builtin.canvas');
    expect(f.services.panels.tabsFor(Slots.workspace).any((t) => t.id == 'canvas.view'), isTrue);
  });

  test('a selection message opens a document tab and reveals the pane', () async {
    final ext = CanvasExtension();
    f.services.extensions.register(ext);
    await f.services.extensions.activate('builtin.canvas');

    f.services.messages.publish('builtin.canvas', 'selection', {'path': 'notes/board.canvas'});
    await deliver();

    expect(ext.openPaths, ['notes/board.canvas']);
    expect(f.services.panels.activeTabIn(Slots.workspace), 'canvas.view');
  });

  test('re-selecting an open document focuses it instead of duplicating', () async {
    final ext = CanvasExtension();
    f.services.extensions.register(ext);
    await f.services.extensions.activate('builtin.canvas');

    f.services.messages.publish('builtin.canvas', 'selection', {'path': 'a.canvas'});
    f.services.messages.publish('builtin.canvas', 'selection', {'path': 'b.canvas'});
    f.services.messages.publish('builtin.canvas', 'selection', {'path': 'a.canvas'});
    await deliver();

    expect(ext.openPaths, ['a.canvas', 'b.canvas']);
  });

  test('a malformed selection payload is ignored', () async {
    final ext = CanvasExtension();
    f.services.extensions.register(ext);
    await f.services.extensions.activate('builtin.canvas');

    f.services.messages.publish('builtin.canvas', 'selection', {'path': ''});
    f.services.messages.publish('builtin.canvas', 'selection', {'nope': 1});
    await deliver();

    expect(ext.openPaths, isEmpty);
  });

  test('an in-place workspace switch drops the open documents (T-269)', () async {
    final ext = CanvasExtension();
    f.services.extensions.register(ext);
    await f.services.extensions.activate('builtin.canvas');

    f.services.events.emit(const ProjectOpened(path: '/repo/a'));
    await deliver();
    f.services.messages.publish('builtin.canvas', 'selection', {'path': 'a.canvas'});
    await deliver();
    expect(ext.openPaths, ['a.canvas']);

    // Same root again — documents stay.
    f.services.events.emit(const ProjectOpened(path: '/repo/a'));
    await deliver();
    expect(ext.openPaths, ['a.canvas']);

    // Different root — documents dropped.
    f.services.events.emit(const ProjectOpened(path: '/repo/b'));
    await deliver();
    expect(ext.openPaths, isEmpty);
  });

  test('deactivate cancels the subscription and disposes the tabs', () async {
    final ext = CanvasExtension();
    f.services.extensions.register(ext);
    await f.services.extensions.activate('builtin.canvas');
    await ext.deactivate();

    f.services.messages.publish('builtin.canvas', 'selection', {'path': 'a.canvas'});
    await deliver();
    expect(ext.openPaths, isEmpty);
  });
}
