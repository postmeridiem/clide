# Rejected — Testing

Alternatives considered and rejected, with rationale preserved for
future reference.

---

### R-5: Patrol test runner
- **Rejected:** 2026-04-21
- **Reason:** Adds a dependency (violates [D-31](../decisions/tooling.md#d-31-prefer-zero-deps-exact-pin)) for a capability we get from Playwright + Flutter's own semantics tree. Patrol's value proposition (native-gesture emulation) is less relevant on Linux desktop than on mobile.
- **Cross-reference:** [D-26](../decisions/testing.md#d-26-web-driver--raw-playwright--flutter-semantics)

---
