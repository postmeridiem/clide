# Web Deployment

Clide runs in a browser via a three-layer stack:

```
Browser (code.schweitz.net)
 └─ ttyd (web terminal server, port 8888)
     └─ zellij (session persistence only)
         └─ clide (Textual TUI)
             └─ claude code (embedded PTY)
```

## Components

| Layer | Purpose | Config |
|-------|---------|--------|
| **ttyd** | Serves terminal over WebSocket | systemd service on port 8888 |
| **zellij** | Session reconnection (detach/reattach) | Locked mode, bare layout, no UI |
| **clide** | TUI IDE wrapper around Claude Code | Zellij's default shell |

## Installation

From the clide project root:

```bash
sudo bash deploy/install-clide-web.sh
```

This installs:
1. `ttyd` binary to `/usr/local/bin/`
2. `zellij` binary to `/usr/local/bin/`
3. `clide-launcher` script to `/usr/local/bin/`
4. Zellij config to `~/.config/zellij/` (locked mode + bare layout)
5. `clide-web.service` systemd unit
6. Enables and starts the service

### Reverse Proxy

For external access, configure your reverse proxy (e.g., Nginx Proxy Manager) to:
- Proxy `code.schweitz.net` → `localhost:8888`
- Enable WebSocket support (required for ttyd)

## Architecture

### ttyd

Web terminal server. Runs `clide-launcher` for each browser connection.

**Service:** `/etc/systemd/system/clide-web.service`

Key flags:
- `-p 8888` — port
- `-W` — writable (allows input)
- `-a` — allows URL arguments (passes `?project=X` to the launcher)
- `-t fontSize=14` — terminal font size

### clide-launcher

Entry point script at `/usr/local/bin/clide-launcher`. Handles:

1. **Project selection** — parses `?project=NAME` from the URL
2. **Session management** — creates or reattaches to a Zellij session named `clide-<project>`
3. **Fallback UI** — shows a project selector if no project specified

**URL patterns:**
- `code.schweitz.net` — shows project selector
- `code.schweitz.net?project=clide` — opens/attaches to the clide project

### Zellij

Used **only** for session persistence (reconnecting after browser close/refresh). All UI features are disabled.

**Config:** `deploy/zellij/config.kdl`

Key settings:
- `default_mode "locked"` — all keys pass through to Clide except `Ctrl+G`
- `default_layout "bare"` — no tab bar, no status bar
- `pane_frames false` — no pane borders
- `default_shell` — points to the clide binary
- `show_startup_tips false`

**Layout:** `deploy/zellij/bare.kdl` — single pane, zero chrome.

### Keybinding Layering

Since the stack is deeply nested, keybindings are carefully layered:

| Key | Layer | Action |
|-----|-------|--------|
| `Ctrl+G` | Zellij | Unlock Zellij (only key Zellij captures in locked mode) |
| `Ctrl+Q` | Clide | Quit Clide |
| `Ctrl+B` | Clide | Toggle sidebar |
| `Ctrl+P` | Clide | Quick open |
| `Ctrl+S` | Clide | Save file |
| All others | Clide → Claude | Pass through to Clide, then to Claude Code |

**To detach a session** (e.g., before service restart):
1. `Ctrl+G` — unlock Zellij
2. `Ctrl+O` — session mode
3. `d` — detach

Or just close the browser tab — Zellij detaches automatically.

## Operations

### Service Management

```bash
# Status
systemctl status clide-web

# Restart (disconnects all sessions)
sudo systemctl restart clide-web

# Logs
journalctl -u clide-web -f
```

### Session Management

```bash
# List sessions
zellij list-sessions

# Kill stuck sessions
zellij delete-all-sessions --force --yes

# Clear serialized session cache (if ghost sessions persist)
rm -rf ~/.cache/zellij/*/session_info/clide-*
```

### Troubleshooting

**Service stuck in `deactivating`:** A child process (usually `claude`) didn't respond to SIGTERM.
```bash
sudo systemctl kill -s SIGKILL clide-web
sudo systemctl start clide-web
```

**Old sessions ignore config changes:** Zellij serializes sessions. Delete them and restart:
```bash
zellij delete-all-sessions --force --yes
rm -rf ~/.cache/zellij/*/session_info/clide-*
sudo systemctl restart clide-web
```

**Keys not reaching Clide:** Zellij may be in normal mode. Press `Ctrl+G` to toggle back to locked mode. The status bar being visible is a sign you're unlocked (bare layout hides it in locked mode).

## Files

```
deploy/
├── install-clide-web.sh    # Installation script (run with sudo)
├── clide-launcher           # Session launcher (ttyd → zellij → clide)
├── clide-web.service        # systemd unit file
└── zellij/
    ├── config.kdl           # Zellij config (locked mode, no UI)
    └── bare.kdl             # Bare layout (single pane, no chrome)
```
