# Golden dreams — hosted clide

**Status:** speculative. Captured 2026-09-02 from one design conversation, not a
design review. Nothing here is committed to; nothing here is scoped. **Triage on
ingest**, and expect to disagree with some of it.

What this is: the shape of clide as a hosted, browser-reachable application, and
the reasoning behind each fork — recorded so the next pass argues with a position
rather than starting from a blank page.

---

## Two scenarios, opposite emphases

**Homelab.** One trusted user (the operator), reaching their own machine from
anywhere. The user is trusted; the network is not. **The perimeter is the
security boundary.**

**Corporate workstations.** N semi-trusted colleagues on shared hardware, served
to Chromebooks. The network is conventional (SSO, TLS); the users may be careless
toward each other. **The isolation boundary is the security boundary.**

Same product. The design below serves both, but they load-bear on different
layers, and conflating them is how you end up with a perimeter that's overbuilt
and an isolation story that isn't there.

## Settled — things we'd have to argue our way back out of

**Bundle size is not a constraint.** The 93 MB `build/web` is a build directory:
37 MB of CanvasKit variants where exactly one loads, a 3.3 MB JS fallback that
never loads in wasm mode, and 51 MB of assets fetched on demand. Cold load is
~10–15 MB before compression; the app itself is 2.9 MB, smaller than Monaco.

**Clide is never multi-tenant. It is single-tenant, replicated.** One instance
per user — container or OS user. Not for fashion: clide's whole design assumes
*you are the same user on the same box* (singleton kernel, per-workspace socket,
settings, recents, session IDs). Inside a per-user boundary that assumption
becomes true again, so nothing in the app has to change. Retrofitting a user
model into the process would be a rewrite and a permanent liability.

**The server holds state**, in three tiers:

| Tier | Examples | Lives |
|---|---|---|
| Authoritative | buffers, Claude sessions, canvas docs, project root, settings | server |
| Session-scoped | open panes, tabs, active workspace tab, selection | server, per workstation session |
| Ephemeral | scroll, pan/zoom, hover, in-flight gesture | client, lost on reconnect |

Tier 2 is the one that decides whether reconnect *feels* seamless. Wrong scroll
position: nobody notices. Empty workspace: feels broken.

Within tier 1 there's a second split that matters operationally — **on-disk**
(transcripts, canvas files, settings; already crash-survivable per D-77) versus
**in-memory** (editor buffers between saves). That difference decides whether a
container restart is annoying or destructive, and it's the whole reason a
stateful clide is in tension with auto-updating deploys (Watchtower on the
homelab, rolling evictions on k8s).

**That decision already picked the deployment target.** Cloud Run is
stateless-request shaped — autoscaling, scale-to-zero, no instance affinity. A
session owning buffers, PTYs and a live Claude process needs to still be there in
twenty minutes on the same instance. That's GKE with a per-user pod and a PVC —
the Coder / Gitpod / Codespaces shape, which they all reached for this reason.

**Enforcement belongs in the kernel, not the dispatcher.** Per-user path scoping
in the receiving socket is enforcement at the wrong layer, because clide spawns
processes: the terminal pane is a real PTY and the Claude pane spawns a CLI that
runs Bash. Neither goes through the dispatcher. Dispatcher-level scoping is a
lock on the front door of a house with no back wall — and worse, it *looks* like
a boundary, so someone later reasons from it and is wrong.

Keep the existing path confinement (`resolveUnderRoot`, `resolveForWriteUnderRoot`)
as **defense in depth and correctness**, and name it that way in the design so
nobody mistakes it for the boundary.

**Clide is a remote code execution surface by construction.** Not incidentally —
the Claude pane runs arbitrary tools and the terminal is a PTY. Whoever reaches
an authenticated session has, functionally, a shell as that user. Hold it to
whatever bar you hold SSH to on that box; anything less is theatre, because the
capability is identical.

## The shape

### Two layers

An **always-on proxy** authenticates and supervises. A **per-user clide** does
the work, spawned as that user (homelab) or as a pod (corporate). This is
privilege separation — the `sshd` model, where a privileged listener
authenticates and the work happens in a child that has dropped privileges.

Properties worth preserving:

- **The proxy is a separate binary, not `clide --serve`.** Then "the mapping is
  never loaded by clide" is structural rather than a rule someone maintains. One
  settings refactor that globs a config directory would otherwise quietly break
  it, on the privileged side.
- **The proxy does not speak clide's protocol.** Authenticate, resolve identity,
  spawn-or-attach, pump an *opaque* byte stream. If it doesn't understand what it
  carries, a protocol bug can't escalate through it. `sshd`'s privsep monitor is
  deliberately tiny for the same reason.
- **Both its edges are pluggable**, which is why one design covers both
  scenarios: identity in (verified assertion | trusted header over a proven hop),
  execution out (`fork`+`setuid` | pod controller). Core stays identical.
- **It must attach, not only spawn.** Server-holds-state means reconnect matters,
  so the proxy needs a session registry, an idle policy, and an answer for the
  second connection (we lean single-client: evict or observe).
- The routing key is `(user, workspace)`, not user — clide is one process per
  workspace (D-70/72). Workspace selection has to live in the URL or handshake,
  which drags in Q-51/T-422 where cross-window fencing is already known-leaky.

### Identity

**The transport is user-aware, but what it authorizes is *which OS identity you
get*, not *which paths you may touch*.** Identity at the transport for routing,
audit and revocation; enforcement in the kernel.

**Clide never learns who you are.** No user model, no roles, no permission checks
in the app — it runs as a Unix user and that *is* its entire security context,
inherited rather than implemented. The app can never grow a half-correct
authorization layer because it has no vocabulary for one.

**The mapping** (IdP subject → execution identity) is the proxy's alone:
root-owned, `0600`, and unreadable by the spawned process. Not in clide's
settings surface — a shared config between the privileged and unprivileged halves
is a classic escalation path. Key it on the IdP's **stable subject ID**, never
username or email: accounts get renamed and recreated, and a name-keyed mapping
silently transfers to whoever inherits the address.

**Escalation is an act, not an attribute.** `alice may attach as {alice, admin}`
with the choice made at connect time and re-auth for the privileged one — the
`sudo` model. A static `alice → root` means every login is root, and a stolen
session is a root session.

**Audit is split by design** — the proxy knows subject→user→session, clide knows
what happened inside. Stamp a correlation ID at spawn so the two trails join.
Cheap now, miserable to retrofit during an incident.

### Auth, without implementing OIDC

You need **assertion verification**, not an OIDC client: no auth-code flow, no
PKCE, no token storage or refresh. Verify the signed assertion against the
issuer's JWKS and read the subject from it.

The trusted-header name must be **configurable** — IAP, Cloudflare Access,
Authentik and oauth2-proxy all differ — and configuring it is the operator's
attestation that *on this system, that header is trustworthy*. Which implies:

- **Unset must refuse connections.** Not "trust nothing and allow." Permissive
  defaults defeat the point of making it explicit.
- **Two modes with different trust roots.** *Verified assertion* trusts
  cryptography. *Trusted header* trusts topology — and so must carry a
  mandatory proof-of-hop: shared-secret header injected by the LB, mTLS, or a
  private path. Loopback is the degenerate case of that on one box. Trusted-header
  mode with a proven hop is a first-class choice, not a fallback.
- **`aud`, not just signature and issuer.** For IAP the signature and issuer are
  *global to GCP* — every assertion is signed by the same Google key with issuer
  `https://cloud.google.com/iap`. Only the audience claim scopes it to your
  backend. It's the field people skip because everything works without it.

Related network notes, from reviewing the GCP side:

- Firewalling to `35.191.0.0/16` + `130.211.0.0/22` is **not** a per-project
  boundary — those are shared Google front-end ranges. The cross-project vector
  is an **internet NEG**, which lets any project's LB target an arbitrary public
  IP. Internal-only backends close it structurally.
- Internal-only means **VPC-only, not IAP-only**: anything already in the VPC
  (CI runners executing branch code, dev VMs with engineer shells) can hit the
  backend directly with forged headers. Subnets are not isolation boundaries in
  GCP — all subnets in a VPC route to each other; the isolation is the firewall
  rules. Separate VPCs, or firewall rules keyed on **service accounts** rather
  than ranges, are the structural versions.
- IAP does strip client-supplied `X-Goog-*` headers — but that's a property of
  the *route*, and the backend can't observe which route a request took. Useful
  for reducing surface; not evidence of provenance.

### Claude credentials

Properly containerized, **logging into Claude is the user's own problem** — which
dissolves the custody question rather than solving it. The operator never holds
anyone's credentials, and per-user entitlement is how subscriptions work anyway.

Mostly already built: `account_registry.dart` (T-483, epic **T-476**) models
accounts as `{name, dir}` where `dir` is that account's `CLAUDE_CONFIG_DIR`, with
a per-workspace binding keyed on the same FNV-1a hash D-70 uses for socket paths.
The hosted case is the degenerate version — one account whose dir is on the
user's PVC. The UX is already scoped as that epic's downstream tickets
(T-480/481/482/484).

Hosting genuinely *improves* one thing: the login flow can't open a browser in
the container, so it falls back to a device-code shape — show a URL, take a
pasted code. That's a better fit than desktop's shell-out-and-hope, because the
browser is on the user's machine even when `claude` isn't.

What's needed: **"installed but not authenticated" as a first-class state**,
distinct from "not installed", presented as onboarding rather than error. T-357's
onboarding / read-mode degrade is the existing machinery — files, git, editor and
tickets keep working while the Claude pane carries a connect prompt.

## The actual project: the extension split

**The cut doesn't run between clide and the browser. It runs through the middle
of every extension.**

`CanvasExtension` holds a `MultitabController` (client state) *and* a document
store that does IPC. `ClaudeConfig` is a `ChangeNotifier` that reads the
filesystem. Today's builtins straddle both halves because there was never a
reason not to.

VS Code hit this exact wall — it's why extensions there declare
`extensionKind: ["ui", "workspace"]`. You cannot cut an app in half until each
part declares which half it's in. Clide needs the same taxonomy, plus a third
case: **lives in both**, which is most of the interesting ones.

**D-6 becomes structural rather than disciplinary.** Today an extension *could*
call `File()` directly and nobody notices until someone wants the CLI — which is
precisely how T-570 happened. Split, the client half physically cannot, so every
capability must be expressed as something the server executes and the CLI gets it
by construction.

**Expose all capabilities as verbs.** An earlier draft of this argued for a
private extension channel; that was wrong twice over. The security objection was
already spent (desktop exposes the same verbs to anything reaching the socket,
Claude included), and a private channel is a mechanism for violating D-6 that the
architecture would newly permit — backwards. The only genuine exception is
**boundary plumbing**: calls that exist solely because the renderer is remote
("scroll extent of this list", "layout metrics for that pane"). Those have no
desktop counterpart, so they aren't parity gaps. The bar for claiming something
is plumbing should be high — "it's just internal" is the excuse that produced
T-570.

**Prerequisite gap:** extensions cannot register dispatcher verbs today. The
`canvas.*` verbs live in `lib/src/daemon/canvas_commands.dart`, wired in
`main.dart` — a *builtin* needed a core change to get its CLI. Fine when you own
the tree; not viable for third-party extensions, and a precondition for the split
rather than a consequence of it.

**D-56 survives.** The split is a *build target*, not a shipped daemon: desktop
compiles both halves into one process (direct calls, zero hops, no fidelity
compromise), hosted compiles them apart. The seam already exists —
`DaemonClient` is the abstraction and `daemonClientFactory` already selects an
implementation, with web currently passing `null`. D-56 was protecting users from
managing a background service; a hosted operator already manages containers.

## Open questions

1. **Does Claude come with you into an elevated session?** Hands-on-keyboard
   elevated sessions are a remote IDE with an admin mode. Elevated sessions where
   the agent has equal reach are an autonomous agent with root on the homelab —
   which the estate rule (*no direct sudo; write a script, explain it, ask the
   user to run it*) already decided against once, in a context where it was
   harder to do by accident. **Asked twice, still unanswered. It changes the
   design, not the implementation.**
2. **Personal or company-provisioned Claude accounts?** Personal keeps custody
   with the user and the story above holds. Company-provisioned brings custody
   back to IT — different plan tier, different admin surface, and the container
   is holding a company credential after all.
3. **Multi-client, ever?** We lean single-client-per-workspace with reconnect,
   which preserves the current model entirely. Multi-client means collaborative
   editing — conflict resolution, CRDTs or OT on buffers, presence. That's a
   different product, not a feature.
4. **Which lock proves the LB→backend hop** in each existing stack — shared
   secret, mTLS, or private path.

## Why this is cheaper than it looks

Almost none of the hosted story is new architecture. It is:

- the extension taxonomy — **T-358**'s shape
- the state migration — the pattern **T-570** and **T-550** already established,
  one widget at a time
- the execution seam — **T-399**, verbatim, already scoped for SSH-remote
- account plumbing — **T-476** and its downstream tickets
- onboarding degrade — **T-357**

All of it already justified by other reasons. **The genuinely new pieces are the
proxy and the assertion check**, and both are small enough to read in one sitting.

Which means the sequencing question mostly dissolves: every widget whose state
moves to a store, and every extension that gets honest about which half it lives
in, is independently worth doing — better testability, better CLI parity, better
reconnect — and is the port, done incrementally, without a flag day.

The version to be suspicious of is the one that starts with the WebSocket.

## See also

`docs/spikes/web-target-2026-09-02.md` — what actually happens today when the
wasm build is served and loaded, including the two runtime fence holes the CI
compile gate structurally cannot see.
