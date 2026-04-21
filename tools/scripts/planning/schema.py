"""SQL schema for .pql/pql.db — adapted from settled-reach, Scrum stripped.

Differences from settled-reach:
- Tickets use TEXT PK (`T-NNN`), not INTEGER AUTOINCREMENT.
- No `sprints` table; no `sprint_id` column.
- `ticket_deps.{blocker,blocked}_id` are TEXT (referencing `tickets.id`).
"""

SCHEMA_SQL = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS decisions (
    id          TEXT PRIMARY KEY,
    type        TEXT NOT NULL CHECK(type IN ('confirmed','question','rejected')),
    domain      TEXT NOT NULL,
    title       TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'active'
                    CHECK(status IN ('active','superseded','resolved','open')),
    date        TEXT,
    file_path   TEXT NOT NULL,
    synced_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS decision_refs (
    source_id   TEXT NOT NULL REFERENCES decisions(id) ON DELETE CASCADE,
    target_id   TEXT NOT NULL REFERENCES decisions(id) ON DELETE CASCADE,
    ref_type    TEXT NOT NULL
                    CHECK(ref_type IN ('supersedes','references','resolves','depends_on','amends')),
    note        TEXT,
    PRIMARY KEY (source_id, target_id, ref_type)
);

CREATE TABLE IF NOT EXISTS tickets (
    id           TEXT PRIMARY KEY,
    type         TEXT NOT NULL CHECK(type IN ('initiative','epic','story','task','bug')),
    parent_id    TEXT REFERENCES tickets(id),
    title        TEXT NOT NULL,
    description  TEXT,
    status       TEXT NOT NULL DEFAULT 'backlog'
                    CHECK(status IN ('backlog','ready','in_progress','review','done','cancelled')),
    priority     TEXT DEFAULT 'medium'
                    CHECK(priority IN ('critical','high','medium','low')),
    assigned_to  TEXT,
    team         TEXT,
    decision_ref TEXT REFERENCES decisions(id),
    created_at   TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS ticket_deps (
    blocker_id   TEXT NOT NULL REFERENCES tickets(id),
    blocked_id   TEXT NOT NULL REFERENCES tickets(id),
    PRIMARY KEY (blocker_id, blocked_id)
);

CREATE TABLE IF NOT EXISTS ticket_history (
    ticket_id    TEXT NOT NULL REFERENCES tickets(id),
    field        TEXT NOT NULL,
    old_value    TEXT,
    new_value    TEXT,
    changed_by   TEXT,
    changed_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS ticket_labels (
    ticket_id    TEXT NOT NULL REFERENCES tickets(id),
    label        TEXT NOT NULL,
    PRIMARY KEY (ticket_id, label)
);

CREATE INDEX IF NOT EXISTS idx_tickets_status        ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_team          ON tickets(team);
CREATE INDEX IF NOT EXISTS idx_tickets_decision_ref  ON tickets(decision_ref);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned      ON tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_decisions_domain      ON decisions(domain);
CREATE INDEX IF NOT EXISTS idx_decisions_type        ON decisions(type);
CREATE INDEX IF NOT EXISTS idx_decision_refs_target  ON decision_refs(target_id);
"""


TICKET_STATUSES = (
    "backlog",
    "ready",
    "in_progress",
    "review",
    "done",
    "cancelled",
)

TICKET_TYPES = ("initiative", "epic", "story", "task", "bug")

PRIORITIES = ("critical", "high", "medium", "low")
