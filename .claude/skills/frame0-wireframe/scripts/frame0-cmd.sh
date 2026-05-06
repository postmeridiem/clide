#!/bin/bash
set -euo pipefail

PORT="${FRAME0_PORT:-58320}"
ENDPOINT="http://localhost:${PORT}/execute_command"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args...] [--port N]

Low-level Frame0 HTTP API wrapper. Replaces the MCP server with direct
curl calls. Requires Frame0 desktop app to be running.

Commands:
  health                              Check if Frame0 is running
  exec <namespace:action> <json>      Execute a raw API command
  create-shape <type> <json-props>    Create a shape (Rectangle, Ellipse, Text, Line)
  get-shape <id>                      Get shape details
  update-shape <id> <json-props>      Update shape properties
  delete <id> [id...]                 Delete shapes by ID
  move <id> <dx> <dy>                 Move a shape by pixel offset
  duplicate <id>                      Duplicate a shape
  group <id> [id...]                  Group shapes
  ungroup <group-id>                  Ungroup a group
  create-connector <tail-id> <head-id> [json-props]  Connect two shapes
  create-icon <name> <json-props>     Create an icon shape
  add-page <name>                     Add a new page (becomes current)
  get-page [page-id]                  Get current or specific page data
  list-pages [--shapes]               List all pages (--shapes for shape data)
  current-page                        Get current page ID
  set-page <page-id>                  Set current page
  export [page-id] [--format mime]    Export page as image (default: image/png)
  fit                                 Fit view to screen

Options:
  --port N    Frame0 API port (default: $PORT, env: FRAME0_PORT)

Examples:
  $(basename "$0") health
  $(basename "$0") add-page "HUD Layout"
  $(basename "$0") create-shape Rectangle '{"name":"btn","left":100,"top":100,"width":120,"height":36}'
  $(basename "$0") list-pages
  $(basename "$0") export --format image/png
EOF
  exit 1
}

# Parse --port from anywhere in args
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port) PORT="$2"; ENDPOINT="http://localhost:${PORT}/execute_command"; shift 2 ;;
    *)      ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

[[ $# -lt 1 ]] && usage

# Execute a Frame0 API command, return data or error
frame0_exec() {
  local command="$1"
  local args
  args="${2:-"{}"}"

  local response
  response=$(curl -s -w "\n%{http_code}" -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{\"command\": \"$command\", \"args\": $args}" 2>&1) || {
    echo "ERROR: Cannot connect to Frame0 at localhost:$PORT" >&2
    echo "Is Frame0 running? See: .claude/skills/frame0-wireframe/references/setup-guide.md" >&2
    return 1
  }

  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" != 2* ]]; then
    echo "ERROR: HTTP $http_code from Frame0" >&2
    echo "$body" >&2
    return 1
  fi

  # Parse success/error from response
  python3 -c "
import sys, json
try:
    r = json.loads(sys.stdin.read())
    if r.get('success'):
        d = r.get('data')
        if d is not None:
            print(json.dumps(d, indent=2))
    else:
        print('ERROR: ' + str(r.get('error', 'Unknown error')), file=sys.stderr)
        sys.exit(1)
except json.JSONDecodeError as e:
    print(f'ERROR: Invalid JSON response: {e}', file=sys.stderr)
    sys.exit(1)
" <<< "$body"
}

# Build JSON array from remaining args
ids_to_json_array() {
  local arr="["
  local first=true
  for id in "$@"; do
    [[ "$first" == true ]] && first=false || arr+=","
    arr+="\"$id\""
  done
  arr+="]"
  echo "$arr"
}

CMD="${1:-}"
shift || true

case "$CMD" in
  health)
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/" 2>/dev/null | grep -q "^[23]"; then
      echo "Frame0 is running on port $PORT"
    else
      echo "Frame0 is NOT running on port $PORT" >&2
      echo "Start Frame0 desktop app, then retry." >&2
      echo "See: .claude/skills/frame0-wireframe/references/setup-guide.md" >&2
      exit 1
    fi
    ;;

  exec)
    [[ $# -lt 2 ]] && { echo "Usage: exec <command> <json-args>" >&2; exit 1; }
    frame0_exec "$1" "$2"
    ;;

  create-shape)
    [[ $# -lt 2 ]] && { echo "Usage: create-shape <Type> <json-props>" >&2; exit 1; }
    local_type="$1"
    local_props="$2"
    local_parent="${3:-}"
    local_parent_arg=""
    [[ -n "$local_parent" ]] && local_parent_arg=", \"parentId\": \"$local_parent\""
    frame0_exec "shape:create-shape" "{\"type\": \"$local_type\", \"shapeProps\": $local_props$local_parent_arg, \"convertColors\": true}"
    ;;

  get-shape)
    [[ $# -lt 1 ]] && { echo "Usage: get-shape <id>" >&2; exit 1; }
    frame0_exec "shape:get-shape" "{\"shapeId\": \"$1\"}"
    ;;

  update-shape)
    [[ $# -lt 2 ]] && { echo "Usage: update-shape <id> <json-props>" >&2; exit 1; }
    frame0_exec "shape:update-shape" "{\"shapeId\": \"$1\", \"shapeProps\": $2, \"convertColors\": true}"
    ;;

  delete)
    [[ $# -lt 1 ]] && { echo "Usage: delete <id> [id...]" >&2; exit 1; }
    local_arr=$(ids_to_json_array "$@")
    frame0_exec "edit:delete" "{\"shapeIdArray\": $local_arr}"
    ;;

  move)
    [[ $# -lt 3 ]] && { echo "Usage: move <id> <dx> <dy>" >&2; exit 1; }
    frame0_exec "shape:move" "{\"shapeId\": \"$1\", \"dx\": $2, \"dy\": $3}"
    ;;

  duplicate)
    [[ $# -lt 1 ]] && { echo "Usage: duplicate <id> [dx] [dy]" >&2; exit 1; }
    local_dx="${2:-0}"
    local_dy="${3:-0}"
    frame0_exec "edit:duplicate" "{\"shapeIdArray\": [\"$1\"], \"dx\": $local_dx, \"dy\": $local_dy}"
    ;;

  group)
    [[ $# -lt 2 ]] && { echo "Usage: group <id> <id> [id...]" >&2; exit 1; }
    local_arr=$(ids_to_json_array "$@")
    frame0_exec "shape:group" "{\"shapeIdArray\": $local_arr}"
    ;;

  ungroup)
    [[ $# -lt 1 ]] && { echo "Usage: ungroup <group-id>" >&2; exit 1; }
    frame0_exec "shape:ungroup" "{\"shapeIdArray\": [\"$1\"]}"
    ;;

  create-connector)
    [[ $# -lt 2 ]] && { echo "Usage: create-connector <tail-id> <head-id> [json-props]" >&2; exit 1; }
    local_props="${3:-{}}"
    frame0_exec "shape:create-connector" "{\"tailId\": \"$1\", \"headId\": \"$2\", \"shapeProps\": $local_props, \"convertColors\": true}"
    ;;

  create-icon)
    [[ $# -lt 2 ]] && { echo "Usage: create-icon <name> <json-props>" >&2; exit 1; }
    frame0_exec "shape:create-icon" "{\"iconName\": \"$1\", \"shapeProps\": $2, \"convertColors\": true}"
    ;;

  add-page)
    [[ $# -lt 1 ]] && { echo "Usage: add-page <name>" >&2; exit 1; }
    frame0_exec "page:add" "{\"pageProps\": {\"name\": \"$1\"}}"
    ;;

  get-page)
    if [[ $# -ge 1 ]]; then
      frame0_exec "page:get" "{\"pageId\": \"$1\", \"exportShapes\": true}"
    else
      local_id
      local_id=$(frame0_exec "page:get-current-page")
      # Strip quotes from returned ID
      local_id=$(echo "$local_id" | tr -d '"')
      frame0_exec "page:get" "{\"pageId\": \"$local_id\", \"exportShapes\": true}"
    fi
    ;;

  list-pages)
    local_shapes="false"
    [[ "${1:-}" == "--shapes" ]] && local_shapes="true"
    frame0_exec "doc:get" "{\"exportPages\": true, \"exportShapes\": $local_shapes}"
    ;;

  current-page)
    frame0_exec "page:get-current-page"
    ;;

  set-page)
    [[ $# -lt 1 ]] && { echo "Usage: set-page <page-id>" >&2; exit 1; }
    frame0_exec "page:set-current-page" "{\"pageId\": \"$1\"}"
    ;;

  export)
    local_page_id=""
    local_format="image/png"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --format) local_format="$2"; shift 2 ;;
        *) local_page_id="$1"; shift ;;
      esac
    done
    local_page_arg=""
    [[ -n "$local_page_id" ]] && local_page_arg="\"pageId\": \"$local_page_id\", "
    frame0_exec "file:export-image" "{${local_page_arg}\"format\": \"$local_format\", \"fillBackground\": true}"
    ;;

  fit)
    frame0_exec "view:fit-to-screen"
    ;;

  --help|-h|help)
    usage
    ;;

  *)
    echo "Unknown command: $CMD" >&2
    usage
    ;;
esac
