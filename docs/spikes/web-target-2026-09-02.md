# Web target: what actually happens, and what's between here and a usable one

**Date:** 2026-09-02 · **Build:** v2.12.0 · **Method:** `flutter build web --wasm`,
served on `localhost:4280`, loaded in Chrome, console + access log read.

Framing for this spike (from the request): **assume clide runs on the OS of the
hosting system and has project dirs to work in.** So the question is not "can a
browser spawn a PTY" — it can't, and never will. It is: *if a real host process
exists, what stands between today's tree and a browser front end for it?*

That reframing matters, because it changes most of the gaps from "impossible" to
"needs a transport".

## What happens today

The build **succeeds** — 93 MB, ~43 s. The D-100 compile fence holds.

Loaded in a browser, it gets meaningfully far:

1. WASM module loads and starts.
2. All bundled fonts load (Inter, Phosphor ×3, JetBrains Mono ×4, Fira Mono ×2).
3. All 12 theme YAMLs load.
4. i18n catalogs load, extensions register, `keymaps/default.yaml` loads.
5. **Then it throws** `Unsupported operation: _Namespace` and the app never paints.

`_Namespace` is `dart:io`'s filesystem layer, which has no web implementation.
Every occurrence is the same root cause: something touched a real path.

## Finding 1 — the fence has runtime holes, and the CI gate can't see them

D-100 fences `dart:ffi` behind conditional imports and adds a
`flutter build web --wasm` step "so the fence can't silently rot". That gate
proves the tree **compiles**. It cannot prove the tree **boots** — and those came
apart here.

Two holes found by actually running it:

- **`main.dart:114`** — `resolveWorkspaceRoot(Directory.current)` sits *six lines
  above* the `if (!kIsWeb)` guard that protects everything after it. Constructing
  a `Directory` is inert on web; *resolving* one is not. Fixed in this spike
  (one line, `kIsWeb ? Directory('/clide-web-no-disk') : …`), which took the boot
  from step 3 to step 5 above.
- **A second `_Namespace`** during extension activation, after the builtin i18n
  catalogs register. Not chased — chasing it is the port, not the survey.
  Twelve files on the activation path call `existsSync` / `createSync` /
  `listSync` / `readAsStringSync`:
  `terminal_pane`, `conversation_view`, `path_preset_control`, `agent_bootstrap`,
  `account_registry`, `claude_pane`, `claude_config`, `cli_install`, `watchdog`,
  `toolchain_paths`, `file_log_sink`, `tree_sitter_ffi`.

This is a **D-108 case in the wild**: the wasm gate is a negative check — "it
didn't fail to compile" — and compiling got mistaken for working. A gate that
booted the bundle and asserted first paint would have caught both holes on the
day they landed. See "Recommended next step".

## Finding 2 — there is no transport on web, by construction

`main.dart:561` passes `daemonClientFactory: kIsWeb ? null : …`.

On web there is **no IPC client at all**. Even with every `_Namespace` hole
plugged, the UI would paint and then do nothing: `files.read`, `git.status`,
`pql`, the Claude session — every subsystem call has nowhere to go. Today's
transport is a Unix domain socket (D-70/D-72), which a browser cannot open.

This is the real work, and it is not a bug — it is an absent layer.

## Finding 3 — the console is loud before anything is wrong

The i18n fallback chain probes `assets/i18n/en/<ns>.json` before `en_us`, so a
clean boot emits ~20 × (404 + a red engine error) before resolving correctly.
Harmless, and invisible on desktop where nothing logs the miss — but on web it
buries real errors in noise, which is exactly when you least want that. Cheap to
fix by resolving the chain against the manifest rather than by probing.

## What it would take

Ordered by what unblocks the most.

### 1. A transport the browser can speak (the load-bearing one)

The dispatcher already speaks a clean request/response envelope over a socket.
A WebSocket peer serving the *same* `IpcRequest`/`IpcResponse` envelope would let
the existing `DaemonClient` interface stand, with only the connection swapped.
The `_argv` unwrap, the schema layer and every handler stay untouched.

Non-trivial parts: auth (a browser tab is not a trusted local process),
workspace selection (no `Directory.current` to infer from), and the event stream
(`clide tail --events` is already a streaming socket mode, so the shape exists).

### 2. The execution seam — **already scoped as T-399**

Everything that calls `Process.run` or `File` directly has to go behind an
injectable seam so the web build can route it to the host instead. That is
verbatim the SSH-remote epic's **T-399: "RemoteExecutionContext seam —
subsystems stop calling `Process.run`/`File` directly."**

**The web port and SSH-remote workspaces are the same refactor.** T-336's fork
(T-398 SSH connection manager, T-399 the seam, T-400 remote PTY, T-401 polling
watcher, T-402 preflight) is ~80% of a web backend with a different pipe on the
end. Doing them independently would be building the same seam twice.

### 3. Per-subsystem degrade decisions

With a seam and a transport, each subsystem is a separate call, not one flag:

| Subsystem | With a host behind it | Notes |
|---|---|---|
| files / git / pql | Works over the transport | Pure request/response already |
| editor | Works | Buffers are server-side state today |
| Claude session | Works | stdout streaming is already a stream |
| terminal / PTY | Works if the host owns the PTY | `xterm.dart` renders fine in a browser; only the *spawn* is native |
| tree-sitter | Needs a decision | Native FFI today; either server-side highlight or a wasm grammar build |
| Lua extensions | Needs a decision | Same shape as tree-sitter |

Note that with the seam, the terminal is **not** a blocker. D-100's "no
PTY/terminal on web" is true of a standalone browser build, not of a browser
front end to a host that owns the pty.

## Recommended next step

Not "port it". Two cheap things that stop the target rotting, then a decision:

1. **Plug the two `_Namespace` holes** and make the CI web job *boot* the bundle
   and assert first paint, not merely compile it. The Playwright harness for this
   already exists (`tools/ui/`, D-26) and is already ticketed as **T-443**; it is
   currently dead — the browser isn't even installed locally. A booting gate is
   what makes D-100's "can't silently rot" true rather than aspirational.
2. **Quieten the i18n probe**, so the console is readable when something breaks.
3. **Decide whether the web target is a UI/e2e surface (D-100 as written) or a
   real front end.** If the latter, sequence it *behind* T-399 and take the seam
   once. That is a product call, not an implementation one.

## Honest scope note

Everything above is from one build, one browser, one boot, plus reading the
tree. Not verified: whether the app paints anything after the second
`_Namespace` is plugged, how CanvasKit vs Skwasm performs on the conversation
view, and whether the 93 MB bundle is acceptable over a network. The
`SharedArrayBuffer` COOP/COEP headers the serve script mentions are also still
missing, so Skwasm's threaded path is untested.
