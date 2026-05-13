/// Tests the graceful-fallback paths of `TreeSitterService` when the
/// native `libtree-sitter` library isn't dlopen-resolvable. In that
/// environment the service short-circuits every public method without
/// throwing — which is also how the running app behaves on platforms
/// where the library hasn't been bundled.
library;

import 'package:clide/kernel/src/syntax/tree_sitter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TreeSitterService — fallback paths', () {
    final svc = TreeSitterService.shared;

    test('hasGrammar(path) returns false for an unknown extension', () async {
      expect(await svc.hasGrammar('foo.unknownextension'), isFalse);
    });

    test('hasGrammar(path) returns false when the library cannot load', () async {
      // 'foo.dart' resolves to grammar "dart", which still requires the
      // native library + asset to actually load. In the test runner the
      // native lib isn't on the dlopen search path, so _init() fails and
      // hasGrammar reports false.
      expect(await svc.hasGrammar('foo.dart'), isFalse);
    });

    test('languageFor(path) returns null when the language is unknown', () async {
      expect(await svc.languageFor('foo.unknownextension'), isNull);
    });

    test('languageFor(path) returns null when the library cannot load', () async {
      expect(await svc.languageFor('foo.dart'), isNull);
    });

    test('highlight returns an empty result for unknown extensions', () async {
      final r = await svc.highlight('foo.unknownextension', 'whatever');
      expect(r.spans, isEmpty);
    });

    test('highlight returns an empty result when the library cannot load', () async {
      final r = await svc.highlight('foo.dart', 'void main() {}');
      expect(r.spans, isEmpty);
    });

    test('loadedLanguages getter returns a list (may be empty)', () {
      // Just exercise the getter — the actual contents depend on the
      // environment.
      expect(svc.loadedLanguages, isA<List<String>>());
    });
  });

  group('SyntaxResult / SyntaxSpan', () {
    test('SyntaxResult.empty has no spans', () {
      expect(SyntaxResult.empty.spans, isEmpty);
    });

    test('SyntaxSpan stores start / end / role', () {
      const s = SyntaxSpan(start: 3, end: 7, role: 'keyword');
      expect(s.start, 3);
      expect(s.end, 7);
      expect(s.role, 'keyword');
    });
  });
}
