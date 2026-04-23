# Open Questions — Testing

---

### Q-11: Coverage gates — hard thresholds vs soft reporting
- **Status:** Open
- **Question:** `ci/test_coverage.sh` emits lcov + a summary. Do we gate merges on a hard threshold (fail < 80%), report softly, or tier per directory (kernel > 90%, built-ins > 70%, widgets covered by goldens exempt)?
- **Context:** Hard thresholds force tests-for-coverage-sake; soft reporting gets ignored.
- **Source:** 2026-04-21 planning.

### Q-12: Screen-reader automation (axe-core via Playwright)
- **Status:** Open
- **Question:** [D-22](accessibility.md#d-22-wcag-aa-contrast-gate-on-bundled-themes) gates contrast at build time. Do we also run axe-core against the WASM build in Playwright for runtime a11y issues (missing labels, invalid roles, orphan focusables)?
- **Context:** axe-core is JS; runs in the browser against the rendered tree. Extra CI time; extra signal.
- **Source:** 2026-04-21 planning.

---
