# friction.md

A running log of install / setup / environment friction — the papercuts that
cost time getting clide (and its tooling) working on a machine. Newest first.

Each entry: **symptom → root cause → fix**, with enough detail that the next
person (or the next clone) can recognise and resolve it fast.

---

## 2026-06-06 — pql hooks disabled the repo's pre-push gate

**Symptom**
- "pql setup is broken." On the surface pql worked (`pql schema`,
  `pql decisions sync`, `pql plan status` all fine), but the git hook wiring
  was in a split-brain state.

**Root cause**
- The repo's intended setup is `git config core.hooksPath .githooks` (run via
  `make hooks`). `.githooks/` is the committed, canonical hook set: it carries
  **both** pql's planning delegators (pre-commit / post-merge / post-checkout /
  post-rewrite, each sourcing `.pql/hooks/*`) **and** the repo's own `pre-push`
  gate (`make push-check`).
- `core.hooksPath` was **unset** in every scope, so git fell back to the
  default `.git/hooks/`. `pql init` had populated *that* directory with only
  the pql delegators — **no `pre-push`**.
- Net effect: the pre-push gate (decisions + core + fast tests + a11y) was
  silently **not running** on push, while pql's automation ran only by accident
  from the default dir. CLAUDE.md requires the gate to always run and forbids
  `--no-verify`, so this was a real (silent) regression, not cosmetic.

**Fix**
- `make hooks` → restores `core.hooksPath = .githooks` (now `pre-push` and the
  pql delegators all fire from one canonical, git-tracked source).
- Removed the stray pql-only delegators from `.git/hooks/`
  (`pre-commit`, `post-merge`, `post-checkout`, `post-rewrite`). They became
  inert once hooksPath pointed elsewhere, and leaving them created a dangerous
  partial fallback — a hook set that runs pql but silently skips the pre-push
  gate if `core.hooksPath` ever gets unset again. The real hook logic lives in
  `.pql/hooks/` and was untouched.

**Watch out for**
- `pql init` installs into the default `.git/hooks/` and does **not** respect an
  existing `core.hooksPath`. After running it, re-run `make hooks` and verify
  with `git rev-parse --git-path hooks` (should print `.githooks`) and confirm
  `.githooks/pre-push` is present & executable.
