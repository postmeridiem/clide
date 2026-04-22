# Tooling Decisions

Toolchain, supply chain, CI, ignore strategy.

---

### D-031: Prefer-zero-deps, exact-pin
- **Date:** 2026-04-21
- **Decision:** Default to writing code ourselves. Every third-party Dart dependency needs a paragraph of justification in the PR that adds it. What stays is exact-pinned in `pubspec.yaml` (no caret ranges), `pubspec.lock` is committed, and advisories are reviewed before every bump.
- **Rationale:** Supply-chain gate. Flutter SDK + Dart SDK give us most of what we need; the dependencies we keep are the ones we can't reasonably write (yaml parser, mocktail, alchemist). Exact-pin because caret ranges mean "the CVE bumps itself in silently."
- **Cost:** Longer PR descriptions for deps; occasional reinvention of a convenience. Accepted.
- **Raised by:** 2026-04-21 planning; reinforced by user feedback memory.

### D-032: CI — Gitea primary, Linux-only runners, not yet activated
- **Date:** 2026-04-21
- **Decision:** CI config lives at `.gitea/workflows/test.yml` (Gitea Actions consumes GitHub-Actions syntax). Runners are Linux only; macOS is tested locally. The workflow is ready but Gitea Actions is not yet activated on the instance — the file is a staged pipeline for review. If the repo moves to GitHub, the file copies to `.github/workflows/test.yml` verbatim.
- **Rationale:** We want the CI story defined before we turn CI on — lower blast radius on early red builds. GitHub portability is free because the syntax is shared.
- **Cost:** PRs don't run CI yet; `make push-check` is the gate until activation.
- **Raised by:** 2026-04-21 planning.

### D-042: Dependencies documented in `licenses.yaml`
- **Date:** 2026-04-22
- **Decision:** `app/assets/licenses.yaml` has three sections: `self:` (clide's MIT license, rendered first in the About screen so the user knows what they're running), `dependencies:` (third-party artefacts that **ship in the binary** — fonts, runtime Dart packages, native supporter tools, bundled data), and `dev_dependencies:` (build-time-only tooling — test runners, mocks, lints, golden harness — tracked for audit but **not rendered** in the About screen because they don't reach the user). Each entry has name, kind, version, homepage, license identifier, and a one-line purpose; runtime entries also carry a `license_file:` pointer to the bundled license text so the About screen can display it verbatim. Adding any dependency is a two-step commit: add the artefact **and** the corresponding `licenses.yaml` entry in the same changeset, under the correct section.
- **Rationale:** Complements [D-031](#d-031-prefer-zero-deps-exact-pin). Prefer-zero-deps is a *budget*; `licenses.yaml` is the *visible consequence*. An extra row in the About screen is a review-time signal that the shipped-binary surface grew. Splitting dev deps out keeps the user-facing list small and honest — a test framework is not something the user needs to see in About — while still documenting every supply-chain input for audit completeness. The runtime entries discharge the redistribution obligations bundled licenses impose (OFL, MIT, BSD all require preserving the license text alongside the binary) without ad-hoc NOTICE files.
- **Cost:** One extra edit per dep. Zero tolerance for drift — an un-listed dep is a contributor-visible bug. Until the About screen lands at Tier 6, `licenses.yaml` is accurate but not rendered; the discipline applies from now regardless so Tier 6 inherits a clean list.
- **Raised by:** 2026-04-22 planning (user-directed best practice).

### D-033: Golden-output ignore pattern — `coverage.*` excludes output, not scripts
- **Date:** 2026-04-21
- **Decision:** `.gitignore` excludes `coverage.*` (the lcov output files from `flutter test --coverage`). Coverage-related scripts are named `ci/test_coverage.sh` (not `ci/coverage.sh`) to stay outside the pattern.
- **Rationale:** An earlier draft named the script `ci/coverage.sh` and it was silently git-ignored. Renaming the script is cheaper than narrowing the gitignore pattern (which risks re-introducing output churn).
- **Cost:** Script names have a convention to follow.
- **Raised by:** 2026-04-21 planning (caught during commit rehearsal).

---
