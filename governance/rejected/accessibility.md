# Rejected — Accessibility

Alternatives considered and rejected, with rationale preserved for
future reference.

---

### R-4: Flutter `intl` + ARB codegen for i18n
- **Rejected:** 2026-04-21
- **Reason:** ARB codegen is inflexible for plugin-contributed catalogs — every catalogue needs a codegen pass, every extension ships with pre-generated Dart, and runtime merging is fighting the tool. The fframe text-driven pattern reads JSON at runtime with no codegen, which fits extension-shipped catalogs cleanly.
- **Cross-reference:** [D-21](../decisions/accessibility.md#d-21-i18n-is-a-tier-0-contract)

---
