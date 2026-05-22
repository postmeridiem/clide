/// Widget tests for the multi-tab editor view: a tab per open buffer
/// (filename + dirty marker), the empty-state hint, and tab taps
/// routing to `editor.activate`. Buffer-list logic itself is covered
/// in editor_controller_test.dart.
library;

import 'package:clide/builtin/editor/src/editor_view.dart';
import 'package:clide/clide.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

IpcResponse _ok(Map<String, Object?> data) => IpcResponse.ok(id: '', data: data);

Map<String, Object?> _buf(String id, String path, {bool dirty = false}) => {'id': id, 'path': path, 'dirty': dirty};

Map<String, Object?> _read(String id, String path) => {
      'id': id,
      'path': path,
      'content': 'content of $path',
      'selection': {'start': 0, 'end': 0},
      'dirty': false,
    };

void main() {
  group('EditorView tabs', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    void stubBuffers(List<Map<String, Object?>> buffers, {String? active}) {
      f.ipc.stub('editor.list', (_) async => _ok({'buffers': buffers}));
      f.ipc.stub(
          'editor.active',
          (_) async => active == null
              ? _ok(const {})
              : _ok({
                  'active': {'id': active}
                }));
      f.ipc.stub('editor.read', (a) async {
        final id = a['id'] as String;
        final b = buffers.firstWhere((b) => b['id'] == id);
        return _ok(_read(id, b['path'] as String));
      });
    }

    testWidgets('renders one tab per open buffer, by filename', (tester) async {
      stubBuffers([_buf('b_1', 'lib/a.dart'), _buf('b_2', 'src/b.dart')], active: 'b_1');
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();
      expect(find.text('a.dart'), findsOneWidget);
      expect(find.text('b.dart'), findsOneWidget);
    });

    testWidgets('a dirty buffer carries a marker in its tab title', (tester) async {
      stubBuffers([_buf('b_1', 'lib/a.dart', dirty: true)], active: 'b_1');
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();
      expect(find.text('a.dart •'), findsOneWidget);
    });

    testWidgets('no open buffers shows the open-a-file hint', (tester) async {
      stubBuffers(const [], active: null);
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();
      expect(find.text('Open a file to begin editing.'), findsOneWidget);
    });

    testWidgets('tapping an inactive tab routes to editor.activate', (tester) async {
      stubBuffers([_buf('b_1', 'lib/a.dart'), _buf('b_2', 'src/b.dart')], active: 'b_1');
      String? activated;
      f.ipc.stub('editor.activate', (a) async {
        activated = a['id'] as String?;
        return _ok({'active': a['id']});
      });
      await tester.pumpWidget(harness(f, const EditorView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('b.dart'));
      await tester.pumpAndSettle();

      expect(activated, 'b_2');
    });
  });
}
