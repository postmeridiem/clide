# Open Questions — Master Index

Open questions live in per-domain `questions-<domain>.md` files.
This index is a pointer and a place to record the most-load-bearing
open questions with one-line summaries.

## By domain

| File | Topics |
|------|--------|
| [questions-architecture.md](questions-architecture.md) | IPC, events, canvas, window chrome, macOS signing, pql absorption, ticket persistence, interaction model |
| [questions-extensions.md](questions-extensions.md) | Extension API shape, Lua runtime vendoring, manifest schema version |
| [questions-accessibility.md](questions-accessibility.md) | Web-mode a11y, i18n plurals/gender/dates |
| [questions-testing.md](questions-testing.md) | Coverage gates, screen-reader automation |
| [questions-process.md](questions-process.md) | Editor tab (LSP vs tree-sitter), icon set, theme hot-reload, kernel DB access, planning-tool location |

## Load-bearing questions (gate other work)

- **[Q-21](questions-process.md#q-21-pql-absorbs-planning-vs-keeps-separate)** — Pql absorbs planning features vs clide absorbs pql vs separate CLI. Blocks the stopgap sunset and shapes the pql-side planning session.
- **[Q-22](questions-process.md#q-22-ticket-persistence-strategy)** — Ticket persistence: per-dev only / milestone-committed / markdown-mirrored. Shapes multi-contributor story.
- **[Q-5](questions-architecture.md#q-5-ipc-wire-format-stability)** — IPC wire-format stability and `schema_version:` in `pubspec.yaml`. Decide when the first real subcommand lands.
- **[Q-15](questions-process.md#q-15-editor-tab-full-lsp-vs-tree-sitter-only)** — Editor tab: full LSP integration vs tree-sitter-only highlight. Decide during Tier 2.

---
