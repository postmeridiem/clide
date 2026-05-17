/// Tests the graceful-fallback paths of `TreeSitterService` when the
/// native `libtree-sitter` library isn't dlopen-resolvable. In that
/// environment the service short-circuits every public method without
/// throwing — which is also how the running app behaves on platforms
/// where the library hasn't been bundled.
library;

import 'package:clide/kernel/src/syntax/tree_sitter_service.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/kernel_fixture.dart';

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

  group('TreeSitterService.colorForRole', () {
    late SurfaceTokens tokens;

    setUpAll(() async {
      final f = await KernelFixture.create();
      tokens = f.services.theme.current.surface;
      await f.dispose();
    });

    test('every keyword-flavoured role maps to syntaxKeyword', () {
      for (final role in ['keyword', 'repeat', 'conditional', 'include', 'exception', 'operator']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxKeyword, reason: role);
      }
    });

    test('type-flavoured roles map to syntaxType', () {
      for (final role in ['type', 'type.builtin', 'constructor']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxType, reason: role);
      }
    });

    test('string-flavoured roles map to syntaxString', () {
      for (final role in ['string', 'string.special']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxString, reason: role);
      }
    });

    test('number-flavoured roles map to syntaxNumber', () {
      for (final role in ['number', 'float', 'boolean']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxNumber, reason: role);
      }
    });

    test('comment maps to syntaxComment', () {
      expect(TreeSitterService.colorForRole('comment', tokens), tokens.syntaxComment);
    });

    test('function-flavoured roles map to syntaxMethod', () {
      for (final role in ['function', 'function.builtin', 'function.method', 'method']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxMethod, reason: role);
      }
    });

    test('punctuation roles map to syntaxPunct', () {
      for (final role in ['punctuation.bracket', 'punctuation.delimiter', 'punctuation.special']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxPunct, reason: role);
      }
    });

    test('variable roles fall back to globalForeground', () {
      for (final role in ['variable', 'variable.builtin', 'variable.parameter']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.globalForeground, reason: role);
      }
    });

    test('property / field share syntaxMethod with functions', () {
      for (final role in ['property', 'field']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxMethod, reason: role);
      }
    });

    test('constant roles share syntaxNumber with numbers', () {
      for (final role in ['constant', 'constant.builtin']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxNumber, reason: role);
      }
    });

    test('tag / attribute share syntaxKeyword', () {
      for (final role in ['tag', 'attribute']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxKeyword, reason: role);
      }
    });

    test('namespace / module share syntaxType', () {
      for (final role in ['namespace', 'module']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxType, reason: role);
      }
    });

    test('markdown text.* roles distribute across keyword / string / type tokens', () {
      expect(TreeSitterService.colorForRole('text.title', tokens), tokens.syntaxKeyword);
      for (final role in ['text.literal', 'text.reference', 'text.uri']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxString, reason: role);
      }
      for (final role in ['text.emphasis', 'text.strong']) {
        expect(TreeSitterService.colorForRole(role, tokens), tokens.syntaxType, reason: role);
      }
    });

    test('unknown roles fall through to globalForeground', () {
      expect(TreeSitterService.colorForRole('definitely-not-a-real-role', tokens), tokens.globalForeground);
      expect(TreeSitterService.colorForRole('', tokens), tokens.globalForeground);
    });
  });
}
