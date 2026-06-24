#!/usr/bin/env bash
# Release finalizer for the single-process Flutter app (T-393).
#
# Run AFTER the `release vX.Y.Z` commit is in place (version bump + changelog
# move — see .claude/skills/git-commit/SKILL.md "Cutting a release"). It:
#   1. reads the version from pubspec.yaml,
#   2. asserts CHANGELOG.md has a dated section for it (not still Unreleased),
#   3. asserts the working tree is clean,
#   4. runs the full gate (make push-check),
#   5. creates the annotated vX.Y.Z tag if missing — closing the loop that
#      previously left every release since v2.1.0 untagged.
#
# No goreleaser, no sidecar (both dissolved, D-56). Artifact builds are
# `make build-linux` / `make build-macos`. This never pushes — it prints the
# push command for you to run.
#
# Invoke via `make release`, not directly.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

version="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
if [[ -z "$version" ]]; then
  echo "release: could not read 'version:' from pubspec.yaml" >&2
  exit 1
fi
tag="v$version"

# 1. The release commit must already have moved Unreleased → [version] — DATE.
if ! grep -qE "^## \[${version//./\\.}\] — [0-9]{4}-[0-9]{2}-[0-9]{2}" CHANGELOG.md; then
  echo "release: CHANGELOG.md has no dated section for [$version]." >&2
  echo "         Cut the release commit first (move Unreleased → '## [$version] — YYYY-MM-DD')." >&2
  exit 1
fi

# 2. Clean tree — the release commit is in, nothing dangling.
if [[ -n "$(git status --porcelain)" ]]; then
  echo "release: working tree not clean — commit the release first." >&2
  exit 1
fi

# 3. Full gate.
echo "release: running the full gate (make push-check)…"
make push-check

# 4. Tag (idempotent), annotated, on the current release commit.
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "release: tag $tag already exists — leaving it."
else
  git tag -a "$tag" -m "clide $tag"
  echo "release: created tag $tag at $(git rev-parse --short HEAD)."
fi

echo
echo "release: $tag verified and tagged. Next:"
echo "  git push origin main --follow-tags   # publish the commit + tag"
echo "  make build-linux                     # desktop bundle (Linux)"
echo "  make build-macos                     # desktop bundle (macOS, on a Mac)"
