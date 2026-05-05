# Tooling Decisions

Toolchain, supply chain, CI, ignore strategy.

---

### D-31: Prefer-zero-deps, exact-pin
- **Date:** 2026-04-21
- **Decision:** Default to writing code ourselves. Every third-party Dart dependency needs a paragraph of justification in the PR that adds it. What stays is exact-pinned in `pubspec.yaml` (no caret ranges), `pubspec.lock` is committed, and advisories are reviewed before every bump.
- **Rationale:** Supply-chain gate. Flutter SDK + Dart SDK give us most of what we need; the dependencies we keep are the ones we can't reasonably write (yaml parser, mocktail, alchemist). Exact-pin because caret ranges mean "the CVE bumps itself in silently."
- **Cost:** Longer PR descriptions for deps; occasional reinvention of a convenience. Accepted.
- **Raised by:** 2026-04-21 planning; reinforced by user feedback memory.

### D-32: CI — Gitea primary, Linux-only runners, not yet activated
- **Date:** 2026-04-21
- **Decision:** CI config lives at `.gitea/workflows/test.yml` (Gitea Actions consumes GitHub-Actions syntax). Runners are Linux only; macOS is tested locally. The workflow is ready but Gitea Actions is not yet activated on the instance — the file is a staged pipeline for review. If the repo moves to GitHub, the file copies to `.github/workflows/test.yml` verbatim.
- **Rationale:** We want the CI story defined before we turn CI on — lower blast radius on early red builds. GitHub portability is free because the syntax is shared.
- **Cost:** PRs don't run CI yet; `make push-check` is the gate until activation.
- **Raised by:** 2026-04-21 planning.

### D-42: Dependencies documented in `licenses.yaml`
- **Date:** 2026-04-22
- **Decision:** `app/assets/licenses.yaml` has three sections: `self:` (clide's MIT license, rendered first in the About screen so the user knows what they're running), `dependencies:` (third-party artefacts that **ship in the binary** — fonts, runtime Dart packages, native supporter tools, bundled data), and `dev_dependencies:` (build-time-only tooling — test runners, mocks, lints, golden harness — tracked for audit but **not rendered** in the About screen because they don't reach the user). Each entry has name, kind, version, homepage, license identifier, and a one-line purpose; runtime entries also carry a `license_file:` pointer to the bundled license text so the About screen can display it verbatim. Adding any dependency is a two-step commit: add the artefact **and** the corresponding `licenses.yaml` entry in the same changeset, under the correct section.
- **Rationale:** Complements [D-31](#d-31-prefer-zero-deps-exact-pin). Prefer-zero-deps is a *budget*; `licenses.yaml` is the *visible consequence*. An extra row in the About screen is a review-time signal that the shipped-binary surface grew. Splitting dev deps out keeps the user-facing list small and honest — a test framework is not something the user needs to see in About — while still documenting every supply-chain input for audit completeness. The runtime entries discharge the redistribution obligations bundled licenses impose (OFL, MIT, BSD all require preserving the license text alongside the binary) without ad-hoc NOTICE files.
- **Cost:** One extra edit per dep. Zero tolerance for drift — an un-listed dep is a contributor-visible bug. Until the About screen lands at Tier 6, `licenses.yaml` is accurate but not rendered; the discipline applies from now regardless so Tier 6 inherits a clean list.
- **Raised by:** 2026-04-22 planning (user-directed best practice).

### D-33: Golden-output ignore pattern — `coverage.*` excludes output, not scripts
- **Date:** 2026-04-21
- **Decision:** `.gitignore` excludes `coverage.*` (the lcov output files from `flutter test --coverage`). Coverage-related scripts are named `ci/test_coverage.sh` (not `ci/coverage.sh`) to stay outside the pattern.
- **Rationale:** An earlier draft named the script `ci/coverage.sh` and it was silently git-ignored. Renaming the script is cheaper than narrowing the gitignore pattern (which risks re-introducing output churn).
- **Cost:** Script names have a convention to follow.
- **Raised by:** 2026-04-21 planning (caught during commit rehearsal).

### D-58: Format engines are adoptable dependencies
- **Date:** 2026-04-23
- **Decision:** The "own the rendering stack" guardrail applies to **UI chrome** — panels, tabs, panes, canvas, terminal, layout primitives. **Format engines** — packages that parse or render external file formats (SVG, markdown, HTML, terminal escape sequences, tree-sitter grammars) — are adoptable like any other dependency: vet, exact-pin, CVE-lock, document in `licenses.yaml`. They are not shortcuts for lazy coding; they are well-maintained renderers for formats we didn't invent. The distinction: if it renders *our* UI, we own it; if it renders *someone else's file format*, we adopt a parser/renderer and sandbox it.
- **Adopted under this rule:** `jovial_svg` (SVG renderer), `markdown` (MD parser; renderer is ours), `flutter_widget_from_html_core` (HTML renderer; sandboxed), `xterm` (terminal emulator), tree-sitter (syntax highlighting). Canvas (`CustomPaint` + `InteractiveViewer`) stays in-house — UI chrome, not a format engine.
- **Amendment to D-31 (prefer-zero-deps):** D-31's "prefer-zero-deps" still applies — every new dependency needs justification. This record clarifies that format engines clear the justification bar by default. The supply-chain gate (exact-pin, advisory review, `licenses.yaml`) still applies.
- **Rationale:** Reimplementing SVG, markdown, or VT100 parsing adds months of work for no fidelity gain. tree-sitter already set this precedent. The key is sandboxing: HTML rendering must whitelist tags/attributes; SVG must not execute scripts; markdown rendering goes through our own widget builder so we control the output.
- **Cost:** Each adopted engine adds transitive dependencies and supply-chain surface. Mitigated by exact-pinning and `make security`.
- **Cross-reference:** [D-31](#d-31-prefer-zero-deps-exact-pin), [D-42](#d-42-dependencies-documented-in-licensesyaml).
- **Raised by:** 2026-04-23 format engine evaluation.

### D-59: Bundled git via dugite-native
- **Date:** 2026-04-25
- **Decision:** Ship a self-contained Git binary from [dugite-native](https://github.com/desktop/dugite-native) (the same distribution GitHub Desktop bundles). Downloaded at build time via `make dugite-fetch`, stored under `native/dugite/`, gitignored. The `Toolchain` class resolves to the bundled binary first, falling back to system git on PATH.
- **Rationale:** The macOS app sandbox blocks execution of Homebrew-installed git (symlinks resolve to Cellar paths that SBPL cannot match without freezing rendering). `/usr/bin/git` is an xcrun shim that refuses to run inside a sandbox. Bundling dugite-native makes clide self-contained — no dependency on Homebrew, Xcode CLT, or system git. The approach is proven: GitHub Desktop, Tower, and other git GUI apps all bundle their own git for the same reason.
- **Alternatives rejected:** (R) libgit2 via FFI — missing porcelain commands (pull/push/rebase), no hooks, would require rewriting GitClient. (R) Build git from source — dugite-native already does this with better infra. (R) SBPL exceptions for Homebrew — `(subpath "/opt/homebrew")` for process-exec freezes Flutter rendering on macOS 26.
- **Cost:** ~57 MB download (~199 MB unpacked, stripped at build time). Must track dugite-native releases for security updates. GPL-2.0 (git binary) applies to the bundled artefact, not to clide's MIT code.
- **Cross-reference:** [D-31](#d-31-prefer-zero-deps-exact-pin), [D-42](#d-42-dependencies-documented-in-licensesyaml).
- **Raised by:** 2026-04-25 macOS sandbox investigation.

### D-60: No network on default launch path
- **Date:** 2026-04-26
- **Decision:** clide does not perform network I/O during app startup, library initialization, or first use of any API unless the user has explicitly taken an action whose stated purpose is to cause a network fetch. Opening the app, opening a file, or typing in a buffer are not such actions. Libraries that download native binaries on first import (the `wasm_run` pattern), auto-installing language servers/grammars, CDN-fetched assets, startup telemetry, and unsolicited update checks are all prohibited. Signed, pinned fetches are permitted only when: the URL is hardcoded in the repo, the artifact is verified against a committed hash or signature, the fetch is cached, failure produces a clear error, and the primary function works without the fetch succeeding. If all five cannot be satisfied, vendor the artifact or require explicit user action.
- **Rationale:** clide's security model claims that app behavior on a user's machine is fully determined by the signed release artifact and the repository state at build time. The moment something is fetched from the network that wasn't audited at build time, the entire sandboxing and trust story collapses. See `POLICY.md` §"The core rule."
- **Cost:** Some features require vendoring artifacts that other apps would download at first launch. Accepted — the trust boundary is worth the extra build complexity.
- **Cross-reference:** [D-31](#d-31-prefer-zero-deps-exact-pin), [D-63](#d-63-vendored-binary-rebuild-process), `POLICY.md`.
- **Raised by:** 2026-04-26 policy-to-decision migration (T-28).

### D-61: Dependency vetting checklist
- **Date:** 2026-04-26
- **Decision:** Before adding any dependency (direct or transitive), verify: (1) **Network behavior** — no network I/O during import, init, or first call; no postinstall scripts that download binaries; check transitive deps with `flutter pub deps`. (2) **Binary provenance** — native binaries must be built from source in the same repo, not fetched from release artifacts. (3) **Maintainership** — single-maintainer packages need explicit sign-off and a documented fallback; packages with no activity in 12+ months require a controlled fork or inlining. (4) **Surface area** — prefer packages that do one thing; a dep adding 15 transitive deps for a 100-line problem should be inlined. (5) **Version pinning** — exact-pinned per D-31, lockfile committed, CVE-checked, source-reviewed, justified in place. (6) **License** — compatible per D-65.
- **Rationale:** D-31 states the budget; this record codifies the gate each dependency must pass. The checklist exists so agents and human contributors apply the same standard without re-deriving it each time.
- **Cost:** Longer evaluation cycle for new dependencies. Intentional — the cost of a bad dep is higher.
- **Cross-reference:** [D-31](#d-31-prefer-zero-deps-exact-pin), [D-60](#d-60-no-network-on-default-launch-path), [D-65](#d-65-license-compatibility-matrix), `POLICY.md`.
- **Raised by:** 2026-04-26 policy-to-decision migration (T-28).

### D-62: Dependency removal process
- **Date:** 2026-04-26
- **Decision:** A dependency is not removed until all five steps are completed in a single PR: (1) Grep the entire repository for references to the package, its exports, and contributed type names — zero hits outside git history. (2) Regenerate the lockfile. (3) Update `assets/licenses.yaml` to drop the package and any orphaned transitive deps. (4) Remove any vendored artifacts (binaries, prebuilt assets, generated bindings) and delete their `BUILD.md` records. (5) Check for architectural assumptions the dep was carrying — if it justified a data flow, build step, or platform strategy, the replacement must pick up those responsibilities or the relevant D-record must be updated.
- **Rationale:** "I deleted the line from pubspec.yaml" is the start of a removal, not the end. Partial removals leave orphaned lockfile entries (installed on fresh clones), stale license entries, or orphaned vendored binaries that look legitimate.
- **Cost:** Removal PRs are larger than the one-line diff suggests. Accepted.
- **Cross-reference:** [D-31](#d-31-prefer-zero-deps-exact-pin), [D-42](#d-42-dependencies-documented-in-licensesyaml), `POLICY.md`.
- **Raised by:** 2026-04-26 policy-to-decision migration (T-28).

### D-63: Vendored binary rebuild process
- **Date:** 2026-04-26
- **Decision:** Every vendored native binary has a `BUILD.md` next to it recording: (1) exact upstream source (git URL + commit SHA, not a version tag), (2) full build command with all compile flags, (3) toolchain version (compiler, linker, target triple), (4) expected output size and SHA-256 hash, (5) any patches applied (stored as `.patch` files in the same directory). Rebuilds happen in CI, not on contributor machines. The rebuild PR updates `BUILD.md`, the binaries, and hashes atomically. No binary is committed without a reproducibility record. Security patches to vendored deps are tracked with the same urgency as source-level vulnerabilities. Dropping a platform requires a policy decision; adding one requires adding it to the CI matrix and rebuilding all vendored binaries first.
- **Rationale:** Vendored binaries are inside the trust boundary — the signed release contains exactly these bytes. Without reproducibility records, a committed binary is unverifiable and therefore untrustworthy.
- **Cost:** Rebuilds require CI infrastructure and cross-compilation. Currently partially manual (T-25 tracks full CI automation).
- **Cross-reference:** [D-60](#d-60-no-network-on-default-launch-path), [D-42](#d-42-dependencies-documented-in-licensesyaml), T-25, `POLICY.md`.
- **Raised by:** 2026-04-26 policy-to-decision migration (T-28).

### D-65: License compatibility matrix
- **Date:** 2026-04-26
- **Decision:** clide is MIT-licensed. Every dependency, vendored binary, bundled font, and asset must be compatible and attributed. **Compatible (permissive):** MIT, Apache-2.0, BSD-2/3, ISC, Zlib, Unlicense, CC0. **Compatible with care (copyleft):** MPL-2.0 for libraries; LGPL only for dynamically-linked vendored binaries where users can replace the library. **Not compatible:** GPL for linked code (GPL vendored binaries like git are fine — they ship as separate executables), AGPL, SSPL, "commercial use prohibited," unreviewed custom licenses. Apache-2.0 deps preserve their NOTICE file verbatim. Apache-2.0-with-LLVM-exception requires the exception text specifically. Fonts and icon sets are attributed even if the license doesn't strictly require it. An incompatible or unclear license is disqualifying regardless of technical merit.
- **Rationale:** The compatibility rules existed in POLICY.md but were not captured as a D-record, making them invisible to the decision-reference system. This record makes them queryable and cross-referenceable.
- **Cost:** License evaluation adds time to the vetting checklist. Intentional.
- **Cross-reference:** [D-31](#d-31-prefer-zero-deps-exact-pin), [D-42](#d-42-dependencies-documented-in-licensesyaml), [D-61](#d-61-dependency-vetting-checklist), `POLICY.md`.
- **Raised by:** 2026-04-26 policy-to-decision migration (T-28).

---
