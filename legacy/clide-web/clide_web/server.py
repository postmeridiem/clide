"""FastAPI application: HTTP routes + WebSocket terminal bridge."""

from __future__ import annotations

import asyncio
import json
import logging
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path

import uvicorn
from clide.models.db import ConnectionLog
from clide.services.database import get_db, init_db
from fastapi import Depends, FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from sqlmodel import Session as DBSession

from clide_web.config import ClideWebSettings, load_settings
from clide_web.pty_bridge import PtyBridge
from clide_web.sessions import TmuxSessionManager

logger = logging.getLogger(__name__)

# Module-level settings and session manager (initialized in lifespan)
_settings: ClideWebSettings | None = None
_session_mgr: TmuxSessionManager | None = None
_cleanup_task: asyncio.Task | None = None  # type: ignore[type-arg]

STATIC_DIR = Path(__file__).parent / "static"


# ------------------------------------------------------------------
# Lifespan
# ------------------------------------------------------------------


@asynccontextmanager
async def lifespan(_app: FastAPI):  # type: ignore[no-untyped-def]
    global _settings, _session_mgr, _cleanup_task

    _settings = load_settings()
    _session_mgr = TmuxSessionManager(_settings)

    # Initialize database
    init_db(_settings.db_path)
    logger.info("Database initialized at %s", _settings.db_path)

    # Start periodic session cleanup
    _cleanup_task = asyncio.create_task(_periodic_cleanup())

    yield

    # Shutdown
    if _cleanup_task:
        _cleanup_task.cancel()
        try:
            await _cleanup_task
        except asyncio.CancelledError:
            pass


async def _periodic_cleanup() -> None:
    """Periodically sync DB session records with live tmux state."""
    assert _settings is not None
    assert _session_mgr is not None
    while True:
        await asyncio.sleep(_settings.session_cleanup_interval_seconds)
        try:
            db_gen = get_db()
            db = next(db_gen)
            try:
                await _session_mgr.cleanup_dead_sessions(db)
            finally:
                try:
                    next(db_gen)
                except StopIteration:
                    pass
        except Exception:
            logger.exception("Session cleanup failed")


# ------------------------------------------------------------------
# App
# ------------------------------------------------------------------

app = FastAPI(title="clide-web", version="1.0.0", lifespan=lifespan)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


# ------------------------------------------------------------------
# Routes
# ------------------------------------------------------------------


@app.get("/", response_class=HTMLResponse)
async def index():
    """Redirect root to project list or serve HTML."""
    return _serve_index()


@app.get("/projects/{project_name}", response_class=HTMLResponse)
@app.head("/projects/{project_name}")
async def project_page(project_name: str):  # noqa: ARG001
    """Serve the terminal page for a specific project."""
    return _serve_index()


def _serve_index() -> FileResponse | HTMLResponse:
    index_path = STATIC_DIR / "index.html"
    if index_path.exists():
        return FileResponse(index_path, media_type="text/html")
    return HTMLResponse("<h1>clide-web</h1><p>index.html not found</p>", status_code=500)


@app.get("/health")
async def health():
    """Health check for reverse proxy."""
    return {"status": "ok"}


@app.get("/api/projects")
async def list_projects():
    """List available git projects."""
    assert _session_mgr is not None
    return {"projects": _session_mgr.list_projects()}


@app.get("/api/sessions")
async def list_sessions():
    """List active tmux sessions."""
    assert _session_mgr is not None
    sessions = await _session_mgr.list_sessions()
    return {"sessions": sessions}


# ------------------------------------------------------------------
# WebSocket terminal bridge
# ------------------------------------------------------------------


@app.websocket("/projects/{project}/ws")
async def websocket_terminal(
    ws: WebSocket,
    project: str,
    db: DBSession = Depends(get_db),  # noqa: B008
):
    """Bridge WebSocket ↔ PTY (via tmux attach).

    Protocol:
        Prefix "0" + data   → terminal I/O
        Prefix "1" + json   → control messages
        Prefix "2" + C,R    → resize (cols,rows)
    """
    assert _settings is not None
    assert _session_mgr is not None

    await ws.accept()

    if not project:
        await ws.send_text('1{"type":"error","message":"No project specified"}')
        await ws.close(code=1008)
        return

    # Validate and create/attach tmux session
    try:
        tmux_name = await _session_mgr.create_session(project, db)
    except (ValueError, RuntimeError) as e:
        await ws.send_text(f'1{json.dumps({"type": "error", "message": str(e)})}')
        await ws.close(code=1008)
        return

    # Log connection
    client_ip = ws.client.host if ws.client else "unknown"
    log_entry = ConnectionLog(project_name=project, client_ip=client_ip)
    db.add(log_entry)
    db.commit()
    db.refresh(log_entry)

    # Send session info
    await ws.send_text(
        f'1{json.dumps({"type": "session_info", "project": project, "tmux_session": tmux_name})}'
    )

    # Set up PTY bridge to tmux session
    send_queue: asyncio.Queue[bytes] = asyncio.Queue()

    def on_output(data: bytes) -> None:
        send_queue.put_nowait(data)

    def on_exit() -> None:
        send_queue.put_nowait(b"")  # Sentinel for EOF

    bridge = PtyBridge(
        tmux_session=tmux_name,
        on_output=on_output,
        on_exit=on_exit,
        rows=_settings.default_rows,
        cols=_settings.default_cols,
    )
    bridge.start()

    # Task to forward PTY output → WebSocket
    async def _forward_output() -> None:
        while True:
            data = await send_queue.get()
            if not data:
                break
            try:
                await ws.send_bytes(b"0" + data)
            except Exception:
                break

    output_task = asyncio.create_task(_forward_output())

    try:
        while True:
            message = await ws.receive()

            if message["type"] == "websocket.disconnect":
                break

            if "text" in message:
                text = message["text"]
                if not text:
                    continue
                prefix = text[0]
                payload = text[1:]

                if prefix == "0":
                    # Terminal input
                    bridge.write(payload.encode("utf-8", errors="surrogateescape"))
                elif prefix == "1":
                    # Control message
                    await _handle_control(ws, payload, project)
                elif prefix == "2":
                    # Resize: "2cols,rows"
                    try:
                        cols_str, rows_str = payload.split(",", 1)
                        bridge.resize(int(rows_str), int(cols_str))
                    except (ValueError, IndexError):
                        pass

            elif "bytes" in message:
                raw = message["bytes"]
                if raw and len(raw) > 1:
                    prefix = raw[0:1]
                    payload_bytes = raw[1:]
                    if prefix == b"0":
                        bridge.write(payload_bytes)

    except WebSocketDisconnect:
        pass
    except Exception:
        logger.exception("WebSocket error for project %s", project)
    finally:
        bridge.stop()
        output_task.cancel()
        try:
            await output_task
        except asyncio.CancelledError:
            pass

        # Update connection log
        log_entry.disconnected_at = datetime.utcnow()
        db.add(log_entry)
        db.commit()


async def _handle_control(ws: WebSocket, payload: str, project: str) -> None:  # noqa: ARG001
    """Handle a JSON control message from the client."""
    try:
        msg = json.loads(payload)
    except json.JSONDecodeError:
        return

    msg_type = msg.get("type", "")

    if msg_type == "list_projects":
        assert _session_mgr is not None
        projects = _session_mgr.list_projects()
        await ws.send_text(f'1{json.dumps({"type": "projects", "projects": projects})}')

    elif msg_type == "ping":
        await ws.send_text(f'1{json.dumps({"type": "pong"})}')


# ------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------


def main() -> None:
    """Run the clide-web server."""
    settings = load_settings()
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    )
    logger.info("Starting clide-web on %s:%d", settings.host, settings.port)
    uvicorn.run(
        app,
        host=settings.host,
        port=settings.port,
        log_level="info",
        ws_ping_interval=20,
        ws_ping_timeout=20,
    )
