/// Tier-0 stub. The real implementation loads a vendored liblua via
/// `dart:ffi` and exposes a `LuaState` handle that [LuaExtension] uses
/// to run script callbacks. Lands at Tier 6.
class LuaHost {
  LuaHost._();

  /// Boot the vendored liblua. Throws until Tier 6.
  static Future<LuaHost> start() async {
    throw UnsupportedError(
        'Lua runtime lands at Tier 6 (supporter tool sibling of ptyc).');
  }

  Future<void> dispose() async {}
}
