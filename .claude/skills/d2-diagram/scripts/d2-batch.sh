#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel)"
RENDER="$SCRIPT_DIR/d2-render.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [directory] [options]

Batch render all .d2 files in a directory. Skips files whose PNG is
newer than the source unless --force is used.

Options:
  --dry-run    List files that would be rendered
  --force      Re-render even if SVG is up to date
  --theme N    Override theme for all files

Examples:
  $(basename "$0")                                # All in docs/diagrams/
  $(basename "$0") docs/diagrams/architecture/    # One category
  $(basename "$0") --dry-run                      # Preview
  $(basename "$0") --force                        # Re-render everything
EOF
  exit 1
}

DIR="$REPO_ROOT/docs/diagrams"
DRY_RUN=false
FORCE=false
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --force)   FORCE=true; shift ;;
    --theme)   EXTRA_ARGS+=(--theme "$2"); shift 2 ;;
    --help|-h) usage ;;
    *)
      if [[ -d "$1" ]] || [[ -d "$REPO_ROOT/$1" ]]; then
        DIR="$1"
        [[ "$DIR" != /* ]] && DIR="$REPO_ROOT/$DIR"
      else
        echo "Unknown option or directory: $1" >&2; exit 1
      fi
      shift
      ;;
  esac
done

[[ ! -d "$DIR" ]] && { echo "ERROR: Directory not found: $DIR" >&2; exit 1; }

RENDERED=0
SKIPPED=0
FAILED=0

while IFS= read -r -d '' d2_file; do
  png_file="${d2_file%.d2}.png"

  # Skip if PNG is newer than source (unless --force)
  if [[ "$FORCE" != true ]] && [[ -f "$png_file" ]] && [[ "$png_file" -nt "$d2_file" ]]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  rel_path="${d2_file#"$REPO_ROOT/"}"

  if [[ "$DRY_RUN" == true ]]; then
    echo "Would render: $rel_path"
    RENDERED=$((RENDERED + 1))
    continue
  fi

  if "$RENDER" "$d2_file" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"; then
    RENDERED=$((RENDERED + 1))
  else
    echo "FAILED: $rel_path" >&2
    FAILED=$((FAILED + 1))
  fi
done < <(find "$DIR" -name '*.d2' -print0 | sort -z)

echo ""
echo "Batch complete: $RENDERED rendered, $SKIPPED skipped (up to date), $FAILED failed"
