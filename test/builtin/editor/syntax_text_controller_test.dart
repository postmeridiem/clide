/// Tests SyntaxTextController — the editor's TextEditingController that
/// turns tree-sitter spans into styled TextSpans. A fake
/// TreeSitterService supplies canned spans so the byte→char mapping and
/// span-rendering logic can be exercised without the native grammar.
library;

import 'package:clide/builtin/editor/src/syntax_text_controller.dart';
import 'package:clide/kernel/kernel.dart';
import 'package:clide/kernel/src/syntax/tree_sitter_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/kernel_fixture.dart';
import '../../helpers/widget_harness.dart';

/// TreeSitterService stub returning canned spans (constructor does no
/// FFI work — `_init` is lazy and never reached here).
class _FakeSyntax extends TreeSitterService {
  _FakeSyntax(this.spans);
  final List<SyntaxSpan> spans;
  @override
  Future<SyntaxResult> highlight(String path, String source) async => SyntaxResult(spans);
}

/// Counts highlight invocations so a test can assert a same-path
/// updatePath doesn't kick off a redundant highlight.
class _CountingSyntax extends TreeSitterService {
  int calls = 0;
  @override
  Future<SyntaxResult> highlight(String path, String source) async {
    calls++;
    return const SyntaxResult([]);
  }
}

void main() {
  group('SyntaxTextController', () {
    late KernelFixture f;
    setUp(() async => f = await KernelFixture.create());
    tearDown(() => f.dispose());

    /// Pump a themed context, run [body] with a controller already
    /// given tokens from the active theme.
    Future<void> withController(
      WidgetTester tester,
      SyntaxTextController c,
      Future<void> Function(BuildContext ctx) body,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(harness(f, Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      })));
      c.tokens = ClideTheme.of(ctx).surface;
      await body(ctx);
    }

    testWidgets('renders highlighted spans as styled TextSpan children', (tester) async {
      final c = SyntaxTextController(
          syntax: _FakeSyntax(const [
        SyntaxSpan(start: 0, end: 5, role: 'keyword'), // "class"
        SyntaxSpan(start: 6, end: 9, role: 'type'), // "Foo"
      ]));
      await withController(tester, c, (ctx) async {
        c.text = 'class Foo {}';
        c.updatePath('a.dart');
        await tester.pumpAndSettle();
        final span = c.buildTextSpan(context: ctx, withComposing: false);
        expect(span.children, isNotNull);
        // keyword + gap + type + trailing → several children.
        expect(span.children!.length, greaterThan(2));
      });
    });

    testWidgets('maps byte offsets across multi-byte (surrogate) characters', (tester) async {
      // '😀' is a surrogate pair (4 UTF-8 bytes). A span after it must
      // still land on the right character offset.
      final c = SyntaxTextController(
          syntax: _FakeSyntax(const [
        SyntaxSpan(start: 5, end: 8, role: 'type'), // "Foo" after "😀 "
      ]));
      await withController(tester, c, (ctx) async {
        c.text = '😀 Foo';
        c.updatePath('a.dart');
        await tester.pumpAndSettle();
        final span = c.buildTextSpan(context: ctx, withComposing: false);
        expect(span.children, isNotNull);
        expect(span.toPlainText(), '😀 Foo');
      });
    });

    testWidgets('with no spans falls back to a plain TextSpan', (tester) async {
      final c = SyntaxTextController(syntax: _FakeSyntax(const []));
      await withController(tester, c, (ctx) async {
        c.text = 'plain text';
        final span = c.buildTextSpan(context: ctx, withComposing: false);
        expect(span.children, isNull);
        expect(span.text, 'plain text');
      });
    });

    testWidgets('updatePath to the same path is a no-op', (tester) async {
      final syntax = _CountingSyntax();
      final c = SyntaxTextController(syntax: syntax);
      await withController(tester, c, (ctx) async {
        c.text = 'x';
        c.updatePath('a.dart');
        await tester.pumpAndSettle();
        final first = syntax.calls;
        expect(first, greaterThan(0));
        c.updatePath('a.dart'); // same path → early return
        await tester.pumpAndSettle();
        expect(syntax.calls, first); // no new highlight request
      });
    });

    testWidgets('a path with no known grammar skips highlighting', (tester) async {
      final c = SyntaxTextController(syntax: _FakeSyntax(const [SyntaxSpan(start: 0, end: 1, role: 'x')]));
      await withController(tester, c, (ctx) async {
        c.text = 'data';
        c.updatePath('notes.unknownext');
        await tester.pumpAndSettle();
        final span = c.buildTextSpan(context: ctx, withComposing: false);
        // No grammar → no spans applied → plain text.
        expect(span.children, isNull);
        expect(span.text, 'data');
      });
    });
  });
}
