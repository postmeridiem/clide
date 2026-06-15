/// Desktop tree-sitter bootstrap (T-438 web fence, D-100): dlopen the vendored
/// libtree-sitter once at startup. The web build uses [tree_sitter_boot_stub.dart].
library;

import 'package:clide/kernel/src/syntax/tree_sitter_ffi.dart';

/// Initialize the tree-sitter library; returns false if it can't be loaded.
bool initTreeSitter() => TreeSitterLib.init();
