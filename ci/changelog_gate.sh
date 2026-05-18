#!/usr/bin/env bash
# CHANGELOG concision gate — enforces a single 60-word per-bullet hard
# cap on the `## [Unreleased]` section. Released sections are frozen
# and skipped (don't penalize historical entries pre-dating the rule).
#
# A "bullet" is a markdown list item beginning with `- `, including any
# indented continuation lines until the next bullet, blank line, or
# heading. Word count is whitespace-tokenized.
#
# A soft 40-word warning was tried earlier and dropped — warnings that
# never block a push just normalise drift, so the gate is now binary.
#
# Bypass: never. If the rule rejects something genuinely user-visible
# that needs more context, the context belongs in the commit body or a
# D-record — see .claude/skills/git-commit/SKILL.md.
set -euo pipefail
cd "$(dirname "$0")/.."

CHANGELOG=CHANGELOG.md
HARD_CAP=60

if [[ ! -f "$CHANGELOG" ]]; then
  echo "==> changelog gate: $CHANGELOG missing" >&2
  exit 2
fi

awk -v hard="$HARD_CAP" '
  BEGIN { in_unreleased = 0; bullet = ""; bullet_start = 0; fail = 0 }

  function check_bullet() {
    if (bullet == "") return
    # Trim the leading "- " marker, then tokenize on whitespace.
    gsub(/^- +/, "", bullet)
    n = split(bullet, _words, /[[:space:]]+/)
    if (n > hard) {
      printf "FAIL line %d: bullet is %d words (cap %d)\n", bullet_start, n, hard
      printf "    %s\n\n", substr(bullet, 1, 120) (length(bullet) > 120 ? "..." : "")
      fail++
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
    printf "==> changelog gate OK\n"
  }
' "$CHANGELOG"
