# Accessibility + i18n Decisions

A11y + i18n are Tier-0 contracts, not Tier-6 polish.

---

### D-20: A11y is a Tier-0 contract
- **Date:** 2026-04-21
- **Decision:** Every widget primitive wraps its interaction surface in a `Semantics` node at the point of creation. A11y coverage is a test-time gate (`ci/test_a11y.sh`), not a post-hoc polish pass. `ensureSemantics()` fires at app boot; Flutter's semantics tree is always populated.
- **Rationale:** Retrofitting a11y onto a grown UI is what every project that skips this promises to do later and then doesn't. Making it a Tier-0 contract costs one `Semantics` line per primitive and a semantic-coverage test; postponing costs a rewrite.
- **Cost:** Widget authors maintain correct labels; tests reject new primitives without semantics. Enforced by `test/a11y/` coverage tests.
- **Raised by:** 2026-04-21 planning.

### D-21: i18n is a Tier-0 contract (fframe pattern + locale-fallback chain)
- **Date:** 2026-04-21
- **Decision:** All user-facing strings resolve through a namespaced i18n catalogue loader ported from fframe's text-driven pattern, extended with a locale-fallback chain fframe lacks. JSON per locale; `I18n.of(context).t('namespace.key', {vars})`. Missing keys resolve down the chain (e.g. `en_GB` → `en` → default), never fail silently; missing at the base locale logs a dev-mode error.
- **Rationale:** Flutter's `intl` + ARB codegen is inflexible for plugin-contributed catalogs (see [R-4](../rejected/accessibility.md#r-4-flutter-intl--arb-codegen-for-i18n)) — we need per-extension catalogs that merge without a codegen step. fframe's shape fits; its silent-fallback behaviour does not, so we add the chain.
- **Cost:** JSON has no comments and no trailing commas; translation tooling has to accept that. Separate `i18n` facade on every feature.
- **Raised by:** 2026-04-21 planning.

### D-22: WCAG-AA contrast gate on bundled themes
- **Date:** 2026-04-21
- **Decision:** Every bundled theme must pass a WCAG-AA contrast check on its canonical token pairs (text/background, link/background, focus-ring/background) at test time. `ci/test_a11y.sh` runs the gate; CI fails on regressions.
- **Rationale:** Themes drift under "looks nicer" tweaks; contrast regressions land silently. Running the gate on every PR is the cheapest insurance. Ran the gate on initial themes — caught one summer-night muted token at 2.81:1 (below AA), fixed before landing.
- **Cost:** Third-party themes (Tier 6) won't be gated until an extension-time test hook lands. Bundled themes are gated today.
- **Raised by:** 2026-04-21 planning. Refined by [D-69](#d-69-published-themes-are-user-contracts-ship-hc-variants-for-a11y) — the gate's *strict* pair set only applies to high-contrast variants; named themes keep their published palettes.

### D-69: published themes are user contracts; ship -hc variants for a11y
- **Date:** 2026-05-17
- **Decision:** The four bundled themes that ship under a recognisable name — `clide`, `midnight`, `paper`, `terminal` — are user contracts. Their palette colours (including syntax tokens, status colours, and borderHi) MUST NOT be retuned to satisfy contrast gates. When a stricter contrast check would fail one of them, the fix is one of: (a) ship a sibling theme with `-hc` (high-contrast) or `-cb` (colour-blind) in the name and enforce the strict pair set only there, or (b) split `canonicalPairs` into a *baseline* set every theme must pass and an *extended* set that only the `-hc`/`-cb` variants must pass.
- **Rationale:** Users pick `midnight` because it looks like VS Code, `paper` because it reads as a drafting sheet, `terminal` because of the amber-on-near-black tmux feel. Quietly darkening `paper`'s success/warning/info or boosting `midnight`'s `borderHi` to pass a WCAG-AA check changes what they got and what they signed up for. A11y is a Tier-0 contract ([D-20](#d-20-a11y-is-a-tier-0-contract)), but it's served by *offering* an accessible variant, not by overwriting the aesthetic ones. VS Code itself ships `Default Dark+` and a separate `Default High Contrast` for exactly this reason.
- **Cost:** Two extra theme files per "named" theme when we add a11y variants. The bundled-theme contrast gate ([D-22](#d-22-wcag-aa-contrast-gate-on-bundled-themes)) needs a baseline/extended split so the named themes don't fail the strict pairs.
- **Raised by:** 2026-05-17 — user intervened mid-T-114 when I had retuned `clide`/`midnight`/`paper`/`terminal` palette entries to satisfy the expanded `canonicalPairs`; reverted, decision written, T-114 will follow this rule.

### D-102: i18n routing — ext-id namespaces, `core` catalog, ClideSettings.i18n facade, contribution keys
- **Date:** 2026-06-19
- **Decision:** Implements [D-21](#d-21-i18n-is-a-tier-0-contract-fframe-pattern--locale-fallback-chain) across the whole app (epic T-462).
  - **Namespaces:** an extension's catalog namespace IS its id (`builtin.<name>`); the ExtensionManager eager-loads it on activation, so a built-in localizes with no hand-maintained registry. Framework chrome outside any extension (`lib/widgets`, `lib/kernel`, the shared reader chrome) resolves under one **`core`** namespace, preloaded at boot.
  - **Read path:** widgets resolve through the single [D-101](architecture.md) facade — `ClideSettings.i18n.string(context, key, namespace:, placeholder:)` (+ `.interpolated`) — null-safe (returns the placeholder when no kernel is in scope, so primitives render in isolated tests).
  - **Manifest labels:** `CommandContribution` carries `titleKey`/`i18nNamespace`; the palette and menu resolve via a shared `localizedCommandTitle`, and the palette's fuzzy search matches the localized title. The settings schema carries `i18nNamespace`+`titleKey` on the category and `labelKey`/`helpKey`/option `labelKey` beneath it, threaded down by the renderer.
  - **Storage:** catalogs are bundled assets at `assets/i18n/<locale>/<namespace>.json` — the locale is a *directory* (`en_us`, future `nl_nl`, `nl_be`, `en_eu`, …), so a new language is a new folder of the same namespace files, no renames.
- **Rationale:** makes a complete translation set (e.g. a Dutch pack) a pure data drop — no code. ext-id namespaces need no registry; the facade keeps one widget-facing read path for theme/fonts/i18n (D-101); the locale-dir layout is cleaner to maintain and mirrors how an external extension ships its own catalog.
- **Cost:** every extension's manifest gains optional key fields, and framework primitives now depend on the (null-safe) facade. The pure-data search matcher (`settingsFieldMatches`) still matches the English label — display localizes, search-by-translation does not (acceptable refinement).
- **Raised by:** 2026-06-19, epic T-462 (i18n everywhere). Builds on [D-101](architecture.md).

---
