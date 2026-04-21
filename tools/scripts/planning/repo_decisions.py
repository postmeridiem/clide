"""Decisions repository — upsert records, query joined views."""
from __future__ import annotations

import sqlite3
from pathlib import Path

from .parser import Record, parse_all


def sync(conn: sqlite3.Connection, repo_root: Path) -> dict:
    records, warnings = parse_all(repo_root)
    known_ids = {r.id for r in records}
    conn.execute("DELETE FROM decision_refs")
    upserted = 0
    for r in records:
        conn.execute(
            """
            INSERT INTO decisions (id, type, domain, title, status, date, file_path, synced_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
            ON CONFLICT(id) DO UPDATE SET
                type      = excluded.type,
                domain    = excluded.domain,
                title     = excluded.title,
                status    = excluded.status,
                date      = excluded.date,
                file_path = excluded.file_path,
                synced_at = datetime('now')
            """,
            (r.id, r.type, r.domain, r.title, r.status, r.date, r.file_path),
        )
        upserted += 1

    refs_created = 0
    broken = 0
    for r in records:
        for target, ref_type, note in r.refs:
            if target not in known_ids:
                broken += 1
                warnings.append(f"broken ref: {r.id} → {target} ({ref_type})")
                continue
            try:
                conn.execute(
                    """INSERT OR IGNORE INTO decision_refs
                       (source_id, target_id, ref_type, note)
                       VALUES (?, ?, ?, ?)""",
                    (r.id, target, ref_type, note),
                )
                refs_created += 1
            except sqlite3.IntegrityError:
                pass
    conn.commit()
    return {
        "synced": upserted,
        "refs": refs_created,
        "broken": broken,
        "warnings": warnings,
    }


def list_decisions(
    conn: sqlite3.Connection,
    type_: str | None = None,
    domain: str | None = None,
    status: str | None = None,
) -> list[sqlite3.Row]:
    conditions: list[str] = []
    params: list[str] = []
    if type_:
        conditions.append("type = ?")
        params.append(type_)
    if domain:
        conditions.append("domain = ?")
        params.append(domain)
    if status:
        conditions.append("status = ?")
        params.append(status)
    where = " AND ".join(conditions) if conditions else "1=1"
    return list(
        conn.execute(
            f"SELECT id, type, domain, title, status, date, file_path "
            f"FROM decisions WHERE {where} ORDER BY id",
            params,
        )
    )


def get(conn: sqlite3.Connection, rid: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM decisions WHERE id = ?", (rid,)
    ).fetchone()


def refs_of(conn: sqlite3.Connection, rid: str) -> list[sqlite3.Row]:
    return list(
        conn.execute(
            """
            SELECT source_id, target_id, ref_type, note
            FROM decision_refs
            WHERE source_id = ? OR target_id = ?
            ORDER BY ref_type, source_id, target_id
            """,
            (rid, rid),
        )
    )


def tickets_for(conn: sqlite3.Connection, rid: str) -> list[sqlite3.Row]:
    return list(
        conn.execute(
            "SELECT id, type, title, status, priority FROM tickets "
            "WHERE decision_ref = ? ORDER BY id",
            (rid,),
        )
    )


def coverage(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    """D-records without an implementing ticket."""
    return list(
        conn.execute(
            """
            SELECT d.id, d.domain, d.title
            FROM decisions d
            LEFT JOIN tickets t ON t.decision_ref = d.id
            WHERE d.type = 'confirmed' AND t.id IS NULL
            ORDER BY d.id
            """
        )
    )
