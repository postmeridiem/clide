#!/usr/bin/env bash
# CHANGELOG concision gate — enforces the per-bullet word caps from the
# git-commit skill (40 soft, 60 hard) across the `## [Unreleased]`
# section. Released sections are frozen and skipped (don't penalize
# historical entries pre-dating the rule).
#
# A "bullet" is a markdown list item beginning with `- `, including any
# indented continuation lines until the next bullet, blank line, or
# heading. Word count is whitespace-tokenized.
#
# Soft cap 40 → warn (non-zero exit only if HARD is also breached).
# Hard cap 60 → fail.
#
# Bypass: never. If the rule rejects something genuinely user-visible
# that needs more context, the context belongs in the commit body or a
# D-record — see .claude/skills/git-commit/SKILL.md.
set -euo pipefail
cd "$(dirname "$0")/.."

CHANGELOG=CHANGELOG.md
SOFT_CAP=40
HARD_CAP=60

if [[ ! -f "$CHANGELOG" ]]; then
  echo "==> changelog gate: $CHANGELOG missing" >&2
  exit 2
fi

awk -v soft="$SOFT_CAP" -v hard="$HARD_CAP" '
  BEGIN { in_unreleased = 0; bullet = ""; bullet_start = 0; fail = 0; warn = 0 }

  function check_bullet() {
    if (bullet == "") return
    n = split(bullet, _words, /[[:space:]]+/)
    # split() counts a trailing empty token when the string starts/ends with
    # whitespace; trim the leading "- " marker too.
    gsub(/^- +/, "", bullet)
    n = split(bullet, _words, /[[:space:]]+/)
    if (n > hard) {
      printf "FAIL line %d: bullet is %d words (hard cap %d)\n", bullet_start, n, hard
      printf "    %s\n\n", substr(bullet, 1, 120) (length(bullet) > 120 ? "..." : "")
      fail++
    } else if (n > soft) {
      printf "WARN line %d: bullet is %d words (soft cap %d)\n", bullet_start, n, soft
      printf "    %s\n\n", substr(bullet, 1, 120) (length(bullet) > 120 ? "..." : "")
      warn++
    }
    bullet = ""
    bullet_start = 0
  }

  /^## \[Unreleased\]/ { in_unreleased = 1; next }
  /^## \[/ && in_unreleased { check_bullet(); in_unreleased = 0; exit_loop = 1 }
  !in_unreleased { next }

  # Within Unreleased.
  /^### / { check_bullet(); next }                       # subsection header
  /^[[:space:]]*$/ { check_bullet(); next }              # blank line ends bullet
  /^- / {                                                # new bullet
    check_bullet()
    bullet = $0
    bullet_start = NR
    next
  }
  /^[[:space:]]+/ && bullet != "" {                      # continuation of current bullet
    bullet = bullet " " $0
    next
  }

  END {
    check_bullet()
    if (fail > 0) {
      printf "\n==> changelog gate FAIL: %d bullet(s) over %d words.\n", fail, hard
      printf "    Trim them. Rationale, probe results, behavior-change deep dives\n"
      printf "    belong in the commit body, a D-record, or the ticket — not here.\n"
      printf "    See .claude/skills/git-commit/SKILL.md \"Be concise\".\n"
      exit 1
    }
    if (warn > 0) {
      printf "==> changelog gate OK with %d warning(s) over %d words.\n", warn, soft
    } else {
      printf "==> changelog gate OK\n"
    }
  }
' "$CHANGELOG"
