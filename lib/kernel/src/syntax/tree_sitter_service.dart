/// Platform facade for the tree-sitter highlighter (T-438 web fence, D-100):
/// the FFI-backed [TreeSitterService] on desktop, a no-op stub on web. Both
/// re-export the shared [SyntaxSpan]/[SyntaxResult] types and `colorForRole`,
/// so consumers import this file unchanged.
library;

export 'tree_sitter_service_stub.dart' if (dart.library.ffi) 'tree_sitter_service_ffi.dart';
