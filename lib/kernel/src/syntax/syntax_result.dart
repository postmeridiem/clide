/// Pure syntax-highlight result types + the capture-role→theme-color map
/// (T-438 web fence, D-100). No `dart:ffi`, so it is shared by the FFI-backed
/// [TreeSitterService] impl and its web stub — both expose identical data types.
library;

import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:clide/kernel/src/theme/tokens.dart';

/// Loads grammar WASM bytes for [language] (e.g. "dart" → `dart.wasm`).
/// Throws on missing or unreadable assets.
typedef GrammarBytesLoader = Future<Uint8List> Function(String language);

/// Loads the highlight query (`.scm` source) for [language], or returns
/// null if no query is bundled for it.
typedef GrammarQueryLoader = Future<String?> Function(String language);

class SyntaxSpan {
  const SyntaxSpan({required this.start, required this.end, required this.role});

  final int start;
  final int end;
  final String role;
}

class SyntaxResult {
  const SyntaxResult(this.spans);
  final List<SyntaxSpan> spans;

  static const empty = SyntaxResult([]);
}

/// Map a tree-sitter capture [role] to a theme color.
Color syntaxColorForRole(String role, SurfaceTokens tokens) {
  return switch (role) {
    'keyword' || 'repeat' || 'conditional' || 'include' || 'exception' || 'operator' => tokens.syntaxKeyword,
    'type' || 'type.builtin' || 'constructor' => tokens.syntaxType,
    'string' || 'string.special' => tokens.syntaxString,
    'number' || 'float' || 'boolean' => tokens.syntaxNumber,
    'comment' => tokens.syntaxComment,
    'function' || 'function.builtin' || 'function.method' || 'method' => tokens.syntaxMethod,
    'punctuation.bracket' || 'punctuation.delimiter' || 'punctuation.special' => tokens.syntaxPunct,
    'variable' || 'variable.builtin' || 'variable.parameter' => tokens.globalForeground,
    'property' || 'field' => tokens.syntaxMethod,
    'constant' || 'constant.builtin' => tokens.syntaxNumber,
    'tag' || 'attribute' => tokens.syntaxKeyword,
    'namespace' || 'module' => tokens.syntaxType,
    'text.title' => tokens.syntaxKeyword,
    'text.literal' || 'text.reference' || 'text.uri' => tokens.syntaxString,
    'text.emphasis' || 'text.strong' => tokens.syntaxType,
    _ => tokens.globalForeground,
  };
}
