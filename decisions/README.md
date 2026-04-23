# Decisions

Confirmed decisions, open questions, and rejected alternatives for clide.

Decisions are split by domain. When unsure where a record belongs: if
it constrains **how we build**, it's architecture. If it defines **what
ships to users**, it's extensions / accessibility. If it defines **how
we verify**, it's testing. If it defines **what the toolchain looks
like**, it's tooling. If it defines **how the team works**, it's
process.

Cross-domain records live in one file with `[D-NNN]`-shaped cross-
references in related files. Split threshold: when any file exceeds
~350 lines, review whether it should split (see settled-reach's
`questions-*.md` split pattern for precedent).

## Domain files

| File | Domain |
|------|--------|
| [architecture.md](architecture.md) | Core, rendering, IPC, kernel, panel manager |
| [extensions.md](extensions.md) | Extension contract, Lua runtime, grain, contribution points |
| [accessibility.md](accessibility.md) | A11y + i18n policy, WCAG gates |
| [testing.md](testing.md) | Test pyramid, drivers, client-side constraint |
| [tooling.md](tooling.md) | Toolchain, supply chain, CI, ignore strategy |
| [process.md](process.md) | Q&D system, kanban, commit conventions, changelog |
| [rejected.md](rejected.md) | Rejected alternatives across all domains |
| [questions.md](questions.md) | Master index of open questions |
| [questions-architecture.md](questions-architecture.md) | Architecture Qs |
| [questions-extensions.md](questions-extensions.md) | Extension Qs |
| [questions-accessibility.md](questions-accessibility.md) | A11y / i18n Qs |
| [questions-testing.md](questions-testing.md) | Testing Qs |
| [questions-process.md](questions-process.md) | Process + tooling Qs |

## Record shape

Confirmed decisions (`D-NNN`):

```markdown
### D-NNN: Short title
- **Date:** YYYY-MM-DD
- **Decision:** one-sentence summary, then details.
- **Rationale:** why this over alternatives.
- **Cost:** known downsides / what we're accepting.
- **Raised by:** who proposed / endorsed.
```

Domain-specific fields (`Kill switch:`, `Evaluation reports:`,
`Amendment:`, `Cross-reference:`) are additive. Amendments are inline
and dated: `**Amendment (YYYY-MM-DD):** …`. Cross-references use
markdown anchor links with the full slug:
`[D-5](architecture.md#d-5-dart-core-ptyc-peer)`.

Open questions (`Q-NNN`):

```markdown
### Q-NNN: Short question-form title
- **Status:** Open | Partially resolved → [D-NNN] | Resolved → [D-NNN]
- **Question:** ...
- **Context:** ...
- **Assigned to:** (optional)
- **Source:** (optional)
```

Rejected alternatives (`R-NNN`):

```markdown
### R-NNN: Short rejected-option title
- **Rejected:** YYYY-MM-DD
- **Reason:** ...
- **Cross-reference:** [D-NNN] (what was picked instead)
```

## Claiming an ID

Until the pql planning subcommands land ([`Q-21`](questions-process.md)),
claim IDs by inspecting the highest existing `D-NNN` / `Q-NNN` /
`R-NNN` in the target file and incrementing.

Once `pql decisions claim D <domain> "title"` exists, use that —
same semantics, no race on concurrent sessions.

## Querying

`pql decisions …` reads `decisions/*.md` and writes `.pql/pql.db`
(gitignored; markdown is the source of truth).

Common queries:

```bash
pql decisions list --type confirmed --domain architecture
pql decisions show D-5 --with-refs
pql decisions coverage     # D-records without tickets
pql decisions validate     # pre-push parser gate
pql ticket board           # kanban view of tickets
```

## Adding a decision

1. Edit the appropriate domain file.
2. Follow the record shape above.
3. Run `pql decisions validate` (also runs in `make push-check`).
4. Commit. The SQLite index rebuilds from markdown on any
   `pql decisions sync`.
