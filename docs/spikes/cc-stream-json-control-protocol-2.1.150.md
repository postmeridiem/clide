# Spike: Claude Code stream-json control protocol (T-165 / T-166)

**Pinned to:** claude **2.1.150**. Undocumented, version-drifting internal contracts
(per D-75/D-77) — re-validate on a CC bump, keyed off the transcript/event `version`
field and `claude_code_version` in the `init` event.

**Method:** drove the real `claude` binary as a subprocess over stdin/stdout
(`docs/spikes/` driver scripts were throwaway; the captured logs are the source of
truth) **and** read the shipped implementation directly — the CLI is a ~238 MB node
SEA at `~/.local/share/claude/versions/2.1.150`; `strings` on it exposes the zod
schemas and the request/response builders. Every shape below was confirmed live
(a real prompt round-tripped) unless marked otherwise. Cost a handful of paid turns.

---

## 0. TL;DR for the implementation

Spawn:

```
claude --input-format stream-json --output-format stream-json --verbose \
       --permission-prompt-tool stdio  [ --resume <id> | --session-id <id> ]
```

- **`--permission-prompt-tool stdio` is mandatory** to receive permission prompts.
  Without it, any tool that resolves to "ask" is **auto-denied** (no prompt reaches
  the client) — confirmed: a `Write` came back as `permission_denials` + an
  `is_error` tool_result "you haven't granted it yet", never a control request.
  `stdio` is a hidden value (not in `--help`); the SDK uses it (`f.sdkUrl?"stdio":…`).
- Read stdout as line-delimited JSON. Most lines are normal stream events
  (`system`/`assistant`/`user`/`result`/`rate_limit_event`); some are
  `control_request`s you **must answer** or Claude hangs.
- Send a prompt as `{"type":"user","message":{"role":"user","content":"…"}}`.
  stream-json does **not** echo your user messages back unless
  `--replay-user-messages` — local-echo them yourself.

---

## 1. Output event stream (stdout)

One JSON object per line. Types seen:

- `system`/`subtype:"hook_started"|"hook_progress"|"hook_response"` — session hooks
  (e.g. SessionStart). Informational; ignore for rendering.
- `system`/`subtype:"init"` — **the config goldmine.** Carries `session_id`, `cwd`,
  `model` (`claude-opus-4-7[1m]`), `permissionMode`, `tools[]`, `mcp_servers[]`,
  `slash_commands[]`, `skills[]`, `agents[]`, `output_style`, `claude_code_version`,
  `apiKeySource`, `plugins[]`. (This is a strong source for `ClaudeConfig` / status.)
- `assistant` — `{message:{model,id,content:[…],usage:{…}}, uuid, session_id, request_id}`.
  **Content blocks are emitted as separate `assistant` events sharing one `message.id`**
  (e.g. a `text` block, then a `tool_use` block). Block shapes are identical to the
  transcript: `text` / `thinking` (+`signature`) / `tool_use`(`id`,`name`,`input`).
  `message.usage` carries `input_tokens` + `cache_read_input_tokens` +
  `cache_creation_input_tokens` (→ context-token count).
- `user` — two flavours: (a) **tool results** Claude received —
  `message.content:[{type:"tool_result",tool_use_id,content,is_error}]` plus a
  top-level `tool_use_result`; (b) **harness-injected user messages** — a skill
  load (`Skill` tool → text begins `"Base directory for this skill:"`), a
  slash-command expansion, or a system reminder. Injected ones carry
  **`isSynthetic: true`** at the top level (the transcript uses `isMeta`
  instead). Verified by boundary test: the inject only appears once the `Skill`
  tool is actually invoked (it's auto-allowed, no prompt); if Claude just runs a
  command inferred from the slash text, no inject is emitted. clide flags these
  (`UserMessage.injected`) and renders them as a muted, collapsed "context"
  card, not a blue "you" message.
- `result` — terminal turn summary: `result` (final text), `usage`, `total_cost_usd`,
  `permission_denials[]`, `num_turns`, **`modelUsage.<model>.contextWindow`** (e.g.
  `1000000`) **and `maxOutputTokens`** — i.e. the context-window *size* IS exposed
  here (relevant to the T-158 budget gap; the remaining-budget % still is not).
- `rate_limit_event` — `{rate_limit_info:{status,resetsAt,rateLimitType,…}}`.

The existing `parseTranscriptChunk` (transcript_reader.dart) parses the
`assistant`/`user` events as-is (same `message.content` shapes; missing
`uuid`/`timestamp` default harmlessly). Permission mode comes from `init`, not a
`permission-mode` record.

## 2. Control protocol (bidirectional, same stdin/stdout)

### Envelope
Claude → client:
```json
{"type":"control_request","request_id":"<uuid>","request":{"subtype":"…", …}}
```
Client → Claude (the reply):
```json
{"type":"control_response","response":{"subtype":"success","request_id":"<uuid>","response":{…}}}
```
On failure use `{"subtype":"error","request_id":"…","error":"…"}`. **`request_id`
must echo exactly.** An unanswered `control_request` hangs the turn.

### `can_use_tool` (the permission ask) — confirmed live
Request:
```json
{"type":"control_request","request_id":"70c8…","request":{
  "subtype":"can_use_tool","tool_name":"Write","display_name":"Write",
  "input":{"file_path":"…","content":"…"},
  "description":"banana.txt",
  "permission_suggestions":[{"type":"setMode","mode":"acceptEdits","destination":"session"}],
  "tool_use_id":"toolu_…"}}
```
**ALLOW** — `updatedInput` is **required** (a bare `{"behavior":"allow"}` is rejected
with a ZodError: *"updatedInput: expected record, received undefined"*). Echo the
`input` back unchanged to allow as-is, or modify it to alter the call:
```json
{"type":"control_response","response":{"subtype":"success","request_id":"70c8…",
  "response":{"behavior":"allow","updatedInput":{ …the tool input… }}}}
```
**DENY** — `message` is required:
```json
{"type":"control_response","response":{"subtype":"success","request_id":"70c8…",
  "response":{"behavior":"deny","message":"User declined."}}}
```
(Decision zod union also allows optional `updatedPermissions` on allow.)

### AskUserQuestion — confirmed live (the non-obvious one)
AskUserQuestion is **not** answered with a `tool_result` (that path is rejected as a
dismissal — it even shows up in `permission_denials`). It is **permission-gated and
answered through the same `can_use_tool` channel**. Its `input` is exactly clide's
own AskUserQuestion shape:
`{questions:[{question,header,multiSelect,options:[{label,description}]}]}`.
Return the user's choice by injecting an **`answers` map into `updatedInput`**:
`answers : record(question-text → chosen-label)` (multi-select = comma-separated labels).
```json
{"behavior":"allow","updatedInput":{
   "questions":[ …echoed… ],
   "answers":{"Do you prefer cats or dogs?":"Dogs"}}}
```
Confirmed: Claude then reported *"You chose Dogs"*; the resulting tool_use_result was
`{questions:[…],answers:{"Do you prefer cats or dogs?":"Dogs"}}`. Leaving `answers`
empty makes Claude say "your selection didn't come through".

### Other `control_request` subtypes (from the binary's zod schemas)
Client→Claude requests it accepts: `initialize`, `interrupt`,
`set_permission_mode {mode}`, `mcp_message {server_name,message}`.
Claude→client requests you may receive: `can_use_tool`, `hook_callback
{callback_id,input,tool_use_id?}`. **Answer every inbound control_request** (even
unknown subtypes — reply `error` "Unsupported…") or the turn stalls. There is also a
`control_cancel_request` for in-flight cancellation.

### `initialize` handshake — optional, but a config goldmine
Sending it first is **not** what enables permissions (the `stdio` flag does that —
verified: initialize-then-Write was still auto-denied). But the response is rich:
```json
// → {"type":"control_request","request_id":"init-1","request":{"subtype":"initialize","hooks":{},"sdkMcpServers":[]}}
// ← response.response = {commands:[{name,description,argumentHint,aliases?}…],
//      agents:[…], models:[…], output_style, available_output_styles,
//      account:{email,organization,subscriptionType,apiProvider}, pid}
```
`commands[]` carries **descriptions + argumentHints** the `init` event's bare
`slash_commands[]` lacks — better source for the typeahead (T-152) and ClaudeConfig.

## 3. Implications for the tickets
- **T-165:** spawn with the flags in §0; feed `parseTranscriptChunk` from the
  `assistant`/`user` events; pull `permissionMode`/`model` from `init`; local-echo
  user sends. Isolate all protocol framing in one module (drift-containment, D-77).
- **T-166:** wire `can_use_tool` → native prompt card (allow/deny, using
  `display_name`/`description`/`permission_suggestions`); AskUserQuestion → option
  picker, returning `updatedInput.answers`. Answer **every** control_request.
- **ClaudeConfig (D-76):** prefer the `initialize` response's `commands[]` (has
  descriptions) over the `init` `slash_commands[]`.

## 4. MCP vs the control channel — which layer does what
These are **complementary, not competing** — a recurring point of confusion:
- **The conversation + permissions + AskUserQuestion ride the stream-json control
  channel** (`can_use_tool` over stdin/stdout). This is the SDK-blessed transport and
  what `canUseTool` maps to. T-165/T-166 use it. **MCP is not involved here.**
- **MCP is how you give Claude extra *tools/capabilities*.** That's exactly what the
  VSCode/JetBrains extensions do: they host an MCP *server* exposing IDE features to
  Claude (`mcp__ide__getDiagnostics`, `mcp__ide__executeCode`, openDiff) — they do
  **not** route the conversation or permissions through MCP; permissions still go
  through the CLI/control channel. D-77's clide-hosted MCP broker (T-170) is the same
  idea: provide team messaging / task-sync tools to the agents.
- **One overlap exists:** `--permission-prompt-tool` accepts *either* the special
  `stdio` value (control channel — what we use) *or* an **MCP tool name** (Claude
  calls your MCP tool to get the allow/deny). So permissions *could* be routed through
  MCP — but it's strictly more machinery than `stdio`, needs a server, and loses the
  structured `permission_suggestions`/`display_name` the control request carries.
  **Recommendation: keep permissions on `stdio`; reserve MCP for capability/tool
  provision (IDE context later, the team broker in T-170).**

## 5. Resilience — the stdio channel is brittle; the fallback menu (no empty slate)
**Decision (this spike):** carry the conversation + permissions + AskUserQuestion on
the **stdio control channel** (`--permission-prompt-tool stdio` + `can_use_tool`).
Rationale: most direct — no extra process, no loopback "networking", and Claude hands
us structured prompt metadata for free. **But it is an undocumented internal contract;
Anthropic can change or remove it on any version bump.** This section exists so that
if it shifts we start from a researched menu, not a blank page.

**How we'd detect a break (canaries):**
- Pin `claude_code_version` (here **2.1.150**); diff it on every CC upgrade.
- Symptoms of regression: tools **auto-denied despite** `--permission-prompt-tool
  stdio`; `can_use_tool` requests missing/renamed; `ZodError` tool_results rejecting
  our `control_response` (e.g. the `updatedInput`-required quirk changing).
- The captured spike logs (this doc's source) double as **regression fixtures** — wire
  them into the parser/control-handler tests so a CC bump that breaks shapes goes red.

**Fallback menu, in rough preference order if `stdio` is withdrawn:**
1. **MCP permission tool** — `--permission-prompt-tool mcp__clide__approve` against the
   clide-hosted MCP server (T-170 builds that server anyway). Claude calls our MCP
   tool to get the allow/deny. More layers, but **MCP is a stable, public protocol** —
   the strongest fallback precisely because the broker will already exist.
2. **Permission modes** — degrade to `--permission-mode acceptEdits` / `dontAsk` /
   `bypassPermissions` for a reduced-fidelity UX (no per-call prompt) as a stopgap.
   Public, stable flags; buys time to build a better path.
3. **Agent SDK** — if Anthropic ships/keeps a stable public `canUseTool` SDK surface
   (TS/Python), shell out to or port it. Supported, but a heavier dep + language seam.
4. **ACP (Agent Client Protocol)** — if the ecosystem converges on ACP
   (`session/request_permission`, Zed's path) as the blessed editor-integration
   standard, adopt its adapter. Open standard; would reframe the whole transport.

**Containment:** all protocol framing lives behind one module (per D-77), so swapping
transports is a one-seam change. Re-capture fixtures per pinned version.

## Not done / open
- `hook_callback` and `mcp_message` round-trips not exercised live (shapes from the
  binary only) — needed for the clide-hosted MCP broker (T-170).
- Image/file paste intake over stream-json `content` blocks not tested here.
- Remaining-usage budget % still not exposed (only `contextWindow` size, in `result`).
