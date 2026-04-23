# Accessibility + i18n Decisions

A11y + i18n are Tier-0 contracts, not Tier-6 polish.

---

### D-20: A11y is a Tier-0 contract
- **Date:** 2026-04-21
- **Decision:** Every widget primitive wraps its interaction surface in a `Semantics` node at the point of creation. A11y coverage is a test-time gate (`ci/test_a11y.sh`), not a post-hoc polish pass. `ensureSemantics()` fires at app boot; Flutter's semantics tree is always populated.
- **Rationale:** Retrofitting a11y onto a grown UI is what every project that skips this promises to do later and then doesn't. Making it a Tier-0 contract costs one `Semantics` line per primitive and a semantic-coverage test; postponing costs a rewrite.
- **Cost:** Widget authors maintain correct labels; tests reject new primitives without semantics. Enforced by `app/test/a11y/` coverage tests.
- **Raised by:** 2026-04-21 planning.

### D-21: i18n is a Tier-0 contract (fframe pattern + locale-fallback chain)
- **Date:** 2026-04-21
- **Decision:** All user-facing strings resolve through a namespaced i18n catalogue loader ported from fframe's text-driven pattern, extended with a locale-fallback chain fframe lacks. JSON per locale; `I18n.of(context).t('namespace.key', {vars})`. Missing keys resolve down the chain (e.g. `en_GB` → `en` → default), never fail silently; missing at the base locale logs a dev-mode error.
- **Rationale:** Flutter's `intl` + ARB codegen is inflexible for plugin-contributed catalogs (see [R-4](rejected.md#r-4-flutter-intl-and-arb-codegen)) — we need per-extension catalogs that merge without a codegen step. fframe's shape fits; its silent-fallback behaviour does not, so we add the chain.
- **Cost:** JSON has no comments and no trailing commas; translation tooling has to accept that. Separate `i18n` facade on every feature.
- **Raised by:** 2026-04-21 planning.

### D-22: WCAG-AA contrast gate on bundled themes
- **Date:** 2026-04-21
- **Decision:** Every bundled theme must pass a WCAG-AA contrast check on its canonical token pairs (text/background, link/background, focus-ring/background) at test time. `ci/test_a11y.sh` runs the gate; CI fails on regressions.
- **Rationale:** Themes drift under "looks nicer" tweaks; contrast regressions land silently. Running the gate on every PR is the cheapest insurance. Ran the gate on initial themes — caught one summer-night muted token at 2.81:1 (below AA), fixed before landing.
- **Cost:** Third-party themes (Tier 6) won't be gated until an extension-time test hook lands. Bundled themes are gated today.
- **Raised by:** 2026-04-21 planning.

---
