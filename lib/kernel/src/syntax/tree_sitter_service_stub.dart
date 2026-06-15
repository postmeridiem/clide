/// Web stub for [TreeSitterService] (T-438 web fence, D-100): no tree-sitter
/// FFI on web, so highlighting is a no-op — every query returns no spans and
/// the editor / code block render plain text. Mirrors the FFI impl's public
/// API (and re-exports the shared result types) so the facade is transparent.
library;

import 'dart:ui' show Color;

import 'package:clide/kernel/src/syntax/syntax_result.dart';
import 'package:clide/kernel/src/theme/tokens.dart';

export 'package:clide/kernel/src/syntax/syntax_result.dart';

class TreeSitterService {
  static final TreeSitterService shared = TreeSitterService();

  TreeSitterService();

  Future<bool> hasGrammar(String path) async => false;
  Future<String?> languageFor(String path) async => null;
  List<String> get loadedLanguages => const [];
  Future<SyntaxResult> highlight(String path, String source) async => SyntaxResult.empty;
  void dispose() {}
  void resetForTests() {}

  static Color colorForRole(String role, SurfaceTokens tokens) => syntaxColorForRole(role, tokens);
}
