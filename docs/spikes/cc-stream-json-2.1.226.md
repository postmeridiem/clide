# Spike: Claude Code stream-json wire contract at 2.1.226

**Pinned to:** claude **2.1.226**. The previous spike
([`cc-stream-json-control-protocol-2.1.150.md`](cc-stream-json-control-protocol-2.1.150.md))
is pinned to 2.1.150 and says to re-validate on a bump — this is that
re-validation, 76 versions later. Per D-75/D-77 these are undocumented,
version-drifting internal contracts.

**Method:** drove the real binary exactly as `ClaudeStreamJsonProcess.start` does
(`--input-format stream-json --output-format stream-json --verbose
--permission-prompt-tool stdio --include-partial-messages`), one prompt per run,
every line captured raw. Two paid Haiku turns. Raw captures were throwaway; the
findings below are the record.

**Why now:** Epic D needs the companion on Haiku, and the shared session reader
(T-550) should be designed against the contract as it *is* rather than as three
existing consumers assume it to be.

---

## 1. Thinking is fully observable — this corrects our notes

The Epic B signal audit (recorded on T-517) concluded that thinking-in-progress
was unavailable and only an end-of-block `AssistantThinkingMessage` survived.
**That is wrong at 2.1.226.** A plain Haiku turn produces:

```
stream_event  content_block_start   content_block.type = "thinking"
stream_event  content_block_delta   delta.type = "thinking_delta"   (xN)
stream_event  content_block_delta   delta.type = "signature_delta"
assistant                            message.content = [thinking]
stream_event  content_block_stop
stream_event  content_block_start   content_block.type = "text"
stream_event  content_block_delta   delta.type = "text_delta"
assistant                            message.content = [text]
```

So thinking arrives as its own content block, streamed, before the text block.
`_onStreamEvent` sees all of it and drops it: it handles only `message_start`,
`content_block_delta` **gated on `text_delta`**, and `message_stop`.

Alongside it, a system event carries a running estimate:

```json
{"type":"system","subtype":"thinking_tokens","estimated_tokens":8,"estimated_tokens_delta":5,...}
```

### `thinking_tokens` is the CLI's own estimate, and it is not a token count

Worth stating plainly, because the name invites exactly the wrong use. Observed
progression against the authoritative figure from the same turn:

| `estimated_tokens` | 3 | 8 | 12 | 13 | 18 | 38 | **99** |
|---|---|---|---|---|---|---|---|
| `estimated_tokens_delta` | 3 | 5 | 4 | 1 | 5 | 20 | **61** |

`message_delta.usage.output_tokens_details.thinking_tokens` for that turn: **36**.

Seven events, and exactly seven deltas on the thinking block — six
`thinking_delta` plus one `signature_delta`. The 1:1 correspondence and that
final +61 jump give it away: the CLI estimates from the size of each delta as it
arrives, and counts the base64 **signature blob** as though it were thinking
text. Hence 99 against a real 36.

So treat it as a **liveness/progress signal only** — "still thinking, roughly
this far in" — of the sort a TUI spinner wants. Anything displaying it as a token
count, or costing against it, will be about 2.7× out. The authoritative number
arrives once, at the end, in `message_delta.usage`.

**Consequence:** a genuine "he is thinking" signal exists for the companion's own
session, and the `pensive` → `speaking` transition can be observed rather than
inferred. It also means "busy but no text yet" is no longer the only tell.

## 2. Haiku 4.5 thinks by default, and `--effort low` does not stop it

Both probes produced a thinking block unasked. The first spent 36 thinking tokens
deciding how to reply to *"Reply with exactly: hello there friend"*.

D-107 and T-519 both say "leave thinking off" for the companion. **There is no
CLI flag that does that** — `--effort low` is the nearest and it changed nothing
about whether thinking happened.

## 3. `--effort` does NOT error on Haiku 4.5 — this corrects D-107

D-107's cost section and T-519 both state "**Do not set `effort`** — it errors on
Haiku 4.5". At 2.1.226, `--model haiku --effort low` was accepted, ran normally,
and returned `is_error: false`. Either it was fixed upstream or the original
claim came from the API rather than the CLI. Treat the prohibition as lifted, but
note it buys nothing here (§2).

## 4. `--model haiku` works as a spawn flag

`init.model` came back `claude-haiku-4-5-20251001`. The companion can select its
model at spawn instead of via a `set_model` control request after the fact, which
is what `applySessionDefaults` does for the primary. Simpler and avoids a window
where the session exists on the wrong model.

## 5. The `result` event carries error detail we never read

```
is_error, stop_reason, terminal_reason, api_error_status, permission_denials,
num_turns, total_cost_usd, duration_ms, duration_api_ms, ttft_ms, ttft_stream_ms,
time_to_request_ms, modelUsage, usage, fast_mode_state, fast_mode_disabled_reason
```

`_statusFromEvent` reads only `total_cost_usd` and the model's context window.
The Epic B audit noted `rage` had no source because API errors were never
inspected — **the fields are right there**: `is_error`, `stop_reason`,
`terminal_reason`, `api_error_status`. Observed values on a clean turn:
`is_error: false`, `stop_reason: "end_turn"`, `terminal_reason: "completed"`,
`api_error_status: null`.

## 6. Event types not in the 2.1.150 spike

| Event | Notes |
|---|---|
| `system/thinking_tokens` | running thinking-token estimate (§1) |
| `system/hook_started`, `hook_progress`, `hook_response` | hook lifecycle, emitted before `init` |
| `system/status` | emitted after `init` |
| `rate_limit_event` | emitted just before `result` |

`init` also now carries `capabilities`
(`interrupt_receipt_v1`, `interrupt_cancel_queued_v1`, `msg_lifecycle_v1`),
`messaging_socket_path`, `skills`, `plugins`, `agents` and `output_style`.

## 7. Cost, measured — and why the estimate needs care

| Run | Model | Total |
|---|---|---|
| "reply with exactly: hello there friend" | haiku | **$0.0346** |
| "reply with exactly: ok", `--effort low` | haiku | **$0.0265** |

Both are *first turns in a fresh session*, and both paid a large
`cache_creation_input_tokens` (16,236 on run 1) — a session started in this repo
loads the project's context like any other.

**Do not read this as $0.03 per comment.** Cache creation is a per-session cost;
subsequent turns in the same session read the cache at a fraction of the price,
and the settled model is one session per clide run. The honest statement is:
**~$0.03 to start a companion session, plus an unmeasured per-comment cost after
that.** The initiative's ~$0.002/comment figure was never verified and the
steady-state number still is not — measure it with two turns in one session
before anyone relies on it.

## 8. T-544 — no "suggested next prompt" observed

Nothing resembling a Tab-completable next-prompt suggestion appeared in either
capture. Not conclusive: both runs were single-shot, non-interactive, with stdin
closed immediately, which is exactly the wait state such a suggestion would
plausibly key off. T-544 should probe an interactive session before concluding.

---

## What to re-check on the next bump

The two things that changed under us here — whether thinking streams, and whether
`--effort` is accepted — were both *documented* as settled and both moved. Re-run
this probe rather than trusting either file.
