# LLM Integration Decisions

Decisions around Large Language Model integration, driver abstraction, and
multi-LLM support in clide.

---

### D-105: Support Vibe CLI as opt-in alternative to Claude Code CLI

- **Date:** 2026-06-28
- **Status:** confirmed
- **Supersedes:** None
- **See Also:** docs/spikes/vibe-cli-integration-analysis.md, D-6 (CLI/UI parity), D-56 (single process)
- **Raised by:** Mistral Vibe evaluation

#### Decision

**We will support Vibe CLI as an opt-in alternative to Claude Code CLI in clide.**

Vibe CLI provides **stdio protocol, permission prompts, session persistence,
and MCP support** — making it a **~95% feature-parity drop-in replacement** for
Claude Code CLI. This enables users to select their preferred LLM driver on a
per-repo basis while maintaining full backward compatibility with the
existing Claude flow.

#### Context

Claude Code CLI is clide's current and primary LLM. User requested the
ability to switch to Mistral's offerings. Two paths were considered:

1. **Raw Mistral API** — Requires reimplementing stdio protocol, permission
   prompts, session management. Effort: 3-4 weeks. Parity: ~70%.

2. **Vibe CLI** — Mistral's open-source CLI that **natively supports** stdio
   protocol, permission prompts (`can_use_tool`), session persistence
   (`--resume`), MCP servers, and JSONL transcripts. Effort: 1-2 weeks.
   Parity: ~95%.

The analysis in `docs/spikes/vibe-cli-integration-analysis.md` confirms Vibe CLI is the
**production-ready path**.

#### Architectural Choice

**Direct Vibe CLI Integration (Option 1 from analysis):**
- Replace `claude` with `vibe` in clide's spawn logic
- Adapt `StreamJsonProcess` and `TranscriptReader` for minor JSONL differences
- Update `ClaudeConfig` to watch `.vibe/` instead of `.claude/`
- Reuse clide's existing MCP broker for team orchestration

**Fallback (Option 2):** Thin wrapper to normalize Vibe CLI output to match
Claude's stream-json exactly. Only if protocol differences prove significant
during testing.

#### Implementation Constraints

- **Claude remains primary** — Vibe CLI is opt-in; default driver stays `claude`
- **Per-repo setting** — `llm.driver` in `.clide/config.yaml`, similar to multi-
  Claude-account mechanism
- **Zero regression** — All existing Claude functionality preserved
- **Minimal abstraction** — Leverage Vibe CLI's native parity; avoid thick
  conversion layers

#### Success Criteria

- User can select `llm.driver: claude | mistral` in per-repo config
- Vibe CLI sessions work end-to-end: streaming, permissions, tools, MCP, session resume
- `make test` passes with both drivers
- No performance regression in Claude flow
- Migration effort: 1-2 weeks

#### Consequences

**Positive:**
- Users can choose their preferred LLM
- Local inference support (offline/private use cases)
- Minimal code changes (~1-2 weeks)
- Full feature parity maintained

**Negative:**
- Additional binary dependency (Vibe CLI)
- Maintenance burden for two drivers (mitigated by abstraction)
- Testing matrix doubles (mitigated by CI feature flags)

---
