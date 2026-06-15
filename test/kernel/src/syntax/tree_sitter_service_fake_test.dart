/// Fake-FFI tests for `TreeSitterService` — exercises every branch of
/// `_init`, `_loadGrammar`, `highlight`, and `dispose` by substituting
/// `TreeSitterLib.testing(...)` and in-memory grammar/query loaders, no
/// real `libtree-sitter.so` required.
library;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:clide/kernel/src/syntax/tree_sitter_ffi.dart';
// The FFI impl directly (not the facade): these tests inject a fake
// TreeSitterLib via the FFI-only constructor params (T-438).
import 'package:clide/kernel/src/syntax/tree_sitter_service_ffi.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fake addresses used to stand in for opaque handles. Never dereferenced —
  // the fake FFI surface just compares pointer identity.
  Pointer<TSWasmEngine> engineHandle() => Pointer<TSWasmEngine>.fromAddress(0x1000);
  Pointer<TSWasmStore> storeHandle() => Pointer<TSWasmStore>.fromAddress(0x2000);
  Pointer<TSParser> parserHandle() => Pointer<TSParser>.fromAddress(0x3000);
  Pointer<TSQueryCursor> cursorHandle() => Pointer<TSQueryCursor>.fromAddress(0x4000);
  Pointer<Void> languageHandle() => Pointer<Void>.fromAddress(0x5000);
  Pointer<TSQuery> queryHandle() => Pointer<TSQuery>.fromAddress(0x6000);
  Pointer<TSTree> treeHandle() => Pointer<TSTree>.fromAddress(0x7000);

  /// Builds a lib that succeeds through `_init` (engine + store + parser +
  /// cursor) and lets each test customize what happens afterwards.
  TreeSitterLib initOkLib({
    DTsWasmStoreLoadLanguage? wasmStoreLoadLanguage,
    DTsQueryNew? queryNew,
    DTsQueryCaptureCount? queryCaptureCount,
    DTsQueryCaptureNameForId? queryCaptureNameForId,
    DTsParserParseString? parserParseString,
    DTsTreeRootNode? treeRootNode,
    DTsQueryCursorNextMatch? queryCursorNextMatch,
    DTsNodeStartByte? nodeStartByte,
    DTsNodeEndByte? nodeEndByte,
    DTsQueryDelete? queryDelete,
    DTsParserDelete? parserDelete,
    DTsWasmStoreDelete? wasmStoreDelete,
    DTsQueryCursorDelete? queryCursorDelete,
    DTsParserSetLanguage? parserSetLanguage,
  }) {
    return TreeSitterLib.testing(
      wasmEngineNew: engineHandle,
      wasmEngineDelete: (_) {},
      wasmStoreNew: (_, _) => storeHandle(),
      parserNew: parserHandle,
      parserSetWasmStore: (_, _) {},
      queryCursorNew: cursorHandle,
      wasmStoreLoadLanguage: wasmStoreLoadLanguage,
      queryNew: queryNew,
      queryCaptureCount: queryCaptureCount,
      queryCaptureNameForId: queryCaptureNameForId,
      parserParseString: parserParseString,
      treeRootNode: treeRootNode,
      queryCursorNextMatch: queryCursorNextMatch,
      nodeStartByte: nodeStartByte,
      nodeEndByte: nodeEndByte,
      queryDelete: queryDelete,
      parserDelete: parserDelete,
      wasmStoreDelete: wasmStoreDelete,
      queryCursorDelete: queryCursorDelete,
      parserSetLanguage: parserSetLanguage ?? ((_, _) => true),
    );
  }

  Future<Uint8List> okBytes(String _) async => Uint8List.fromList(const [0, 1, 2, 3]);
  Future<String?> noQuery(String _) async => null;
  Future<String?> okQuery(String _) async => '(identifier) @keyword';

  group('TreeSitterService._init — FFI failure branches', () {
    test('wasmEngineNew returning nullptr → hasGrammar(.dart) is false', () async {
      final svc = TreeSitterService(lib: TreeSitterLib.testing(), grammarBytes: okBytes, grammarQuery: noQuery);
      expect(await svc.hasGrammar('foo.dart'), isFalse);
    });

    test('wasmStoreNew returning nullptr → hasGrammar is false', () async {
      final lib = TreeSitterLib.testing(
        wasmEngineNew: engineHandle,
        wasmEngineDelete: (_) {},
        // wasmStoreNew default → nullptr
      );
      final svc = TreeSitterService(lib: lib, grammarBytes: okBytes, grammarQuery: noQuery);
      expect(await svc.hasGrammar('foo.dart'), isFalse);
    });

    test('parserNew returning nullptr → hasGrammar is false', () async {
      final lib = TreeSitterLib.testing(
        wasmEngineNew: engineHandle,
        wasmEngineDelete: (_) {},
        wasmStoreNew: (_, _) => storeHandle(),
        // parserNew default → nullptr
      );
      final svc = TreeSitterService(lib: lib, grammarBytes: okBytes, grammarQuery: noQuery);
      expect(await svc.hasGrammar('foo.dart'), isFalse);
    });

    test('_init failure is cached — second call still false without re-trying', () async {
      var engineCalls = 0;
      final lib = TreeSitterLib.testing(
        wasmEngineNew: () {
          engineCalls++;
          return nullptr;
        },
      );
      final svc = TreeSitterService(lib: lib, grammarBytes: okBytes, grammarQuery: noQuery);
      expect(await svc.hasGrammar('foo.dart'), isFalse);
      expect(await svc.hasGrammar('foo.dart'), isFalse);
      // Second hasGrammar hits the _unavailable cache before _init runs again.
      expect(engineCalls, 1);
    });
  });

  group('TreeSitterService._loadGrammar — branches', () {
    test('grammarBytes throwing is caught → grammar marked unavailable', () async {
      final svc = TreeSitterService(
        lib: initOkLib(wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle()),
        grammarBytes: (_) async => throw StateError('bundle missing'),
        grammarQuery: noQuery,
      );
      expect(await svc.hasGrammar('foo.dart'), isFalse);
    });

    test('wasmStoreLoadLanguage returning nullptr → grammar marked unavailable', () async {
      final svc = TreeSitterService(lib: initOkLib(), grammarBytes: okBytes, grammarQuery: noQuery);
      expect(await svc.hasGrammar('foo.dart'), isFalse);
      // Once marked unavailable, languageFor also returns null.
      expect(await svc.languageFor('foo.dart'), isNull);
    });

    test('grammarQuery returning null → grammar loads with query=nullptr', () async {
      final svc = TreeSitterService(
        lib: initOkLib(wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle()),
        grammarBytes: okBytes,
        grammarQuery: noQuery,
      );
      // languageFor returns the language name when the grammar loaded — even
      // though there's no highlight query.
      expect(await svc.languageFor('foo.dart'), 'dart');
      // hasGrammar likewise returns true.
      expect(await svc.hasGrammar('foo.dart'), isTrue);
      // highlight returns empty because grammar.query is nullptr.
      final h = await svc.highlight('foo.dart', 'x');
      expect(h.spans, isEmpty);
    });

    test('grammarQuery loads + queryNew fails → grammar still cached with query=nullptr', () async {
      final svc = TreeSitterService(
        lib: initOkLib(
          wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle(),
          // queryNew default → nullptr; capture reflection block skipped.
        ),
        grammarBytes: okBytes,
        grammarQuery: okQuery,
      );
      expect(await svc.languageFor('foo.dart'), 'dart');
      expect((await svc.highlight('foo.dart', 'x')).spans, isEmpty);
    });

    test('grammarQuery loads + queryNew + captures reflected → loadedLanguages reports it', () async {
      // Allocate a static capture name buffer that the fake returns for every
      // capture id. Leaks for the duration of the test; not freed.
      final nameNative = 'keyword'.toNativeUtf8();
      final svc = TreeSitterService(
        lib: initOkLib(
          wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle(),
          queryNew: (_, _, _, _, _) => queryHandle(),
          queryCaptureCount: (_) => 1,
          queryCaptureNameForId: (_, _, lenOut) {
            lenOut.value = nameNative.length;
            return nameNative;
          },
        ),
        grammarBytes: okBytes,
        grammarQuery: okQuery,
      );
      expect(await svc.languageFor('foo.dart'), 'dart');
      expect(svc.loadedLanguages, contains('dart'));
    });

    test('a second call for the same language returns the cached grammar', () async {
      var byteLoads = 0;
      final svc = TreeSitterService(
        lib: initOkLib(wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle()),
        grammarBytes: (lang) async {
          byteLoads++;
          return Uint8List.fromList(const [0, 1, 2]);
        },
        grammarQuery: noQuery,
      );
      await svc.languageFor('foo.dart');
      await svc.languageFor('foo.dart');
      expect(byteLoads, 1);
    });

    test('once marked unavailable, repeat calls do not re-attempt the bundle load', () async {
      var byteLoads = 0;
      final svc = TreeSitterService(
        lib: initOkLib(), // wasmStoreLoadLanguage default → nullptr
        grammarBytes: (lang) async {
          byteLoads++;
          return Uint8List.fromList(const [0]);
        },
        grammarQuery: noQuery,
      );
      expect(await svc.hasGrammar('foo.dart'), isFalse);
      expect(await svc.hasGrammar('foo.dart'), isFalse);
      expect(byteLoads, 1);
    });
  });

  group('TreeSitterService.highlight — parse + cursor loop', () {
    test('parserParseString returning nullptr → empty spans', () async {
      final svc = TreeSitterService(
        lib: initOkLib(
          wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle(),
          queryNew: (_, _, _, _, _) => queryHandle(),
          // parserParseString default → nullptr
        ),
        grammarBytes: okBytes,
        grammarQuery: okQuery,
      );
      final h = await svc.highlight('foo.dart', 'whatever');
      expect(h.spans, isEmpty);
    });

    test('cursor produces a match with one capture → SyntaxSpan emitted', () async {
      // Build a leaky TSNode for the fake to return — start/end byte
      // closures decide the span coordinates.
      final rootNode = calloc<TSNode>();
      final capNode = calloc<TSNode>();
      final captures = calloc<TSQueryCapture>(1);
      captures[0].index = 0;
      captures[0].node = capNode.ref;
      final nameNative = 'keyword'.toNativeUtf8();

      var matchCalls = 0;
      final svc = TreeSitterService(
        lib: initOkLib(
          wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle(),
          queryNew: (_, _, _, _, _) => queryHandle(),
          queryCaptureCount: (_) => 1,
          queryCaptureNameForId: (_, _, lenOut) {
            lenOut.value = nameNative.length;
            return nameNative;
          },
          parserParseString: (_, _, _, _) => treeHandle(),
          treeRootNode: (_) => rootNode.ref,
          queryCursorNextMatch: (_, match) {
            if (matchCalls > 0) return false;
            matchCalls++;
            match.ref.captureCount = 1;
            match.ref.captures = captures;
            return true;
          },
          nodeStartByte: (_) => 4,
          nodeEndByte: (_) => 11,
        ),
        grammarBytes: okBytes,
        grammarQuery: okQuery,
      );

      final h = await svc.highlight('foo.dart', 'void hello();');
      expect(h.spans, hasLength(1));
      expect(h.spans.single.start, 4);
      expect(h.spans.single.end, 11);
      expect(h.spans.single.role, 'keyword');
    });

    test('captures with an out-of-range index are skipped', () async {
      final rootNode = calloc<TSNode>();
      final capNode = calloc<TSNode>();
      final captures = calloc<TSQueryCapture>(1);
      captures[0].index = 99; // way beyond captureNames.length=1
      captures[0].node = capNode.ref;
      final nameNative = 'keyword'.toNativeUtf8();

      var matchCalls = 0;
      final svc = TreeSitterService(
        lib: initOkLib(
          wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle(),
          queryNew: (_, _, _, _, _) => queryHandle(),
          queryCaptureCount: (_) => 1,
          queryCaptureNameForId: (_, _, lenOut) {
            lenOut.value = nameNative.length;
            return nameNative;
          },
          parserParseString: (_, _, _, _) => treeHandle(),
          treeRootNode: (_) => rootNode.ref,
          queryCursorNextMatch: (_, match) {
            if (matchCalls > 0) return false;
            matchCalls++;
            match.ref.captureCount = 1;
            match.ref.captures = captures;
            return true;
          },
        ),
        grammarBytes: okBytes,
        grammarQuery: okQuery,
      );

      final h = await svc.highlight('foo.dart', 'void main() {}');
      expect(h.spans, isEmpty);
    });
  });

  group('TreeSitterService.dispose', () {
    test('dispose calls queryDelete + parserDelete + wasmStoreDelete + queryCursorDelete', () async {
      var queryDeletes = 0;
      var parserDeletes = 0;
      var storeDeletes = 0;
      var cursorDeletes = 0;
      final svc = TreeSitterService(
        lib: initOkLib(
          wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle(),
          queryNew: (_, _, _, _, _) => queryHandle(),
          queryDelete: (_) => queryDeletes++,
          parserDelete: (_) => parserDeletes++,
          wasmStoreDelete: (_) => storeDeletes++,
          queryCursorDelete: (_) => cursorDeletes++,
        ),
        grammarBytes: okBytes,
        grammarQuery: okQuery,
      );

      // Load one grammar so dispose has something to walk.
      await svc.hasGrammar('foo.dart');
      svc.dispose();

      expect(queryDeletes, 1);
      expect(parserDeletes, 1);
      expect(storeDeletes, 1);
      expect(cursorDeletes, 1);
    });

    test('dispose is a no-op when no lib was ever injected and TreeSitterLib.instance is null', () {
      // No injected lib + no dlopen'd native lib in the test runner.
      final svc = TreeSitterService(grammarBytes: okBytes, grammarQuery: noQuery);
      svc.dispose(); // must not throw
    });

    test('resetForTests re-arms _init for the next call', () async {
      var engineCalls = 0;
      final lib = TreeSitterLib.testing(
        wasmEngineNew: () {
          engineCalls++;
          return engineHandle();
        },
        wasmEngineDelete: (_) {},
        wasmStoreNew: (_, _) => storeHandle(),
        parserNew: parserHandle,
        parserSetWasmStore: (_, _) {},
        queryCursorNew: cursorHandle,
        wasmStoreLoadLanguage: (_, _, _, _, _) => languageHandle(),
      );
      final svc = TreeSitterService(lib: lib, grammarBytes: okBytes, grammarQuery: noQuery);
      await svc.hasGrammar('foo.dart');
      expect(engineCalls, 1);
      svc.resetForTests();
      await svc.hasGrammar('bar.dart');
      expect(engineCalls, 2);
    });
  });
}
