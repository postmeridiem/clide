/// Widget tests for the .md routing fix in FileTreeView (T-187).
///
/// Clicking a .md file must publish ('builtin.markdown', 'selection', {path})
/// onto the kernel MessageBus rather than calling editor.open.  Non-.md files
/// must still route to editor.open.  Both the tree-row path (_FileRow) and the
/// filtered-row path (_FilteredFileRow) are covered.
library;

import 'package:clide/builtin/files/src/file_tree_view.dart';
import 'package:clide/clide.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

/// Stub the minimum IPC calls that FileTreeController.load() needs.
///
/// The [root] entry list populates the workspace root directory so the tree
/// renders at least one file row.
void _stubTree(
  KernelFixture f, {
  required String rootPath,
  required List<Map<String, Object?>> entries,
}) {
  f.ipc.stub('files.root', (_) async => _ok({'path': rootPath}));
  f.ipc.stub('files.watch', (_) async => _ok(const {}));
  f.ipc.stub('files.ls', (args) async => _ok({'entries': entries}));
}

Map<String, Object?> _file(String name, String path) => {
      'name': name,
      'path': path,
      'isDirectory': false,
      'isSymlink': false,
      'sizeBytes': 0,
      'modifiedMs': 0,
    };

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late KernelFixture f;
  setUp(() async => f = await KernelFixture.create());
  tearDown(() => f.dispose());

  group('FileTreeView .md routing (T-187)', () {
    testWidgets('clicking a .md file publishes to builtin.markdown selection (tree row)', (tester) async {
      const mdPath = 'docs/README.md';
      _stubTree(f, rootPath: '/repo', entries: [_file('README.md', mdPath)]);

      final published = <Message>[];
      final sub = f.services.messages.subscribe(publisher: 'builtin.markdown', channel: 'selection').listen(published.add);
      addTearDown(sub.cancel);

      await tester.pumpWidget(harness(f, const FileTreeView()));
      await pumpAsync(tester);

      // The root node is auto-expanded; the file row should be visible.
      final rowFinder = find.text('README.md');
      expect(rowFinder, findsOneWidget);

      await tester.tap(rowFinder);
      await tester.pump();
      // Broadcast-stream events deliver asynchronously.
      await pumpAsync(tester);

      expect(published, hasLength(1));
      expect(published.first.data['path'], mdPath);
    });

    testWidgets('clicking a non-.md file calls editor.open, not the markdown bus (tree row)', (tester) async {
      const dartPath = 'lib/main.dart';
      _stubTree(f, rootPath: '/repo', entries: [_file('main.dart', dartPath)]);

      final published = <Message>[];
      final sub = f.services.messages.subscribe(publisher: 'builtin.markdown', channel: 'selection').listen(published.add);
      addTearDown(sub.cancel);

      final opened = <String>[];
      f.ipc.stub('editor.open', (args) async {
        opened.add(args['path'] as String? ?? '');
        return _ok(const {});
      });

      await tester.pumpWidget(harness(f, const FileTreeView()));
      await pumpAsync(tester);

      await tester.tap(find.text('main.dart'));
      await tester.pump();
      await pumpAsync(tester);

      // markdown bus must NOT have been published
      expect(published, isEmpty);
      // editor.open must have been called
      expect(opened, hasLength(1));
      expect(opened.first, dartPath);
    });

    testWidgets('clicking a .md in the filtered view publishes to builtin.markdown selection', (tester) async {
      const mdPath = 'governance/decisions/architecture.md';
      _stubTree(
        f,
        rootPath: '/repo',
        entries: [
          _file('architecture.md', mdPath),
          _file('tooling.md', 'governance/decisions/tooling.md'),
        ],
      );

      final published = <Message>[];
      final sub = f.services.messages.subscribe(publisher: 'builtin.markdown', channel: 'selection').listen(published.add);
      addTearDown(sub.cancel);

      await tester.pumpWidget(harness(f, const FileTreeView()));
      await pumpAsync(tester);

      // Type in the filter box to switch to the filtered view.
      final filterBox = find.byWidgetPredicate((w) => w is EditableText);
      await tester.enterText(filterBox.first, 'architecture');
      await tester.pump(const Duration(milliseconds: 250)); // past ClideFilterBox's 200ms debounce
      await tester.pump();

      await tester.tap(find.text(mdPath));
      await tester.pump();
      await pumpAsync(tester);

      expect(published, hasLength(1));
      expect(published.first.data['path'], mdPath);
    });

    testWidgets('clicking a non-.md in the filtered view calls editor.open', (tester) async {
      const dartPath = 'lib/app.dart';
      _stubTree(f, rootPath: '/repo', entries: [_file('app.dart', dartPath)]);

      final published = <Message>[];
      final sub = f.services.messages.subscribe(publisher: 'builtin.markdown', channel: 'selection').listen(published.add);
      addTearDown(sub.cancel);

      final opened = <String>[];
      f.ipc.stub('editor.open', (args) async {
        opened.add(args['path'] as String? ?? '');
        return _ok(const {});
      });

      await tester.pumpWidget(harness(f, const FileTreeView()));
      await pumpAsync(tester);

      final filterBox = find.byWidgetPredicate((w) => w is EditableText);
      await tester.enterText(filterBox.first, 'app');
      await tester.pump(const Duration(milliseconds: 250)); // past ClideFilterBox's 200ms debounce
      await tester.pump();

      await tester.tap(find.text(dartPath));
      await tester.pump();
      await pumpAsync(tester);

      expect(published, isEmpty);
      expect(opened, hasLength(1));
      expect(opened.first, dartPath);
    });
  });
}
