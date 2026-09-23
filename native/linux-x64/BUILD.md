# libtree-sitter.so — vendored build record

## Status: scripted and reproducible, not yet built in CI

[`build.sh`](build.sh) produces this binary inside a digest-pinned
`manylinux_2_28` container, from the source commits pinned below. That
includes wasmtime, which the previous build took prebuilt from Homebrew.
Two clean runs produced the same bytes. [`build.log`](build.log) is the
record of the run that produced the committed binary.

D-63 wants rebuilds to run in CI. `build.sh` is the recipe a CI job runs;
wiring it into a workflow is T-25.

## glibc floor: 2.28

The library needs nothing newer than `GLIBC_2.28`, so it loads on RHEL and
AlmaLinux 8, Debian 10 and later, and Ubuntu 20.04 and later (T-694). The
previous binary, built on Fedora 43, needed 2.34. `make native-verify` fails
if a rebuild raises the floor.

## Sources

- **tree-sitter**
  - Repository: https://github.com/tree-sitter/tree-sitter
  - Tag `v0.26.8`, commit `cd5b087cd9f45ca6d93ab1954f6b7c8534f324d2`
  - Licence: MIT
- **wasmtime**
  - Repository: https://github.com/bytecodealliance/wasmtime
  - Tag `v44.0.0`, commit `af382d7d946b3de82db4bb1f6065b565f97446ae`
  - Licence: Apache-2.0 with LLVM exception ([`WASMTIME-LICENSE`](WASMTIME-LICENSE))
  - Its C API is built as a static library and linked in, so clide ships one `.so`.
  - Crates are held to wasmtime's own `Cargo.lock` (`--locked`).

The script checks each tag against its commit and fails the build if a tag
has moved. No patches are applied.

## Build

```bash
native/linux-x64/build.sh      # JOBS caps the CPUs; 4 by default
```

Inside the container, that runs:

```bash
# wasmtime C API, static
cmake -S wasmtime/crates/c-api -B wasmtime-build -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_LIBDIR=lib -DWASMTIME_USER_CARGO_BUILD_OPTIONS=--locked
cmake --build wasmtime-build
cmake --install wasmtime-build --prefix /tmp/wasmtime

# tree-sitter with the wasm feature
cmake -S tree-sitter -B ts-build \
  -DTREE_SITTER_FEATURE_WASM=ON -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INCLUDE_PATH=/tmp/wasmtime/include \
  -DWASMTIME_LIBRARY=/tmp/wasmtime/lib/libwasmtime.a
cmake --build ts-build
strip --strip-unneeded ts-build/libtree-sitter.so.0.26
```

## Toolchain

- **Container**: `quay.io/pypa/manylinux_2_28_x86_64@sha256:ae21cd1c8220f773f9b5934f3b845d677494d4cd4b8981c1e416f654e8afa74e` (AlmaLinux 8.10, glibc 2.28)
- **C compiler**: GCC 14.2.1 (gcc-toolset-14)
- **CMake**: 4.4.3
- **Rust**: 1.92.0, the minimum wasmtime 44 supports. Installed by `rustup-init` 1.28.2, which is checked against a pinned SHA-256.
- **Target**: x86_64-linux-gnu

## Binary

- **Size**: 37,033,328 bytes
  - The previous build was 24,948,416 bytes.
  - The difference is wasmtime's default C-API features, built from source: about 6.6 MB more code and 1.8 MB more unwind tables than Homebrew's archive.
  - The binary is stripped (`--strip-unneeded`). Unstripped, debug info and the static symbol table would add about 19 MB.
- **SONAME**: `libtree-sitter.so.0.26`
- **Exports**: `ts_wasm_store_new`, `ts_wasm_store_delete`, `ts_wasm_store_load_language` and `ts_wasm_store_language_count`, plus the full tree-sitter C API
- **SHA-256**: `a07053914c22e653bb8e18d9b1a268aa389f34aa4a42abb18f27145b3d991755`

The hash is recorded in [`SHA256SUMS`](SHA256SUMS), alongside `WASMTIME-LICENSE`. `make native-verify` checks it, together with the glibc floor. A rebuild re-records the hash there and here, in the same commit as the new binary.

## TODO before release

- [ ] Build in CI from the pinned sources (T-25); `build.sh` is the recipe
- [x] Record SHA-256 of output
- [x] Build wasmtime from source rather than a prebuilt archive
- [ ] Cross-compile for macOS (aarch64, x86_64)
- [ ] Cross-compile for Windows (x86_64)
- [ ] Vendor wasmtime NOTICE file per POLICY.md Apache-2.0 rules
