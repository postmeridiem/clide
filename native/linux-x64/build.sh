#!/usr/bin/env bash
# Rebuild libtree-sitter.so from pinned sources inside a pinned manylinux_2_28
# container, so the library loads on any Linux with glibc 2.28 or newer (T-694).
# wasmtime is built from source here as well, not taken prebuilt (D-61).
# BUILD.md is the record of what this reproduces (D-63).
#
# Usage:  native/linux-x64/build.sh
#
# Writes libtree-sitter.so and build.log next to this script. It does not touch
# SHA256SUMS: re-record the hash in the same commit as the binary (BUILD.md).
# JOBS (default 4) caps the build's CPUs.
set -euo pipefail

IMAGE=quay.io/pypa/manylinux_2_28_x86_64@sha256:ae21cd1c8220f773f9b5934f3b845d677494d4cd4b8981c1e416f654e8afa74e
RUSTUP_INIT_URL=https://static.rust-lang.org/rustup/archive/1.28.2/x86_64-unknown-linux-gnu/rustup-init
RUSTUP_INIT_SHA256=20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c
RUST_VERSION=1.92.0
WASMTIME_TAG=v44.0.0
WASMTIME_COMMIT=af382d7d946b3de82db4bb1f6065b565f97446ae
TREE_SITTER_TAG=v0.26.8
TREE_SITTER_COMMIT=cd5b087cd9f45ca6d93ab1954f6b7c8534f324d2
GLIBC_FLOOR=2.28
JOBS="${JOBS:-4}"

# On the host: re-run this same file inside the container.
if [[ "${CLIDE_NATIVE_IN_CONTAINER:-}" != 1 ]]; then
  here="$(cd "$(dirname "$0")" && pwd)"
  exec docker run --rm \
    --cpus "$JOBS" \
    --user "$(id -u):$(id -g)" \
    -e CLIDE_NATIVE_IN_CONTAINER=1 \
    -e JOBS="$JOBS" \
    -v "$here:/out" \
    "$IMAGE" bash /out/build.sh
fi

# ---- inside the container -------------------------------------------------

export HOME=/tmp/home CARGO_HOME=/tmp/cargo RUSTUP_HOME=/tmp/rustup CARGO_BUILD_JOBS="$JOBS"
mkdir -p "$HOME" /tmp/build
cd /tmp/build
: >/out/build.log
record() { echo "$*" | tee -a /out/build.log; }

record "# libtree-sitter.so build log"
record "image: $IMAGE"
record "glibc: $(ldd --version | head -1)"
record "gcc: $(gcc --version | head -1)"
record "cmake: $(cmake --version | head -1)"

# Rust, from a hash-pinned rustup-init.
curl -fsSL "$RUSTUP_INIT_URL" -o rustup-init
echo "$RUSTUP_INIT_SHA256  rustup-init" | sha256sum --check --strict
chmod +x rustup-init
./rustup-init -y --no-modify-path --profile minimal --default-toolchain "$RUST_VERSION"
export PATH="$CARGO_HOME/bin:$PATH"
record "rustc: $(rustc --version)"

# Sources, pinned by commit: a moved tag fails the build.
fetch() {
  local name=$1 url=$2 tag=$3 commit=$4 got
  git clone --quiet --depth 1 --branch "$tag" "$url" "$name"
  got="$(git -C "$name" rev-parse HEAD)"
  if [[ "$got" != "$commit" ]]; then
    echo "$name: tag $tag is $got, expected $commit" >&2
    exit 1
  fi
  record "$name: $url @ $commit ($tag)"
}
fetch wasmtime https://github.com/bytecodealliance/wasmtime.git "$WASMTIME_TAG" "$WASMTIME_COMMIT"
fetch tree-sitter https://github.com/tree-sitter/tree-sitter.git "$TREE_SITTER_TAG" "$TREE_SITTER_COMMIT"

# wasmtime's C API as a static library. --locked holds every crate to
# wasmtime's own Cargo.lock. The libdir is explicit because RHEL-family images
# default it to lib64.
cmake -S wasmtime/crates/c-api -B wasmtime-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_LIBDIR=lib -DWASMTIME_USER_CARGO_BUILD_OPTIONS=--locked
cmake --build wasmtime-build -j "$JOBS"
cmake --install wasmtime-build --prefix /tmp/wasmtime
record "wasmtime: cmake -S crates/c-api -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_LIBDIR=lib -DWASMTIME_USER_CARGO_BUILD_OPTIONS=--locked && cmake --build && cmake --install"

# tree-sitter with the wasm feature, wasmtime linked in statically.
cmake -S tree-sitter -B ts-build \
  -DTREE_SITTER_FEATURE_WASM=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INCLUDE_PATH=/tmp/wasmtime/include \
  -DWASMTIME_LIBRARY=/tmp/wasmtime/lib/libwasmtime.a
cmake --build ts-build -j "$JOBS"
record "tree-sitter: cmake -S . -DTREE_SITTER_FEATURE_WASM=ON -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_INCLUDE_PATH=<wasmtime>/include -DWASMTIME_LIBRARY=<wasmtime>/lib/libwasmtime.a && cmake --build"

# The real file behind the libtree-sitter.so symlinks.
so="$(readlink -f ts-build/libtree-sitter.so)"
record "sha256 before strip: $(sha256sum "$so" | cut -d' ' -f1)"

# Ship it stripped. Debug info and the static symbol table are about a third
# of the unstripped size, and the loader needs only the dynamic symbols.
strip --strip-unneeded "$so"
record "strip: $(strip --version | head -1), --strip-unneeded"

# The point of this build: nothing newer than the floor.
need="$(objdump -T "$so" | grep -o 'GLIBC_[0-9.]*' | sed 's/^GLIBC_//' | sort -V | tail -1)"
if [[ "$(printf '%s\n' "$need" "$GLIBC_FLOOR" | sort -V | tail -1)" != "$GLIBC_FLOOR" ]]; then
  echo "libtree-sitter.so needs glibc $need; the floor is $GLIBC_FLOOR" >&2
  exit 1
fi
record "newest glibc symbol version: $need (floor $GLIBC_FLOOR)"
record "soname: $(objdump -p "$so" | awk '/SONAME/ {print $2}')"
record "exports: $(objdump -T "$so" | grep -c ' ts_wasm_') ts_wasm_*, $(objdump -T "$so" | grep '\.text' | grep -c ' ts_') ts_* in .text"

cp "$so" /out/libtree-sitter.so
record "size: $(stat -c %s /out/libtree-sitter.so)"
record "sha256: $(sha256sum /out/libtree-sitter.so | cut -d' ' -f1)"
