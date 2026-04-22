# libtree-sitter.so — vendored build record

## Status: PROVISIONAL — built locally, not yet CI

Built on contributor machine. CI-based reproducible build required before release.

## Source

- **Repository**: https://github.com/tree-sitter/tree-sitter
- **Version**: 0.26.8 (tag v0.26.8)
- **Commit**: cd5b087cd9f45ca6d93ab1954f6b7c8534f324d2
- **Clone**: `/var/mnt/data/projects/treesitter/tree-sitter/`

## Build command

```bash
cmake -B build \
  -DTREE_SITTER_FEATURE_WASM=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INCLUDE_PATH=/home/linuxbrew/.linuxbrew/include \
  -DWASMTIME_LIBRARY=/home/linuxbrew/.linuxbrew/lib/libwasmtime.a
cmake --build build -j$(nproc)
```

## Dependencies (statically linked)

- **wasmtime 44.0.0** — Apache-2.0 with LLVM exception
  - Source: Bytecode Alliance, installed via Homebrew
  - Linked statically (`libwasmtime.a`) so we ship one `.so`

## Toolchain

- **Compiler**: GCC 15.2.1 (Fedora 43)
- **Target**: x86_64-linux-gnu
- **CMake**: system

## Binary details

- **Size**: ~24 MB
- **Exports**: `ts_wasm_store_new`, `ts_wasm_store_delete`, `ts_wasm_store_load_language`, `ts_wasm_store_language_count`, plus full tree-sitter C API

## TODO before release

- [ ] Build in CI from pinned source SHA
- [ ] Record SHA-256 of output
- [ ] Cross-compile for macOS (aarch64, x86_64)
- [ ] Cross-compile for Windows (x86_64)
- [ ] Vendor wasmtime NOTICE file per POLICY.md Apache-2.0 rules
