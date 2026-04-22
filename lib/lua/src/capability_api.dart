/// Tier-0 stub for the sandboxed `clide.*` table exposed to third-party
/// Lua extensions.
///
/// The surface is deliberately narrow: `clide.ipc.request`,
/// `clide.events.on`, `clide.log`, `clide.contribute`, and scoped
/// kernel-service getters that mirror `ClideExtensionContext`. Lua
/// code has no `io`, no `os.execute`, no `package.loadlib`, no `debug`
/// — those are removed from the global state at sandbox init.
///
/// Full binding table lands with the Lua runtime at Tier 6.
class CapabilityApi {
  const CapabilityApi();
}
