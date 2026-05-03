library;

import 'dart:ffi';
import 'dart:io' show File, Platform;

import 'package:ffi/ffi.dart';

// -- Opaque handles ----------------------------------------------------------

final class TSParser extends Opaque {}

final class TSTree extends Opaque {}

final class TSQuery extends Opaque {}

final class TSQueryCursor extends Opaque {}

final class TSWasmStore extends Opaque {}

final class TSWasmEngine extends Opaque {}

// -- Structs -----------------------------------------------------------------

final class TSNode extends Struct {
  @Array(4)
  external Array<Uint32> context;
  external Pointer<Void> id;
  external Pointer<Void> tree;
}

final class TSQueryCapture extends Struct {
  external TSNode node;
  @Uint32()
  external int index;
}

final class TSQueryMatch extends Struct {
  @Uint32()
  external int id;
  @Uint16()
  external int patternIndex;
  @Uint16()
  external int captureCount;
  external Pointer<TSQueryCapture> captures;
}

final class TSWasmError extends Struct {
  @Int32()
  external int kind;
  external Pointer<Utf8> message;
}

// -- Native function typedefs ------------------------------------------------

// Parser
typedef _TsParserNew = Pointer<TSParser> Function();
typedef _TsParserDelete = Void Function(Pointer<TSParser>);
typedef _TsParserSetLanguage = Bool Function(Pointer<TSParser>, Pointer<Void>);
typedef _TsParserSetWasmStore = Void Function(Pointer<TSParser>, Pointer<TSWasmStore>);
typedef _TsParserParseString = Pointer<TSTree> Function(Pointer<TSParser>, Pointer<TSTree>, Pointer<Utf8>, Uint32);

// Tree
typedef _TsTreeDelete = Void Function(Pointer<TSTree>);
typedef _TsTreeRootNode = TSNode Function(Pointer<TSTree>);

// Node
typedef _TsNodeStartByte = Uint32 Function(TSNode);
typedef _TsNodeEndByte = Uint32 Function(TSNode);

// Query
typedef _TsQueryNew = Pointer<TSQuery> Function(Pointer<Void>, Pointer<Utf8>, Uint32, Pointer<Uint32>, Pointer<Int32>);
typedef _TsQueryDelete = Void Function(Pointer<TSQuery>);
typedef _TsQueryCaptureCount = Uint32 Function(Pointer<TSQuery>);
typedef _TsQueryCaptureNameForId = Pointer<Utf8> Function(Pointer<TSQuery>, Uint32, Pointer<Uint32>);

// Query cursor
typedef _TsQueryCursorNew = Pointer<TSQueryCursor> Function();
typedef _TsQueryCursorDelete = Void Function(Pointer<TSQueryCursor>);
typedef _TsQueryCursorExec = Void Function(Pointer<TSQueryCursor>, Pointer<TSQuery>, TSNode);
typedef _TsQueryCursorNextMatch = Bool Function(Pointer<TSQueryCursor>, Pointer<TSQueryMatch>);

// WASM store
typedef _TsWasmStoreNew = Pointer<TSWasmStore> Function(Pointer<TSWasmEngine>, Pointer<TSWasmError>);
typedef _TsWasmStoreDelete = Void Function(Pointer<TSWasmStore>);
typedef _TsWasmStoreLoadLanguage = Pointer<Void> Function(Pointer<TSWasmStore>, Pointer<Utf8>, Pointer<Uint8>, Uint32, Pointer<TSWasmError>);

// WASM engine (from wasmtime C API, re-exported by tree-sitter)
typedef _WasmEngineNew = Pointer<TSWasmEngine> Function();
typedef _WasmEngineDelete = Void Function(Pointer<TSWasmEngine>);

// -- Dart function typedefs --------------------------------------------------

typedef DTsParserNew = Pointer<TSParser> Function();
typedef DTsParserDelete = void Function(Pointer<TSParser>);
typedef DTsParserSetLanguage = bool Function(Pointer<TSParser>, Pointer<Void>);
typedef DTsParserSetWasmStore = void Function(Pointer<TSParser>, Pointer<TSWasmStore>);
typedef DTsParserParseString = Pointer<TSTree> Function(Pointer<TSParser>, Pointer<TSTree>, Pointer<Utf8>, int);

typedef DTsTreeDelete = void Function(Pointer<TSTree>);
typedef DTsTreeRootNode = TSNode Function(Pointer<TSTree>);

typedef DTsNodeStartByte = int Function(TSNode);
typedef DTsNodeEndByte = int Function(TSNode);

typedef DTsQueryNew = Pointer<TSQuery> Function(Pointer<Void>, Pointer<Utf8>, int, Pointer<Uint32>, Pointer<Int32>);
typedef DTsQueryDelete = void Function(Pointer<TSQuery>);
typedef DTsQueryCaptureCount = int Function(Pointer<TSQuery>);
typedef DTsQueryCaptureNameForId = Pointer<Utf8> Function(Pointer<TSQuery>, int, Pointer<Uint32>);

typedef DTsQueryCursorNew = Pointer<TSQueryCursor> Function();
typedef DTsQueryCursorDelete = void Function(Pointer<TSQueryCursor>);
typedef DTsQueryCursorExec = void Function(Pointer<TSQueryCursor>, Pointer<TSQuery>, TSNode);
typedef DTsQueryCursorNextMatch = bool Function(Pointer<TSQueryCursor>, Pointer<TSQueryMatch>);

typedef DTsWasmStoreNew = Pointer<TSWasmStore> Function(Pointer<TSWasmEngine>, Pointer<TSWasmError>);
typedef DTsWasmStoreDelete = void Function(Pointer<TSWasmStore>);
typedef DTsWasmStoreLoadLanguage = Pointer<Void> Function(Pointer<TSWasmStore>, Pointer<Utf8>, Pointer<Uint8>, int, Pointer<TSWasmError>);

typedef DWasmEngineNew = Pointer<TSWasmEngine> Function();
typedef DWasmEngineDelete = void Function(Pointer<TSWasmEngine>);

// -- Bindings ----------------------------------------------------------------

class TreeSitterLib {
  TreeSitterLib._(DynamicLibrary lib)
      : parserNew = lib.lookupFunction<_TsParserNew, DTsParserNew>('ts_parser_new'),
        parserDelete = lib.lookupFunction<_TsParserDelete, DTsParserDelete>('ts_parser_delete'),
        parserSetLanguage = lib.lookupFunction<_TsParserSetLanguage, DTsParserSetLanguage>('ts_parser_set_language'),
        parserSetWasmStore = lib.lookupFunction<_TsParserSetWasmStore, DTsParserSetWasmStore>('ts_parser_set_wasm_store'),
        parserParseString = lib.lookupFunction<_TsParserParseString, DTsParserParseString>('ts_parser_parse_string'),
        treeDelete = lib.lookupFunction<_TsTreeDelete, DTsTreeDelete>('ts_tree_delete'),
        treeRootNode = lib.lookupFunction<_TsTreeRootNode, DTsTreeRootNode>('ts_tree_root_node'),
        nodeStartByte = lib.lookupFunction<_TsNodeStartByte, DTsNodeStartByte>('ts_node_start_byte'),
        nodeEndByte = lib.lookupFunction<_TsNodeEndByte, DTsNodeEndByte>('ts_node_end_byte'),
        queryNew = lib.lookupFunction<_TsQueryNew, DTsQueryNew>('ts_query_new'),
        queryDelete = lib.lookupFunction<_TsQueryDelete, DTsQueryDelete>('ts_query_delete'),
        queryCaptureCount = lib.lookupFunction<_TsQueryCaptureCount, DTsQueryCaptureCount>('ts_query_capture_count'),
        queryCaptureNameForId = lib.lookupFunction<_TsQueryCaptureNameForId, DTsQueryCaptureNameForId>('ts_query_capture_name_for_id'),
        queryCursorNew = lib.lookupFunction<_TsQueryCursorNew, DTsQueryCursorNew>('ts_query_cursor_new'),
        queryCursorDelete = lib.lookupFunction<_TsQueryCursorDelete, DTsQueryCursorDelete>('ts_query_cursor_delete'),
        queryCursorExec = lib.lookupFunction<_TsQueryCursorExec, DTsQueryCursorExec>('ts_query_cursor_exec'),
        queryCursorNextMatch = lib.lookupFunction<_TsQueryCursorNextMatch, DTsQueryCursorNextMatch>('ts_query_cursor_next_match'),
        wasmStoreNew = lib.lookupFunction<_TsWasmStoreNew, DTsWasmStoreNew>('ts_wasm_store_new'),
        wasmStoreDelete = lib.lookupFunction<_TsWasmStoreDelete, DTsWasmStoreDelete>('ts_wasm_store_delete'),
        wasmStoreLoadLanguage = lib.lookupFunction<_TsWasmStoreLoadLanguage, DTsWasmStoreLoadLanguage>('ts_wasm_store_load_language'),
        wasmEngineNew = lib.lookupFunction<_WasmEngineNew, DWasmEngineNew>('wasm_engine_new'),
        wasmEngineDelete = lib.lookupFunction<_WasmEngineDelete, DWasmEngineDelete>('wasm_engine_delete');

  final DTsParserNew parserNew;
  final DTsParserDelete parserDelete;
  final DTsParserSetLanguage parserSetLanguage;
  final DTsParserSetWasmStore parserSetWasmStore;
  final DTsParserParseString parserParseString;
  final DTsTreeDelete treeDelete;
  final DTsTreeRootNode treeRootNode;
  final DTsNodeStartByte nodeStartByte;
  final DTsNodeEndByte nodeEndByte;
  final DTsQueryNew queryNew;
  final DTsQueryDelete queryDelete;
  final DTsQueryCaptureCount queryCaptureCount;
  final DTsQueryCaptureNameForId queryCaptureNameForId;
  final DTsQueryCursorNew queryCursorNew;
  final DTsQueryCursorDelete queryCursorDelete;
  final DTsQueryCursorExec queryCursorExec;
  final DTsQueryCursorNextMatch queryCursorNextMatch;
  final DTsWasmStoreNew wasmStoreNew;
  final DTsWasmStoreDelete wasmStoreDelete;
  final DTsWasmStoreLoadLanguage wasmStoreLoadLanguage;
  final DWasmEngineNew wasmEngineNew;
  final DWasmEngineDelete wasmEngineDelete;

  static TreeSitterLib? _instance;

  static TreeSitterLib? get instance => _instance;

  static bool init() {
    if (_instance != null) return true;
    final lib = _openLibrary();
    if (lib == null) return false;
    _instance = TreeSitterLib._(lib);
    return true;
  }

  static DynamicLibrary? _openLibrary() {
    final libName = Platform.isLinux
        ? 'libtree-sitter.so'
        : Platform.isMacOS
            ? 'libtree-sitter.dylib'
            : Platform.isWindows
                ? 'tree-sitter.dll'
                : null;
    if (libName == null) return null;

    // Try standard dlopen path first (works when lib is in bundle/lib/).
    try {
      return DynamicLibrary.open(libName);
    } catch (_) {}

    // Try next to executable.
    final exe = File(Platform.resolvedExecutable).parent.path;
    for (final dir in ['$exe/lib', exe]) {
      final path = '$dir/$libName';
      if (File(path).existsSync()) {
        try {
          return DynamicLibrary.open(path);
        } catch (_) {}
      }
    }
    return null;
  }
}
