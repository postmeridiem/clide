# Open Questions — Extensions

Extension API shape, Lua runtime vendoring, manifest schema version.

---

### Q-008: Extension API shape — widgets, subcommands, both?
- **Status:** Open
- **Question:** Should extensions contribute widgets (panels, tabs, status-bar items), subcommands (CLI verbs), or both? Both is the obvious answer but has a cost in API surface that must be designed carefully to satisfy user/Claude parity ([D-006](architecture.md)).
- **Context:** CLAUDE.md flags this as "decide during Tier 6." `builtin.*` stubs today contribute widgets + commands + keybindings; the third-party Lua contract has to match.
- **Source:** CLAUDE.md "Open questions" footer.

### Q-009: Lua runtime vendoring
- **Status:** Open
- **Question:** Does the Lua supporter tool ([D-019](extensions.md#d-019-lua-runtime-as-ptyc-peer-supporter-tool)) bundle liblua source (build with the binary) or link system liblua (smaller binary, fragile ABI)?
- **Context:** `ptyc` has no deps; Lua is different — it's a whole VM. Bundling is the straightforward choice but locks a Lua version per clide release.
- **Source:** 2026-04-21 planning.

### Q-010: Extension manifest `schema_version:`
- **Status:** Open
- **Question:** What's the manifest schema-version scheme and bump policy? Coupled with [Q-005](questions-architecture.md#q-005-ipc-wire-format-stability) (IPC wire format) — both want a versioning story.
- **Context:** Today's manifests have no `schema_version:`. Adding one is cheap; the hard part is deciding when we bump.
- **Source:** 2026-04-21 planning.

---
