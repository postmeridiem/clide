# Codebase Cleanliness & Pattern Audit

**Date:** 2026-05-26
**Scope:** `lib/` (314 files, ~2.1MB) and `pubspec.yaml`. Skipped `legacy/`, `tests/`, generated files. Conventions grounded in [`CLAUDE.md`](CLAUDE.md) guardrails and the [`governance/decisions/`](governance/decisions/) D-records (architecture, extensions, testing, tooling, process).

## Baseline health

- `dart format --set-exit-if-changed`: **468/468 files clean.**
- `flutter analyze`: **3 warnings, all in a single WIP file** (`lib/builtin/claude/src/session_orchestrator.dart`), already in the modified-but-uncommitted set:
  - L15: unused `dart:convert` import
  - L16: unused `dart:io` import
  - L29: unused private field `_resumeTailBytes`
- No `print(` / `debugPrint(` in `lib/`. No TODO / FIXME / HACK comments. No commented-out code blocks. No orphaned `.dart` files.

The repo is in unusually good baseline hygiene shape — the audit's interesting findings are structural, not janitorial.

## Guardrail / D-record compliance

| Decision | Status | Notes |
|---|---|---|
| **D-7** bare `WidgetsApp` | Pass | No `MaterialApp`/`CupertinoApp`/`Scaffold`/`ElevatedButton`. Material/Cupertino imports exist only in inlined xterm heritage under `lib/src/terminal/` and aren't instantiated. |
| **D-8** feature-first, barrels only | Pass | No cross-feature reach into another feature's `src/`. `lib/extension/src/` → `lib/kernel/src/` is the one cross-`src/` link (extension framework on platform foundation — legitimate). |
| **D-10** ChangeNotifier + ListenableBuilder | Pass | No provider/riverpod/bloc/get_it. Three `InheritedWidget` subclasses (`ScrollbarTheme`, `ClideKernel`, `ClideTheme` via `InheritedNotifier<ThemeController>`) are all justified scoped-context uses. |
| **D-31 / D-42** exact-pin + `licenses.yaml` | Pass | No caret ranges in `pubspec.yaml`. All 13 runtime deps + dev deps + native binaries documented. |
| **D-46** core frame vs shipped extensions | **Drift** | `editor`, `claude`, `claude-control`, `markdown`, `diff`, `git-ui`, `pql`, `canvas`, `graph`, `decisions`, `tickets`, `todos`, `problems` should be shipped extensions on a separate registration path. They still live in `lib/builtin/` alongside core frame builtins. Architectural intent documented but not enforced — migration deferred. |
| **D-56** single package, in-process IPC | Pass | No `bin/clide.dart`, no `app/`, no `sidecar/`. `lib/src/daemon/` is in-process dispatcher + handlers. |
| **D-1 / D-68** CLI primary, MCP secondary | Pass | `lib/src/ipc/server.dart` (unix socket) and `lib/src/ipc/mcp_server.dart` (HTTP+SSE) both wrap the same `DaemonDispatcher`. |
| **D-72** serial dispatch on main isolate | Pass | `server.dart:212` awaits `dispatcher.dispatch(req)` inside a per-client serial line handler. |
| **D-74** schema co-registered | Pass | `DaemonDispatcher` accepts `CommandSchema?` at registration (`dispatcher.dart:23`), validates pre-handler (L55–59). |
| **D-66** 95% coverage floor | Pass | `pubspec.yaml:26`: `coverage_floor: 95`. |
| **D-75 / D-77 / D-78** Claude coupling isolation | Pass | All `~/.claude/`, transcript JSONL, `claude` CLI invocations live behind `lib/builtin/claude/src/`. No leakage to other features. |
| **CLAUDE.md** in-house renderers | Pass | Markdown: pub.dev parser (per D-58) + custom renderer in `lib/widgets/src/clide_markdown.dart`. Canvas + graph in-house. |
| **Analyzer suppressions** | Pass | `// ignore`s are confined to xterm heritage code, FFI bindings (C naming), and lookup tables. All justified. |

## Findings worth acting on

### 1. Unused pubspec dependencies (D-31 violation in spirit)

- `flutter_widget_from_html_core: 0.17.2` — listed in `dependencies:`, imported nowhere. Mentioned in D-58 as adoptable, but no current consumer.
- `mocktail: 1.0.4` — listed in `dev_dependencies:`, imported nowhere. D-25 specifies it for IO mocks, but no tests use it today.

Per D-62 (Dependency removal process), removing requires the full 5-step PR. But carrying them violates D-31's "what stays is exact-pinned" intent — the spirit being "we keep only what we use."

### 2. D-46 architectural drift — known but uncodified

Thirteen "shipped extension" features still register through the core frame path. This is documented drift, not new — but it's the largest unresolved architectural debt. A dedicated `lib/extensions/` directory + a second registration tier is the prescribed fix.

### 3. Three hotspot files (>800 lines, mixed concerns)

| File | Lines | Shape |
|---|---|---|
| `lib/app.dart` | 1175 | 11+ State classes for sidebar/workspace/editor/context/status — split by region |
| `lib/src/terminal/src/core/escape/parser.dart` | 1139 | `EscapeParser` FSM, 1095-line class — handler logic could split by escape domain |
| `lib/src/terminal/src/terminal.dart` | 907 | `Terminal` class implementing 5 interfaces, 80+ methods spanning cursor/buffer/input/output |

The terminal pair is partially inlined heritage code (xterm.dart) so refactoring it competes with merge-friendliness; `app.dart` is yours to split freely.

### 4. Silent error swallowing in `lib/builtin/claude/src/claude_config.dart`

Seven `catch (_)` sites (L292, 301, 314, 394, 460, 489, 505) in config/skill loading. Config parsing failures vanish without log or UI signal. Per D-76 the service is supposed to "degrade gracefully" on parse miss — that's fine, but at minimum these should log to make schema drift visible (D-75 / D-78 explicitly call out that detection is the mitigation for CC-internals drift).

### 5. Long methods — theme resolvers and one claude config probe

| File:Line | Method | Lines |
|---|---|---|
| `lib/kernel/src/theme/resolver.dart:9` | `palette()` | 172 |
| `lib/kernel/src/theme/resolver.dart:11` | `semantic()` | 170 |
| `lib/kernel/src/theme/resolver.dart:13` | `surface()` | 168 |
| `lib/builtin/claude/src/claude_config.dart:306` | `_parseInitProbe()` | 178 |

Theme resolvers are dense token tables (data-shaped, not control-flow) — borderline but tolerable. The probe parser is the strongest splitting candidate.

### 6. Suspicious duplication

- `lib/builtin/tickets/src/tickets_view.dart` + `ticket_detail_view.dart` — 4+ near-identical `builder: (ctx, hovered, _) => ...` responsive button scaffolds. Extract a factory widget.

### 7. Magic strings worth a constant

- `'type': 'request' | 'response' | 'event'` recurs across `lib/src/ipc/envelope.dart` (L42, 79, 141). With two transports (socket + MCP) both speaking JSON envelopes, these belong as enum-or-const so a typo can't silently land.
- `lib/builtin/claude/src/transcript_reader.dart` (L477, 495, 498): `'user'`, `'assistant'`, `'permission-mode'` — strong candidates for an enum per the D-75 isolation principle (one place that knows the schema).

### 8. Coupling hub

`lib/main.dart` imports from 51 files — boot orchestrator, expected, but fragile. Splittable into `boot_kernel.dart` / `boot_ipc.dart` / `boot_ui.dart` if it grows further.

## What's notably *not* a problem

- No god-object utilities (`utils.dart`, `helpers.dart`, etc.) — feature-first discipline holds.
- No unchecked `as` casts — every cast is guarded by `is` or null-coalesce.
- No `dynamic` overuse outside legitimate JSON / Flutter API boundaries.
- Naming is uniformly Dart-idiomatic across 314 files.
- No deep control-flow nesting outside idiomatic `build()` trees.

## Recommended next moves

1. Land the three analyzer warnings in `session_orchestrator.dart` as part of the in-flight commit.
2. Decide on `flutter_widget_from_html_core` and `mocktail` — either wire them in or remove them via the D-62 process.
3. Open a tracking ticket for the D-46 migration if one doesn't exist; this is the only meaningful drift.
4. Split `app.dart` by layout region — lowest-risk, highest-readability win.
5. Add logging (not exception propagation) to the `claude_config.dart` silent catches so schema drift surfaces during real use.
6. Extract envelope type strings to constants/enum in `lib/src/ipc/envelope.dart` before the second transport (MCP) accumulates more divergence.

## Overall assessment

This is a tidy codebase. The audit found one architectural drift (D-46, already documented), three localized hotspots, two stale pubspec entries, and a handful of cosmetic improvements. Nothing systemic.
