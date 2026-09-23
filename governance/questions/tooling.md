# Open Questions — Tooling

Build, packaging, distribution, supply chain.

---

### Q-53: Web UI distribution
- **Status:** Open
- **Question:** How does the web UI ship ([D-116](../decisions/architecture.md#d-116-web-ui-mode--full-clide-in-the-browser-served-from-a-containerised-host), [D-117](../decisions/architecture.md#d-117-web-front-door--caddy-at-the-edge-internal-dart-broker-and-hosts))?
  - (a) **Image contents.** What is bundled, and what is provisioned at first run? The candidates are Caddy, the Dart broker and hosts, git, pql ([D-92](../decisions/tooling.md#d-92-ship-pql-bundled-with-clide)) and, above all, the Claude Code CLI. The CLI's licence must pass [D-65](../decisions/tooling.md#d-65-license-compatibility-matrix) before it can be bundled, and [D-104](../decisions/tooling.md#d-104-explicit-supporter-binary-path-overrides-in-user-scope-settings) treats `claude` as user-resolved.
  - (b) **Claude credentials inside a container:** the login flow, where credentials persist, and who can read them.
  - (c) **Base image, pinning and architectures:**
    - a digest-pinned base, with exact pins and advisory review for its OS packages ([D-31](../decisions/tooling.md#d-31-prefer-zero-deps-exact-pin), [D-61](../decisions/tooling.md#d-61-dependency-vetting-checklist));
    - glibc ≥ 2.34, which the vendored `libtree-sitter.so` needs;
    - arm64 only after the vendored native libraries are rebuilt for it ([D-63](../decisions/tooling.md#d-63-vendored-binary-rebuild-process)).
  - (d) **Registry, signing and updates:**
    - images published alongside the GitHub releases (GHCR);
    - signing that matches the release channel (T-491);
    - how [D-113](../decisions/architecture.md#d-113-self-update-verified-download-rename-swap-of-the-install-windows-restart-onto-it-the-loader-stays)'s self-update behaves in `webui` mode;
    - [D-64](../decisions/architecture.md#d-64-no-telemetry--architectural-commitment): no update check without a user action.
  - (e) **Installer contract,** Linux with Docker first:
    - preflight checks;
    - data and workspace volumes for many workspaces;
    - bootstrapping the access token;
    - the compose file;
    - upgrade and uninstall;
    - a download that can be verified before it runs, not a blind pipe-to-shell.
  - (f) **TLS on a LAN.** Caddy's internal CA, and how the installer gets its root trusted by the user's browsers, versus a user domain with ACME. A secure context is required (D-117).
  - (g) **The Caddy build:** from source in a build stage, pinned, with its module tree attributed in `licenses.yaml` ([D-42](../decisions/tooling.md#d-42-dependencies-documented-in-licensesyaml)).
- **Context:** Distribution is greenfield: there is no image, registry or container tooling in the repo or its history. POLICY.md does not mention images yet, so this resolution also amends POLICY.md. The prior art is the release pipeline (`release.yml`, which publishes only from a tested commit) and the self-update's digest check.
- **Source:** D-116 / 2026-09-23 user direction.

---
