# Web Deployment

Clide runs in a browser via a two-layer stack:

```
Browser (code.schweitz.net)
 └─ clide-web (FastAPI + uvicorn, port 8888)
     └─ tmux (session persistence)
         └─ clide (Textual TUI)
             └─ claude code (embedded PTY)
```

## Components

| Layer | Purpose | Config |
|-------|---------|--------|
| **clide-web** | FastAPI server: HTML page, WebSocket ↔ PTY bridge, REST API | systemd service on port 8888 |
| **tmux** | Session persistence (detach/reattach on browser disconnect) | Managed by clide-web |
| **clide** | TUI IDE wrapper around Claude Code | Spawned by tmux |

## Installation

From the clide project root:

```bash
sudo bash deploy/install-clide-web.sh
```

This:
1. Installs `clide-web` Python package into the clide venv
2. Installs `clide-web.service` systemd unit
3. Enables and starts the service

### First-Run Setup

After installing, run the setup wizard to configure projects directory and clide binary path:

```bash
clide-web-setup
```

Settings are stored in `~/.clide/clide.db` as UserPreference records.

### Prerequisites

- Python 3.12+ with clide venv set up (`make setup`)
- `tmux` installed (`sudo dnf install tmux` / `sudo apt install tmux`)

### Reverse Proxy

For external access, configure your reverse proxy (e.g., Nginx Proxy Manager) to:
- Proxy `code.schweitz.net` → `localhost:8888`
- Enable WebSocket support

## Architecture

### clide-web

FastAPI application serving:
- `GET /` — HTML page with xterm.js terminal + toolbar
- `GET /projects/{name}` — Project terminal page
- `WS /projects/{name}/ws` — WebSocket terminal bridge
- `GET /api/projects` — List available git repos
- `GET /api/sessions` — List active tmux sessions
- `GET /health` — Health check for reverse proxy

**WebSocket Protocol:**

| Prefix | Direction | Purpose |
|--------|-----------|---------|
| `0` | both | Terminal data |
| `1` | both | Control message (JSON) |
| `2` | client→server | Resize: `cols,rows` |

### tmux

Managed programmatically by clide-web. One session per project (`clide-<project>`).

- Browser disconnect → tmux session persists, reconnect shows current state
- Clide exit (Alt+Q) → `pane-died` hook auto-respawns a fresh Clide instance
- Status bar hidden for clide-web sessions only (user's other tmux sessions unaffected)
- Full environment inherited (HOME, PATH, etc.)

### Keybindings

All keys pass through directly to Clide — no intermediate layer captures keys.
No keybinding conflicts (unlike the previous Zellij-based setup).

### Database

SQLite database at `~/.clide/clide.db` shared between clide and clide-web.
Uses SQLModel (Pydantic-native ORM by FastAPI's creator).

Tables:
- **Project** — name, path, theme, last_accessed
- **Session** — tmux session name, status, last_activity
- **UserPreference** — key/value settings (projects_dir, clide_bin, port, etc.)
- **ConnectionLog** — client IP, connect/disconnect timestamps

## Configuration

Settings priority: environment variables > database preferences > defaults.

Environment variables (prefix `CLIDE_WEB_`):

| Variable | Default | Description |
|----------|---------|-------------|
| `CLIDE_WEB_HOST` | `0.0.0.0` | Server bind address |
| `CLIDE_WEB_PORT` | `8888` | Server port |
| `CLIDE_WEB_PROJECTS_DIR` | `/mnt/media/Projects` | Directory containing git repos |
| `CLIDE_WEB_CLIDE_BIN` | `clide` | Path to clide binary |
| `CLIDE_WEB_DB_PATH` | `~/.clide/clide.db` | SQLite database path |

## URL Patterns

- `code.schweitz.net` — auto-selects first project
- `code.schweitz.net/projects/clide` — opens/attaches to the clide project

The toolbar dropdown allows switching projects. URL updates via `history.pushState`.

## Operations

### Service Management

```bash
# Using make targets (from clide-web/ directory)
make start-server       # Start the systemd service
make stop-server        # Stop the systemd service
make restart-server     # Restart the systemd service
make status-server      # Show service status
make logs-server        # Tail service logs

# Or directly with systemctl
systemctl status clide-web
sudo systemctl restart clide-web
journalctl -u clide-web -f
```

### Session Management

```bash
# List sessions
tmux list-sessions

# Kill a specific session
tmux kill-session -t clide-myproject

# Kill all clide sessions
tmux list-sessions | grep ^clide- | cut -d: -f1 | xargs -I{} tmux kill-session -t {}
```

## Files

```
clide-web/                      # Python package
├── clide_web/
│   ├── server.py               # FastAPI app, routes, WebSocket handler
│   ├── sessions.py             # tmux session manager
│   ├── pty_bridge.py           # PTY ↔ WebSocket bridge
│   ├── config.py               # Pydantic settings with DB overlay
│   ├── setup_wizard.py         # Interactive first-run configuration
│   └── static/
│       ├── index.html          # HTML page (toolbar + xterm.js)
│       └── vendor/             # Vendored xterm.js (no CDN dependencies)
├── pyproject.toml
└── Makefile
deploy/
├── install-clide-web.sh        # Installation script (run with sudo)
└── clide-web.service           # systemd unit file
clide/
├── models/db.py                # SQLModel table definitions (shared)
└── services/database.py        # SQLite engine and session factory
```
