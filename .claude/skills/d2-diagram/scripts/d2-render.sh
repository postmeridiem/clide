#!/bin/bash
set -euo pipefail

D2="/home/linuxbrew/.linuxbrew/bin/d2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel)"

DEFAULT_THEME=200
DEFAULT_LAYOUT="dagre"
DEFAULT_PAD=100

usage() {
  cat <<EOF
Usage: $(basename "$0") [validate|fmt] <file.d2> [options]

Render a .d2 file to PNG with project defaults (theme $DEFAULT_THEME, $DEFAULT_LAYOUT layout).

Commands:
  validate <file>     Check syntax without rendering
  fmt <file>          Auto-format in place

Options:
  --theme N           Override theme (default: $DEFAULT_THEME)
  --layout NAME       Override layout engine (default: $DEFAULT_LAYOUT)
  --sketch            Enable hand-drawn sketch mode
  --output PATH       Override output path (default: input with .png extension)
  --svg               Render to SVG instead of PNG

Examples:
  $(basename "$0") docs/diagrams/architecture/ipc-bridge.d2
  $(basename "$0") validate docs/diagrams/architecture/ipc-bridge.d2
  $(basename "$0") docs/diagrams/architecture/ipc-bridge.d2 --sketch --theme 0
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage

# Parse subcommand
SUBCMD=""
case "$1" in
  validate|fmt)
    SUBCMD="$1"
    shift
    ;;
esac

[[ $# -lt 1 ]] && usage

INPUT="$1"
shift

# Resolve to absolute path
[[ "$INPUT" != /* ]] && INPUT="$REPO_ROOT/$INPUT"

[[ ! -f "$INPUT" ]] && { echo "ERROR: File not found: $INPUT" >&2; exit 1; }

# Handle subcommands
if [[ -n "$SUBCMD" ]]; then
  "$D2" "$SUBCMD" "$INPUT"
  echo "OK: $SUBCMD $INPUT"
  exit 0
fi

# Parse render options
THEME="$DEFAULT_THEME"
LAYOUT="$DEFAULT_LAYOUT"
SKETCH=""
OUTPUT=""
FORMAT="png"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)  THEME="$2"; shift 2 ;;
    --layout) LAYOUT="$2"; shift 2 ;;
    --sketch) SKETCH="-s"; shift ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --svg)    FORMAT="svg"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Derive output path
if [[ -z "$OUTPUT" ]]; then
  OUTPUT="${INPUT%.d2}.$FORMAT"
fi

# Render
"$D2" -t "$THEME" -l "$LAYOUT" --pad "$DEFAULT_PAD" $SKETCH "$INPUT" "$OUTPUT"

SIZE=$(stat --printf="%s" "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null)
echo "Rendered: $OUTPUT ($(( SIZE / 1024 ))KB)"
