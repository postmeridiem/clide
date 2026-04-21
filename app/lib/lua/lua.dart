/// Lua extension runtime boundary (Tier 6 impl; Tier 0 stubs only).
///
/// Third-party extensions run in a vendored `liblua` loaded via
/// `dart:ffi`, sandboxed to a narrow `clide.*` capability API, and
/// render via a declarative widget-intent DSL. The `LuaExtension`
/// adapter proxies to the Lua state so Lua extensions implement the
/// same `ClideExtension` contract as Dart built-ins.
library;

export 'src/adapter.dart';
export 'src/capability_api.dart';
export 'src/host.dart';
export 'src/render_intent.dart';
