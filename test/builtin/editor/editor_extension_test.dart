/// T-197: EditorExtension opens the workspace editor split when a buffer
/// opens and collapses it when the last one closes.
///
/// The workspace renders its editor split off `arrangement.editorOpen`
/// (not the active tab), so the extension must flip that flag — otherwise
/// `editor.open` opens the buffer daemon-side but nothing appears over
/// the Claude pane.
library;

import 'dart:convert';
import 'dart:io';

import 'package:clide/builtin/editor/src/extension.dart';
import 'package:clide/builtin/editor/src/open_files_store.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/src/ipc/envelope.dart';
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
    await pumpEventQueue();
    expect(f.services.arrangement.editorOpen, isTrue);
  });

  test('editor.active-changed with a buffer keeps the split open', () async {
    emitEditor('editor.active-changed', id: 'b_2');
    await pumpEventQueue();
    expect(f.services.arrangement.editorOpen, isTrue);
  });

  test('editor.active-changed with a null id collapses the split', () async {
    emitEditor('editor.opened', id: 'b_1');
    await pumpEventQueue();
    expect(f.services.arrangement.editorOpen, isTrue);

    emitEditor('editor.active-changed', id: null);
    await pumpEventQueue();
    expect(f.services.arrangement.editorOpen, isFalse);
  });

  test('a non-editor event does not open the split', () async {
    f.services.events.emit(DaemonEvent(subsystem: 'git', kind: 'changed', data: const {}, ts: DateTime.now().toUtc()));
    await pumpEventQueue();
    expect(f.services.arrangement.editorOpen, isFalse);
  });

  // D-114: open files are remembered per workspace and reopened with it.
  group('remembering open files', () {
    late String root;
    setUp(() {
      root = f.tempDir.path;
      File('$root/a.dart').writeAsStringSync('a');
      File('$root/b.dart').writeAsStringSync('b');
    });

    void emitPath(String kind, {String? id, String? path}) =>
        f.services.events.emit(DaemonEvent(subsystem: 'editor', kind: kind, data: {'id': id, 'path': path}, ts: DateTime.now().toUtc()));

    Map<String, Object?> saved() => jsonDecode(f.services.settings.get<String>(OpenFilesStore.keyFor(root))!) as Map<String, Object?>;

    test('what is open, which is active, and whether the split shows', () async {
      f.services.events.emit(ProjectOpened(path: root));
      await pumpEventQueue();
      emitPath('editor.opened', id: 'b_1', path: 'a.dart');
      emitPath('editor.opened', id: 'b_2', path: 'b.dart');
      emitPath('editor.active-changed', id: 'b_1', path: 'a.dart');
      await pumpEventQueue();
      expect(saved(), {
        'files': ['a.dart', 'b.dart'],
        'active': 'a.dart',
        'visible': true,
      });

      emitPath('editor.closed', id: 'b_2', path: 'b.dart');
      await pumpEventQueue();
      expect(saved()['files'], ['a.dart']);
    });

    test('reopens them when the workspace opens — skipping deleted files, quietly', () async {
      await f.services.settings.set<String>(
        OpenFilesStore.keyFor(root),
        jsonEncode({
          'files': ['a.dart', 'gone.dart', 'b.dart'],
          'active': 'b.dart',
          'visible': true,
        }),
      );
      final opened = <String>[];
      String? activated;
      var n = 0;
      f.ipc.stub('editor.open', (args) async {
        final path = args['path']! as String;
        opened.add(path);
        final id = 'b_${++n}';
        emitPath('editor.opened', id: id, path: path);
        return IpcResponse.ok(id: '', data: {'id': id, 'path': path});
      });
      f.ipc.stub('editor.activate', (args) async {
        activated = args['id'] as String?;
        return IpcResponse.ok(id: '');
      });
      f.services.panels.activateTab(Slots.workspace, 'editor.active');
      f.services.panels.activateTab(Slots.workspace, f.services.panels.tabsFor(Slots.workspace).first.id);
      final tabBefore = f.services.panels.activeTabIn(Slots.workspace);

      f.services.events.emit(ProjectOpened(path: root));
      await pumpEventQueue();

      expect(opened, ['a.dart', 'b.dart']);
      expect(activated, 'b_2', reason: 'the file that was active is active again');
      expect(f.services.arrangement.editorOpen, isTrue, reason: 'the split was showing');
      expect(f.services.panels.activeTabIn(Slots.workspace), tabBefore, reason: 'restoring does not pull the editor to the front');
    });

    test('a split that was hidden stays hidden', () async {
      await f.services.settings.set<String>(
        OpenFilesStore.keyFor(root),
        jsonEncode({
          'files': ['a.dart'],
          'visible': false,
        }),
      );
      f.ipc.stub('editor.open', (args) async {
        emitPath('editor.opened', id: 'b_1', path: 'a.dart');
        return IpcResponse.ok(id: '', data: const {'id': 'b_1'});
      });
      f.services.events.emit(ProjectOpened(path: root));
      await pumpEventQueue();
      expect(f.services.arrangement.editorOpen, isFalse);
    });
  });

  test('after deactivate, editor events no longer open the split', () async {
    await f.services.extensions.deactivate('builtin.editor');
    emitEditor('editor.opened', id: 'b_9');
    await pumpEventQueue();
    expect(f.services.arrangement.editorOpen, isFalse);
  });
}
