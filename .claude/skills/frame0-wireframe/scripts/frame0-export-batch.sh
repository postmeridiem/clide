#!/usr/bin/env bash
# Batch export wireframes from JSON to PNG via Frame0.
#
# Finds all .json wireframe files under docs/design/wireframes/ and exports
# each to a matching .png. Skips files whose PNG is already newer than the
# JSON, unless --force is passed.
#
# Usage:
#   frame0-export-batch.sh [--dry-run] [--force] [--category CAT] [--root DIR]
#
# Options:
#   --dry-run       Print manifest only, don't touch Frame0.
#   --force         Re-export even if PNG already exists and is up to date.
#   --category CAT  Limit to one subdirectory (e.g. --category dialogue)
#   --root DIR      Wireframes root dir (default: docs/design/wireframes)
#
# Exit codes:
#   0  All exports succeeded (or nothing to do)
#   1  One or more exports failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SYNC="$SCRIPT_DIR/frame0-sync.py"
DEFAULT_ROOT="$REPO_ROOT/docs/design/wireframes"

DRY_RUN=false
FORCE=false
CATEGORY=""
WF_ROOT="$DEFAULT_ROOT"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=true; shift ;;
    --force)      FORCE=true; shift ;;
    --category)   CATEGORY="$2"; shift 2 ;;
    --root)       WF_ROOT="$2"; shift 2 ;;
    -h|--help)
      sed -n '/^# /p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$WF_ROOT" ]]; then
  echo "ERROR: Wireframes directory not found: $WF_ROOT" >&2
  exit 1
fi

# Collect JSON files, optionally filtered by category subdirectory
mapfile -t JSON_FILES < <(
  if [[ -n "$CATEGORY" ]]; then
    find "$WF_ROOT/$CATEGORY" -name "*.json" ! -name ".*" | sort
  else
    find "$WF_ROOT" -name "*.json" ! -name ".*" | sort
  fi
)

if [[ ${#JSON_FILES[@]} -eq 0 ]]; then
  echo "No wireframe JSON files found."
  exit 0
fi

# Classify files into to-export and to-skip
TO_EXPORT=()
TO_SKIP=()

for json in "${JSON_FILES[@]}"; do
  png="${json%.json}.png"
  if $FORCE || [[ ! -f "$png" ]] || [[ "$json" -nt "$png" ]]; then
    TO_EXPORT+=("$json")
  else
    TO_SKIP+=("$json")
  fi
done

# Print manifest
if [[ ${#TO_EXPORT[@]} -gt 0 ]]; then
  echo ""
  echo "Will export (${#TO_EXPORT[@]} files):"
  for json in "${TO_EXPORT[@]}"; do
    png="${json%.json}.png"
    rel="${json#$REPO_ROOT/}"
    if [[ ! -f "$png" ]]; then
      status="new"
    else
      status="updated"
    fi
    printf "  [%-7s]  %s\n" "$status" "$rel"
  done
else
  echo ""
  echo "Nothing to export (all PNGs up to date)."
fi

if [[ ${#TO_SKIP[@]} -gt 0 ]]; then
  echo ""
  echo "Will skip (${#TO_SKIP[@]} files already up to date):"
  for json in "${TO_SKIP[@]}"; do
    rel="${json#$REPO_ROOT/}"
    printf "  [skip   ]  %s\n" "$rel"
  done
fi

if $DRY_RUN; then
  echo ""
  echo "Dry run — no exports performed."
  exit 0
fi

if [[ ${#TO_EXPORT[@]} -eq 0 ]]; then
  exit 0
fi

echo ""
PASSED=0
FAILED=0
FAILED_FILES=()

TOTAL=${#TO_EXPORT[@]}
IDX=0

for json in "${TO_EXPORT[@]}"; do
  IDX=$((IDX + 1))
  png="${json%.json}.png"
  rel="${json#$REPO_ROOT/}"

  printf "[%d/%d]  %s ... " "$IDX" "$TOTAL" "$rel"

  output=$(python3 "$SYNC" export "$json" "$png" 2>/tmp/frame0-batch-err.txt)
  rc=$?
  if [[ $rc -eq 0 ]]; then
    size=$(echo "$output" | tail -1 | grep -oP '\(\K[^)]+' || true)
    echo "ok  $size"
    PASSED=$((PASSED + 1))
  else
    echo "FAILED"
    cat /tmp/frame0-batch-err.txt >&2
    FAILED=$((FAILED + 1))
    FAILED_FILES+=("$rel")
  fi
done

echo ""
echo "$PASSED exported, $FAILED failed."

if [[ $FAILED -gt 0 ]]; then
  echo ""
  echo "Failed:" >&2
  for f in "${FAILED_FILES[@]}"; do
    echo "  $f" >&2
  done
  exit 1
fi

exit 0
