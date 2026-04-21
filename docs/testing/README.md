# Testing clide

Every layer of the test pyramid is wired. The suite is intentionally
designed to run client-side only — `git clone && make push-check` works
on any Linux or macOS dev box without network access or shared state.

## Layers

| layer | location | runner | time | when |
|---|---|---|---|---|
| unit (root) | `test/` | `dart test` | ~5s | `make test` |
| unit + widget + golden (app) | `app/test/` | `flutter test` | ~30s | `make test` |
| a11y contract | `app/test/a11y/` | `flutter test` | ~5s | `make test-a11y` |
| integration (startup gate) | `app/integration_test/` | `flutter test integration_test/` | ~60s | `make test-integration` |
| daemon E2E + web WASM smoke | `test/daemon/` + `tools/ui/tests/` | `dart test` + Playwright | ~60s | `make test-e2e` |
| startup bundle smoke | `ci/smoke_bundle.sh` | xvfb-run, 5s timeout | ~30s | `make smoke-bundle` |

## Dev loop

```bash
make push-check        # gate before `git push` (~90s)
make test-all          # full pyramid (~3-5min)
```

## A11y + i18n

A11y is a day-one contract, not a Tier-6 polish. Every interactive widget
emits a `Semantics` node with label + hint. The a11y suite enforces:

- **semantic_coverage_test.dart** — every built-in declares title + version
  and every interactive contribution carries the fields needed to build a
  Semantics node.
- **contrast_test.dart** — every bundled theme meets WCAG-AA on the token
  pairs in `lib/kernel/src/theme/contrast.dart`. Catches token-pair
  regressions (foreground-on-background, tab.active-on-bg, etc.).
- **i18n_coverage_test.dart** — every i18n key referenced by Tier-0
  built-ins exists in its en_US catalog. Asserts key presence directly
  (not "returned value == key" — that's ambiguous for keys that happen
  to equal their English translation).
- **keyboard_traversal_test.dart** — interactive widgets are focusable
  and expose tap actions to a11y.

See [`a11y-manual.md`](a11y-manual.md) for the 15-minute manual
screen-reader checklist run at every tier cut.

## Interacting with the app (Claude + humans)

Claude Code drives the Flutter WASM build through a Playwright harness
— not via screenshots. Semantics are the contract. See
[`claude-ui-workflow.md`](claude-ui-workflow.md) for the loop.

## CI

`.gitea/workflows/test.yml` is ready to run but Gitea Actions is not
enabled on the instance yet. When the user flips it, four jobs kick off
per push: `unit`, `integration`, `startup-bundle`, `e2e`. The workflow
file is GitHub-Actions compatible — copying it to `.github/workflows/`
is the entire migration if the repo moves to GitHub.
