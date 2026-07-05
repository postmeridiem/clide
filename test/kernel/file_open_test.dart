/// openWorkspaceFile (T-51/T-187) — the single dispatch point for file
/// activations: `.md` → markdown reader, `.canvas` → canvas pane (T-322),
/// everything else → the editor via IPC. Also records recents.
library;

import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/kernel_fixture.dart';

void main() {
  late KernelFixture f;
  late List<Message> published;
  late List<Object?> editorOpens;

  setUp(() async {
    f = await KernelFixture.create();
    published = [];
    editorOpens = [];
    f.services.messages.subscribe().listen(published.add);
    f.ipc.stub('editor.open', (args) async {
      editorOpens.add(args['path']);
      return IpcResponse.ok(id: '1', data: const {});
    });
  });
  tearDown(() => f.dispose());

  Future<void> deliver() => Future<void>.delayed(Duration.zero);

  test('.md routes to the markdown reader via the bus', () async {
    openWorkspaceFile(f.services, 'docs/plan.md');
    await deliver();
    expect(published, hasLength(1));
    expect(published.single.publisher, 'builtin.markdown');
    expect(published.single.channel, 'selection');
    expect(published.single.data, {'path': 'docs/plan.md'});
    expect(editorOpens, isEmpty);
  });

  test('.canvas routes to the canvas pane via the bus (T-322)', () async {
    openWorkspaceFile(f.services, 'notes/board.canvas');
    await deliver();
    expect(published, hasLength(1));
    expect(published.single.publisher, 'builtin.canvas');
    expect(published.single.channel, 'selection');
    expect(published.single.data, {'path': 'notes/board.canvas'});
    expect(editorOpens, isEmpty);
  });

  test('extension match is case-insensitive', () async {
    openWorkspaceFile(f.services, 'BOARD.CANVAS');
    await deliver();
    expect(published.single.publisher, 'builtin.canvas');
  });

  test('everything else opens in the editor over IPC', () async {
    openWorkspaceFile(f.services, 'lib/main.dart');
    await deliver();
    expect(published, isEmpty);
    expect(editorOpens, ['lib/main.dart']);
  });

  test('records the open in recent files; empty path is a no-op', () async {
    openWorkspaceFile(f.services, 'notes/board.canvas');
    openWorkspaceFile(f.services, '');
    await deliver();
    expect(f.services.recentFiles.paths, ['notes/board.canvas']);
  });
}
