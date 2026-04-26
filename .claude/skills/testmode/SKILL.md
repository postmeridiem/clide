---
name: testmode
description: >
  Run and interpret the ClideTestApp platform integration harness.
  Use after modifying toolchain resolution, IPC dispatch, extension
  lifecycle, theme loading, or native platform code. Also use when
  the user says "run testmode", "test the app", "smoke test", or
  "verify the build". Triggers on changes to: lib/kernel/src/toolchain.dart,
  lib/src/daemon/dispatcher.dart, lib/src/ipc/, lib/extension/,
  lib/kernel/src/theme/, lib/builtin/*/src/extension.dart,
  linux/CMakeLists.txt, macos/, Makefile (run targets), lib/main.dart.
---

# Testmode harness

`ClideTestApp` is a lightweight Flutter app that boots the real platform
layer, runs structured tests, prints results, and exits. It catches
regressions that unit tests cannot see: missing binaries, broken
subprocess wiring, IPC dispatch failures, extension activation order,
and theme parse errors.

## Running

```bash
make run-testmode                             # all categories, 60s timeout
make run-testmode TESTMODE_CATEGORY=toolchain
make run-testmode TESTMODE_CATEGORY=ipc
make run-testmode TESTMODE_CATEGORY=extensions
make run-testmode TESTMODE_TIMEOUT=120        # longer timeout for slow builds
```

Results go to stdout **and** `/tmp/clide-testmode.log`. The last line
of testmode output is machine-readable:

```
[testmode:json] {"passed":33,"failed":0,"total":33,"failures":[]}
```

Exit code is non-zero when any test fails. The Makefile verifies
`"failed":0` in the log via `grep -q`.

## When to run which category

| Changed area | Category | Why |
|---|---|---|
| Toolchain, PATH, dugite, ptyc, shell | `toolchain` | Binary resolution + exec |
| IPC envelope, dispatcher, schema | `ipc` | Round-trip + error contract |
| Extension manifest, activate, contributions | `extensions` | Register + activate lifecycle |
| Theme YAML, loader, palette | `extensions` | Theme parse is in this category |
| Platform config (CMakeLists, pbxproj, Makefile) | `all` | Full rebuild validates everything |
| Any doubt | `all` | ~30s, cheap insurance |

## Interpreting output

- `[testmode] exec | ... | OK` — subprocess ran, exit 0 or 1.
- `[testmode] PASS | ...` — assertion passed (IPC / extension tests).
- `[testmode] FAIL | ...` — assertion failed. The output column says why.
- `[testmode] exec | ... | EXCEPTION` — binary not found or not executable.
- `[testmode] exec | ... | TIMEOUT` — subprocess hung (5s limit).

If the app never prints `[testmode]` lines, the testmode gate in
`main.dart` didn't fire — check that `CLIDE_TESTMODE` is set to a
non-empty string (not a bare bool).

## Adding tests

All test logic lives in `lib/test_app.dart`. Pattern:

```dart
// In the appropriate _run*Tests method:
await _testExec('label', binary, ['args'], workDir);
// or
_addResult('label', boolCondition, 'detail string');
```

New categories: add a `runFoo` bool from the `category` string,
gate a new `_runFooTests` method, and add the category name to
the Makefile help comment and this skill's table above.

Extension tests must include transitive dependencies — e.g.
`GitExtension` requires `DiffExtension` to activate first.

## Source files

- `lib/test_app.dart` — all test logic and UI
- `lib/main.dart:54` — testmode gate (`String.fromEnvironment`)
- `Makefile:42–56` — `run-testmode` target with category variable
