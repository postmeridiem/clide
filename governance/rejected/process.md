# Rejected — Process

Alternatives considered and rejected, with rationale preserved for
future reference.

---

### R-6: Nerd-font glyph icons
- **Rejected:** 2026-04-21
- **Reason:** TUI hangover from the Python-era clide under `legacy/`. Not desktop-native; forces a font dependency; doesn't theme consistently. Clide uses custom icon primitives (Tier 6 revisits with proper icon-set design).
- **Cross-reference:** [Q-17](../questions/process.md#q-17-icon-set-growth)

### R-9: Port planning tooling into clide
- **Rejected:** 2026-04-21
- **Reason:** Earlier in the planning session the assumption was "clide owns Dart subcommands for decisions + tickets." That breaks the day a contributor works in a terminal or in VS Code / JetBrains — they have no `clide` binary to run. Reversing: pql owns planning long-term (see [D-39](../decisions/process.md#d-39-planning-tooling-lives-in-pql)); clide consumes via shell-out.
- **Cross-reference:** [D-39](../decisions/process.md#d-39-planning-tooling-lives-in-pql)

### R-10: Python-script stopgap under `tooling/db/`
- **Rejected:** 2026-04-21
- **Reason:** Location, not language. Settled-reach puts scripts at `tooling/db/` — copying that path here creates a script-pollution problem: every project using the pattern commits its own copy. The accepted Python port ([D-40](../decisions/process.md#d-40-python-stopgap-under-toolsscriptsplan)) lives at `tools/scripts/plan`, clearly signalled as dev-tooling and time-limited.
- **Cross-reference:** [D-40](../decisions/process.md#d-40-python-stopgap-under-toolsscriptsplan)

### R-11: Permanent stopgap
- **Rejected:** 2026-04-21
- **Reason:** If the Python port under `tools/scripts/plan` outlasts pql's feature parity, delete it. The deletion commit should be one changeset: remove `tools/scripts/plan`, remove its Makefile target (`decisions-validate` rewires to `pql decisions validate`), add a `CHANGELOG.md` entry under Removed, and verify `.pql/pql.db` still opens under the new `pql` binary.
- **Cross-reference:** [D-40](../decisions/process.md#d-40-python-stopgap-under-toolsscriptsplan)

---
