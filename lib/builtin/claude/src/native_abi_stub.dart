/// Web stub (T-438 web fence, D-100): no FFI ABI introspection on web. The
/// native dir name only matters for locating a dev-tree `clide` binary, which
/// doesn't exist on the web target — so a harmless default suffices.
library;

String currentNativeDirName() => 'linux-x64';
