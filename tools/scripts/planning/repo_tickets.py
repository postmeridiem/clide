"""Tickets repository — CRUD with T-NNN TEXT PKs and history tracking."""
from __future__ import annotations

import sqlite3

from .schema import PRIORITIES, TICKET_STATUSES, TICKET_TYPES


def next_ticket_id(conn: sqlite3.Connection) -> str:
    row = conn.execute(
        "SELECT id FROM tickets WHERE id LIKE 'T-%' ORDER BY "
        "CAST(SUBSTR(id, 3) AS INTEGER) DESC LIMIT 1"
    ).fetchone()
    highest = 0
    if row is not None:
        try:
            highest = int(row["id"].split("-", 1)[1])
        except ValueError:
            highest = 0
    return f"T-{highest + 1:03d}"


def create(
    conn: sqlite3.Connection,
    *,
    type_: str,
    title: str,
    description: str | None = None,
    parent_id: str | None = None,
    priority: str = "medium",
    decision_ref: str | None = None,
    team: str | None = None,
) -> str:
    if type_ not in TICKET_TYPES:
        raise ValueError(f"invalid type {type_!r}; must be one of {TICKET_TYPES}")
    if priority not in PRIORITIES:
        raise ValueError(f"invalid priority {priority!r}; must be one of {PRIORITIES}")
    tid = next_ticket_id(conn)
    conn.execute(
        """
        INSERT INTO tickets
            (id, type, parent_id, title, description, priority, decision_ref, team)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (tid, type_, parent_id, title, description, priority, decision_ref, team),
    )
    conn.commit()
    return tid


def list_(
    conn: sqlite3.Connection,
    *,
    status: str | None = None,
    team: str | None = None,
    assigned: str | None = None,
    decision: str | None = None,
    label: str | None = None,
) -> list[sqlite3.Row]:
    conds: list[str] = []
    params: list[str] = []
    if status:
        conds.append("t.status = ?")
        params.append(status)
    if team:
        conds.append("t.team = ?")
        params.append(team)
    if assigned:
        conds.append("t.assigned_to = ?")
        params.append(assigned)
    if decision:
        conds.append("t.decision_ref = ?")
        params.append(decision)
    join = ""
    if label:
        join = " JOIN ticket_labels l ON l.ticket_id = t.id "
        conds.append("l.label = ?")
        params.append(label)
    where = " AND ".join(conds) if conds else "1=1"
    return list(
        conn.execute(
            f"""
            SELECT t.id, t.type, t.title, t.status, t.priority,
                   t.assigned_to, t.team, t.decision_ref
            FROM tickets t{join}
            WHERE {where}
            ORDER BY
                CASE t.priority
                    WHEN 'critical' THEN 0
                    WHEN 'high'     THEN 1
                    WHEN 'medium'   THEN 2
                    ELSE 3
                END,
                t.id
            """,
            params,
        )
    )


def get(conn: sqlite3.Connection, tid: str) -> sqlite3.Row | None:
    return conn.execute("SELECT * FROM tickets WHERE id = ?", (tid,)).fetchone()


def children(conn: sqlite3.Connection, tid: str) -> list[sqlite3.Row]:
    return list(
        conn.execute(
            "SELECT id, type, title, status, priority FROM tickets "
            "WHERE parent_id = ? ORDER BY id",
            (tid,),
        )
    )


def blockers(conn: sqlite3.Connection, tid: str) -> list[sqlite3.Row]:
    return list(
        conn.execute(
            """
            SELECT t.id, t.title, t.status
            FROM ticket_deps d JOIN tickets t ON d.blocker_id = t.id
            WHERE d.blocked_id = ?
            ORDER BY t.id
            """,
            (tid,),
        )
    )


def set_status(
    conn: sqlite3.Connection, tid: str, new_status: str, *, changed_by: str | None = None
) -> int:
    if new_status not in TICKET_STATUSES:
        raise ValueError(
            f"invalid status {new_status!r}; must be one of {TICKET_STATUSES}"
        )
    row = get(conn, tid)
    if row is None:
        return 0
    old_status = row["status"]
    n = conn.execute(
        "UPDATE tickets SET status = ?, updated_at = datetime('now') WHERE id = ?",
        (new_status, tid),
    ).rowcount
    if n:
        conn.execute(
            """
            INSERT INTO ticket_history (ticket_id, field, old_value, new_value, changed_by)
            VALUES (?, 'status', ?, ?, ?)
            """,
            (tid, old_status, new_status, changed_by),
        )
    conn.commit()
    return n


def set_field(
    conn: sqlite3.Connection,
    tid: str,
    field: str,
    value: str | None,
    *,
    changed_by: str | None = None,
) -> int:
    if field not in {"assigned_to", "team", "priority", "decision_ref"}:
        raise ValueError(f"not a settable field: {field!r}")
    row = get(conn, tid)
    if row is None:
        return 0
    old = row[field]
    n = conn.execute(
        f"UPDATE tickets SET {field} = ?, updated_at = datetime('now') WHERE id = ?",
        (value, tid),
    ).rowcount
    if n:
        conn.execute(
            """
            INSERT INTO ticket_history (ticket_id, field, old_value, new_value, changed_by)
            VALUES (?, ?, ?, ?, ?)
            """,
            (tid, field, old, value, changed_by),
        )
    conn.commit()
    return n


def block(conn: sqlite3.Connection, blocked: str, blocker: str) -> None:
    conn.execute(
        "INSERT OR IGNORE INTO ticket_deps (blocker_id, blocked_id) VALUES (?, ?)",
        (blocker, blocked),
    )
    conn.commit()


def unblock(conn: sqlite3.Connection, blocked: str, blocker: str) -> int:
    n = conn.execute(
        "DELETE FROM ticket_deps WHERE blocked_id = ? AND blocker_id = ?",
        (blocked, blocker),
    ).rowcount
    conn.commit()
    return n


def label_add(conn: sqlite3.Connection, tid: str, label: str) -> None:
    conn.execute(
        "INSERT OR IGNORE INTO ticket_labels (ticket_id, label) VALUES (?, ?)",
        (tid, label),
    )
    conn.commit()


def label_rm(conn: sqlite3.Connection, tid: str, label: str) -> int:
    n = conn.execute(
        "DELETE FROM ticket_labels WHERE ticket_id = ? AND label = ?",
        (tid, label),
    ).rowcount
    conn.commit()
    return n


def search(conn: sqlite3.Connection, query: str) -> list[sqlite3.Row]:
    like = f"%{query}%"
    return list(
        conn.execute(
            """
            SELECT id, type, title, status, priority, assigned_to, team
            FROM tickets
            WHERE title LIKE ? OR COALESCE(description, '') LIKE ?
            ORDER BY id
            """,
            (like, like),
        )
    )


def board(conn: sqlite3.Connection, team: str | None = None) -> dict[str, list[sqlite3.Row]]:
    columns: dict[str, list[sqlite3.Row]] = {s: [] for s in TICKET_STATUSES}
    conds = ["1=1"]
    params: list[str] = []
    if team:
        conds.append("team = ?")
        params.append(team)
    where = " AND ".join(conds)
    for row in conn.execute(
        f"SELECT id, title, status, priority, assigned_to, team FROM tickets "
        f"WHERE {where} ORDER BY id",
        params,
    ):
        columns[row["status"]].append(row)
    return columns
