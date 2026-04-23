library;

import 'dart:convert' show utf8;
import 'dart:ffi';
import 'dart:ui' show Color;

import 'package:clide/kernel/src/syntax/language_map.dart';
import 'package:clide/kernel/src/syntax/tree_sitter_ffi.dart';
import 'package:clide/kernel/src/theme/tokens.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart' show rootBundle;

class SyntaxSpan {
  const SyntaxSpan({
    required this.start,
    required this.end,
    required this.role,
  });

  final int start;
  final int end;
  final String role;
}

class SyntaxResult {
  const SyntaxResult(this.spans);
  final List<SyntaxSpan> spans;

  static const empty = SyntaxResult([]);
}

class _LoadedGrammar {
  _LoadedGrammar({
    required this.language,
    required this.query,
    required this.captureNames,
  });

  final Pointer<Void> language;
  final Pointer<TSQuery> query;
  final List<String> captureNames;
}

class TreeSitterService {
  static final TreeSitterService shared = TreeSitterService._();
  TreeSitterService._();

  final Map<String, _LoadedGrammar> _grammars = {};
  final Set<String> _unavailable = {};

  Pointer<TSWasmStore>? _store;
  Pointer<TSParser>? _parser;
  Pointer<TSQueryCursor>? _cursor;

  bool _initDone = false;

  bool _init() {
    if (_initDone) return _parser != null;
    _initDone = true;

    final lib = TreeSitterLib.instance;
    if (lib == null) return false;

    final engine = lib.wasmEngineNew();
    if (engine == nullptr) return false;

    final error = calloc<TSWasmError>();
    _store = lib.wasmStoreNew(engine, error);
    lib.wasmEngineDelete(engine);

    if (_store == null || _store == nullptr) {
      calloc.free(error);
      return false;
    }
    calloc.free(error);

    _parser = lib.parserNew();
    if (_parser == null || _parser == nullptr) return false;
    lib.parserSetWasmStore(_parser!, _store!);

    _cursor = lib.queryCursorNew();
    return true;
  }

  Future<_LoadedGrammar?> _loadGrammar(String language) async {
    if (_unavailable.contains(language)) return null;
    final cached = _grammars[language];
    if (cached != null) return cached;

    if (!_init()) {
      _unavailable.add(language);
      return null;
    }

    final lib = TreeSitterLib.instance!;

    try {
      // Load grammar WASM bytes.
      final wasmData =
          await rootBundle.load('assets/grammars/$language.wasm');
      final wasmBytes = wasmData.buffer.asUint8List();

      // Load into WASM store.
      final nameNative = language.toNativeUtf8();
      final wasmNative = calloc<Uint8>(wasmBytes.length);
      wasmNative.asTypedList(wasmBytes.length).setAll(0, wasmBytes);
      final error = calloc<TSWasmError>();

      final lang = lib.wasmStoreLoadLanguage(
        _store!, nameNative.cast(), wasmNative, wasmBytes.length, error,
      );

      calloc.free(wasmNative);
      calloc.free(nameNative);

      if (lang == nullptr) {
        final msg = error.ref.message;
        if (msg != nullptr) calloc.free(msg);
        calloc.free(error);
        _unavailable.add(language);
        return null;
      }
      calloc.free(error);

      // Load highlight query.
      String? querySource;
      try {
        querySource =
            await rootBundle.loadString('assets/queries/$language.scm');
      } catch (_) {}

      Pointer<TSQuery> query = nullptr;
      List<String> captureNames = [];

      if (querySource != null) {
        final queryNative = querySource.toNativeUtf8();
        final queryLen = utf8.encode(querySource).length;
        final errorOffset = calloc<Uint32>();
        final errorType = calloc<Int32>();

        query = lib.queryNew(
          lang, queryNative.cast(), queryLen, errorOffset, errorType,
        );

        calloc.free(queryNative);
        calloc.free(errorOffset);
        calloc.free(errorType);

        if (query != nullptr) {
          final count = lib.queryCaptureCount(query);
          final lenOut = calloc<Uint32>();
          for (var i = 0; i < count; i++) {
            final namePtr = lib.queryCaptureNameForId(query, i, lenOut);
            final len = lenOut.value;
            captureNames.add(namePtr.cast<Utf8>().toDartString(length: len));
          }
          calloc.free(lenOut);
        }
      }

      final grammar = _LoadedGrammar(
        language: lang,
        query: query,
        captureNames: captureNames,
      );
      _grammars[language] = grammar;
      return grammar;
    } catch (_) {
      _unavailable.add(language);
      return null;
    }
  }

  Future<bool> hasGrammar(String path) async {
    final lang = grammarForPath(path);
    if (lang == null) return false;
    return (await _loadGrammar(lang)) != null;
  }

  Future<String?> languageFor(String path) async {
    final lang = grammarForPath(path);
    if (lang == null) return null;
    return (await _loadGrammar(lang)) != null ? lang : null;
  }

  List<String> get loadedLanguages => _grammars.keys.toList();

  Future<SyntaxResult> highlight(String path, String source) async {
    final lang = grammarForPath(path);
    if (lang == null) return SyntaxResult.empty;

    final grammar = await _loadGrammar(lang);
    if (grammar == null || grammar.query == nullptr) {
      return SyntaxResult.empty;
    }

    final lib = TreeSitterLib.instance!;
    final parser = _parser!;
    final cursor = _cursor!;

    // Set language on parser for this parse.
    lib.parserSetLanguage(parser, grammar.language);

    // Parse source.
    final sourceNative = source.toNativeUtf8();
    final sourceLen = utf8.encode(source).length;
    final tree = lib.parserParseString(
      parser, nullptr, sourceNative.cast(), sourceLen,
    );

    if (tree == nullptr) {
      calloc.free(sourceNative);
      return SyntaxResult.empty;
    }

    final root = lib.treeRootNode(tree);

    // Run highlight query.
    lib.queryCursorExec(cursor, grammar.query, root);

    final match = calloc<TSQueryMatch>();
    final spans = <SyntaxSpan>[];

    while (lib.queryCursorNextMatch(cursor, match)) {
      final m = match.ref;
      for (var i = 0; i < m.captureCount; i++) {
        final cap = m.captures[i];
        final captureIndex = cap.index;
        if (captureIndex < grammar.captureNames.length) {
          spans.add(SyntaxSpan(
            start: lib.nodeStartByte(cap.node),
            end: lib.nodeEndByte(cap.node),
            role: grammar.captureNames[captureIndex],
          ));
        }
      }
    }

    calloc.free(match);
    lib.treeDelete(tree);
    calloc.free(sourceNative);

    return SyntaxResult(spans);
  }

  void dispose() {
    final lib = TreeSitterLib.instance;
    if (lib == null) return;

    for (final grammar in _grammars.values) {
      if (grammar.query != nullptr) lib.queryDelete(grammar.query);
    }
    _grammars.clear();

    if (_cursor != null && _cursor != nullptr) lib.queryCursorDelete(_cursor!);
    // Parser and WASM store are cleaned up together — deleting the parser
    // does not delete the store, but the store owns the languages.
    if (_parser != null && _parser != nullptr) lib.parserDelete(_parser!);
    if (_store != null && _store != nullptr) lib.wasmStoreDelete(_store!);

    _parser = null;
    _store = null;
    _cursor = null;
    _unavailable.clear();
  }

  static Color colorForRole(String role, SurfaceTokens tokens) {
    return switch (role) {
      'keyword' || 'repeat' || 'conditional' || 'include' ||
      'exception' || 'operator' =>
        tokens.syntaxKeyword,
      'type' || 'type.builtin' || 'constructor' => tokens.syntaxType,
      'string' || 'string.special' => tokens.syntaxString,
      'number' || 'float' || 'boolean' => tokens.syntaxNumber,
      'comment' => tokens.syntaxComment,
      'function' || 'function.builtin' || 'function.method' ||
      'method' =>
        tokens.syntaxMethod,
      'punctuation.bracket' || 'punctuation.delimiter' ||
      'punctuation.special' =>
        tokens.syntaxPunct,
      'variable' || 'variable.builtin' || 'variable.parameter' =>
        tokens.globalForeground,
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
}
