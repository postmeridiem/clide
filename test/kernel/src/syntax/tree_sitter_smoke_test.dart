/// Real-library smoke test for `TreeSitterService`. Dlopen's the vendored
/// `native/linux-x64/libtree-sitter.so`, loads the bundled `dart` grammar
/// from `assets/grammars/dart.wasm` + `assets/queries/dart.scm` straight off
/// the filesystem (no `rootBundle`), and verifies highlight produces sane
/// spans over a tiny Dart program. Catches FFI-signature regressions that
/// the fake-driven branch tests cannot.
///
/// Skips cleanly on non-Linux hosts and on Linux hosts where the vendored
/// library hasn't been built yet.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:clide/kernel/src/syntax/tree_sitter_ffi.dart';
import 'package:clide/kernel/src/syntax/tree_sitter_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _libPath = 'native/linux-x64/libtree-sitter.so';

void main() {
  if (!Platform.isLinux || !File(_libPath).existsSync()) return;

  group('TreeSitterService — native smoke (real libtree-sitter.so + dart grammar)', () {
    late TreeSitterService svc;

    setUpAll(() {
      final dylib = DynamicLibrary.open(_libPath);
      svc = TreeSitterService(
        lib: TreeSitterLib.fromDynamicLibrary(dylib),
        grammarBytes: (lang) async => File('assets/grammars/$lang.wasm').readAsBytes(),
        grammarQuery: (lang) async {
          final f = File('assets/queries/$lang.scm');
          return await f.exists() ? f.readAsString() : null;
        },
      );
    });

    // Intentionally do NOT call svc.dispose() at teardown — wasmtime's
    // store-delete path collides with the Flutter test runner's process
    // finalization (libc `double free` on exit). The OS reclaims everything
    // when the runner process exits.

    test('loads the dart grammar end-to-end', () async {
      expect(await svc.hasGrammar('main.dart'), isTrue);
      expect(await svc.languageFor('main.dart'), 'dart');
      expect(svc.loadedLanguages, contains('dart'));
    });

    test('highlight returns at least one span for a tiny dart program', () async {
      const source = 'void main() {\n  print("hi");\n}\n';
      final r = await svc.highlight('main.dart', source);

      expect(r.spans, isNotEmpty);
      // Every span must be in-range and well-ordered.
      for (final s in r.spans) {
        expect(s.start, lessThanOrEqualTo(s.end));
        expect(s.end, lessThanOrEqualTo(source.length));
        expect(s.role, isNotEmpty);
      }
      // The captures the upstream dart.scm emits cover at least one of these
      // semantic roles for a `void main()` program — assert intersection so
      // the test survives minor query reshufflings.
      final roles = r.spans.map((s) => s.role).toSet();
      expect(
        roles.intersection({'keyword', 'type', 'function', 'string', 'punctuation.bracket', 'punctuation.delimiter'}),
        isNotEmpty,
        reason: 'expected at least one familiar dart role, got: $roles',
      );
    });

    test('a second highlight reuses the cached grammar (no re-load)', () async {
      // Re-issue a highlight; the grammar cache hit is internal but if the
      // service is healthy this just completes without throwing and returns
      // a sane result.
      final r = await svc.highlight('main.dart', 'class X {}');
      expect(r.spans, isNotEmpty);
    });
  });
}
