# Open Questions — Process + Tooling

Editor tab, tree-sitter, icon set, theme hot-reload, kernel DB access.

Tooling-domain questions currently live here too. Split into
`questions-tooling.md` if this file outgrows ~350 lines.

---

### Q-015: Editor tab — full LSP vs tree-sitter-only highlight
- **Status:** Open
- **Question:** Tier 2's editor tab: do we integrate a full LSP story (analyzer server + hovers + completions + diagnostics) or ship tree-sitter-only syntax highlighting and defer LSP to Tier 6?
- **Context:** Full LSP is a large subsystem; tree-sitter is a weekend. User is a heavy LSP user in other IDEs — missing it hurts. CLAUDE.md flags this as "decide during Tier 2."
- **Source:** CLAUDE.md "Open questions" footer.

### Q-016: `tree-sitter-dart` grammar maintenance
- **Status:** Open
- **Question:** `UserNobody14/tree-sitter-dart` is archived. `nielsenko/tree-sitter-dart` is the maintained fork. Do we pin `nielsenko/`, mirror it in-repo, or lean on the Dart analyzer's own semantic output and skip tree-sitter for Dart?
- **Context:** If tree-sitter is the Tier-2 answer ([Q-015](#q-015-editor-tab-full-lsp-vs-tree-sitter-only)), grammar sourcing matters.
- **Source:** 2026-04-21 planning.

### Q-017: Icon set growth
- **Status:** Open
- **Question:** Hand-drawn `CustomPainter` catalogue (total control, pixel-perfect on every theme, slow to grow) vs SVG + parser (faster to grow, one more dep, theming is harder)?
- **Context:** We rejected Nerd-font glyphs ([R-006](rejected.md#r-006-nerd-font-glyph-icons)); something has to fill the gap.
- **Source:** 2026-04-21 planning.

### Q-018: Theme hot-reload in release builds
- **Status:** Open
- **Question:** The theme picker supports live-reloading a YAML during development. Does the same path stay open in release builds (user tweaks `~/.config/clide/themes/foo.yaml` and the app re-reads on focus) or is release-build theming restricted to built-in + settings-UI-installed themes?
- **Context:** Hot-reload is powerful for theme authoring but opens a file-watch + re-parse path in release code.
- **Source:** 2026-04-21 planning.

### Q-019: (withdrawn)
- **Status:** Resolved → n/a
- **Note:** Earlier floated as "ticket markdown mirror vs SQLite" — no longer a split question. Markdown mirror is tracked in [Q-022](questions-architecture.md#q-022-ticket-persistence-strategy); SQLite is the current stopgap per [D-040](process.md#d-040-python-stopgap-under-toolsscriptsplan).

### Q-020: Kernel DB service — namespaced SQL access?
- **Status:** Open
- **Question:** Do extensions get namespaced SQL access to `.clide/clide.db` (tables prefixed `ext_<id>_…`) or stay on the `kernel.settings` key/value facade? Admission-level question ([D-012](architecture.md#d-012-kernel-admission-rule)).
- **Context:** Some extensions (tickets, canvas, graph) naturally want relational storage. K/V gets awkward fast.
- **Source:** 2026-04-21 planning.

---
