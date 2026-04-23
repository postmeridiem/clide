# Open Questions — Accessibility + i18n

---

### Q-13: Web production-mode a11y
- **Status:** Open
- **Question:** In a Flutter web release build, is the semantics tree always on (what we need for Playwright and for end-user screen readers) or gated behind an accessibility toggle (Flutter's default)?
- **Context:** Today the driver clicks `flt-semantics-placeholder` to activate. For user-facing builds we need semantics-always-on.
- **Source:** 2026-04-21 planning.

### Q-14: i18n plurals / gender / date-format tooling
- **Status:** Open
- **Question:** fframe's pattern covers straight key→string lookup with variable interpolation. Plurals, gendered forms, and ICU-style date formatting aren't in scope there. Do we add them to the i18n facade, defer to a runtime library (violates [D-31](tooling.md#d-31-prefer-zero-deps-exact-pin)), or require catalogues to provide pre-formatted strings per count/gender?
- **Context:** Probably becomes painful at Tier 3 (git panel, problem counts) and Tier 4 (pql results).
- **Source:** 2026-04-21 planning.

---
