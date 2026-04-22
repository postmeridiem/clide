#!/usr/bin/env bash
# Compile tree-sitter core + each grammar + bridge.c into self-contained
# WASM modules.  Requires wasi-sdk (cached by `tree-sitter build --wasm`).
#
# Usage:
#   ./tools/ts-wasm/build.sh              # build all grammars
#   ./tools/ts-wasm/build.sh dart rust    # build specific grammars
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

WASI_SDK="${WASI_SDK:-$HOME/.cache/tree-sitter/wasi-sdk}"
TS_CORE="${TS_CORE:-/var/mnt/data/projects/treesitter/tree-sitter}"
GRAMMARS_ROOT="${GRAMMARS_ROOT:-/var/mnt/data/projects/treesitter}"
OUT_DIR="$REPO_ROOT/app/assets/grammars"
QUERIES_DIR="$REPO_ROOT/app/assets/queries"

CC="$WASI_SDK/bin/clang"
CXX="$WASI_SDK/bin/clang++"
SYSROOT="$WASI_SDK/share/wasi-sysroot"

CFLAGS=(
  --sysroot="$SYSROOT"
  --target=wasm32-wasip1
  -O2 -flto
  -fno-exceptions
  -I"$TS_CORE/lib/include"
  -I"$TS_CORE/lib/src"
  -DTREE_SITTER_HIDE_SYMBOLS
)

LDFLAGS=(
  -Wl,--no-entry
  -Wl,--export=init
  -Wl,--export=set_query
  -Wl,--export=parse_and_highlight
  -Wl,--export=capture_count
  -Wl,--export=capture_name
  -Wl,--export=ts_alloc
  -Wl,--export=ts_dealloc
  -Wl,--export=__heap_base
  -Wl,--strip-all
  -Wl,--gc-sections
)

mkdir -p "$OUT_DIR" "$QUERIES_DIR"

# Grammar source-dir resolution.  Multi-grammar repos (markdown, php,
# typescript, xml) nest the actual grammar under a subdirectory.
grammar_src_dir() {
  local name="$1" base="$GRAMMARS_ROOT/tree-sitter-$name"
  # Multi-grammar repos: check for a nested dir matching the grammar name.
  for sub in "$base/$name" "$base/tree-sitter-$name"; do
    [ -f "$sub/src/parser.c" ] && echo "$sub" && return
  done
  # Fallback: repo root.
  [ -f "$base/src/parser.c" ] && echo "$base" && return
  echo >&2 "error: no parser.c for $name"; return 1
}

# Derive the C function name (tree_sitter_<id>) from parser.c.
grammar_fn_name() {
  grep -oP 'TSLanguage \*\K(tree_sitter_\w+)(?=\(void\))' "$1/src/parser.c" | head -1
}

# Find highlight queries, preferring the grammar's own queries/ dir.
copy_queries() {
  local name="$1" src_dir="$2"
  # Try grammar-specific queries first, then repo-level.
  local q=""
  for candidate in \
      "$src_dir/queries/highlights.scm" \
      "$GRAMMARS_ROOT/tree-sitter-$name/queries/highlights.scm" \
      "$GRAMMARS_ROOT/tree-sitter-$name/queries/$name/highlights.scm" \
      "$GRAMMARS_ROOT/tree-sitter-$name/queries-src/highlights.scm"; do
    [ -f "$candidate" ] && q="$candidate" && break
  done
  [ -n "$q" ] && cp "$q" "$QUERIES_DIR/$name.scm" || true
}

build_grammar() {
  local name="$1"
  local src_dir; src_dir="$(grammar_src_dir "$name")" || return 1
  local fn; fn="$(grammar_fn_name "$src_dir")"
  [ -z "$fn" ] && echo >&2 "error: can't find function name for $name" && return 1

  local c_sources=( "$SCRIPT_DIR/bridge.c" "$TS_CORE/lib/src/lib.c" "$src_dir/src/parser.c" )
  local cxx_sources=()

  # Add external scanner.
  if [ -f "$src_dir/src/scanner.c" ]; then
    c_sources+=( "$src_dir/src/scanner.c" )
  fi
  if [ -f "$src_dir/src/scanner.cc" ]; then
    cxx_sources+=( "$src_dir/src/scanner.cc" )
  fi

  local mem; mem="$(free -h | awk '/Mem:/{print $3" used / "$7" avail"}')"
  echo "  $name  ($fn)  [$mem]"

  local tmpdir; tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" RETURN

  # Drop -flto for C++ grammars — wasm-ld LTO on C++ eats 20 GB+.
  local compile_flags=("${CFLAGS[@]}")
  if [ ${#cxx_sources[@]} -gt 0 ]; then
    compile_flags=("${compile_flags[@]/-flto/}")
  fi

  # Compile C sources.
  local objs=()
  local i=0
  for src in "${c_sources[@]}"; do
    $CC "${compile_flags[@]}" -DGRAMMAR_FN="$fn" -I"$src_dir/src" \
      -c "$src" -o "$tmpdir/$i.o" 2>&1
    objs+=( "$tmpdir/$i.o" )
    i=$((i + 1))
  done

  # Compile C++ sources (if any).
  for src in "${cxx_sources[@]}"; do
    $CXX "${compile_flags[@]}" -DGRAMMAR_FN="$fn" -I"$src_dir/src" \
      -fno-rtti -c "$src" -o "$tmpdir/$i.o" 2>&1
    objs+=( "$tmpdir/$i.o" )
    i=$((i + 1))
  done

  # Link.
  local linker="$CC"
  [ ${#cxx_sources[@]} -gt 0 ] && linker="$CXX"
  $linker "${compile_flags[@]}" "${objs[@]}" "${LDFLAGS[@]}" \
    -o "$OUT_DIR/$name.wasm" 2>&1

  copy_queries "$name" "$src_dir"
}

# Determine which grammars to build.
if [ $# -gt 0 ]; then
  targets=("$@")
else
  targets=()
  for d in "$GRAMMARS_ROOT"/tree-sitter-*/; do
    g="$(basename "$d" | sed 's/^tree-sitter-//')"
    targets+=("$g")
  done
fi

echo "Building ${#targets[@]} grammars..."
failed=()
for g in "${targets[@]}"; do
  if ! build_grammar "$g"; then
    failed+=("$g")
  fi
done

echo ""
echo "Built $((${#targets[@]} - ${#failed[@]})) / ${#targets[@]} grammars."
if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed: ${failed[*]}"
  exit 1
fi
