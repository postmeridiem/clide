"""Markdown parser for decisions/*.md.

Yields `Record` dicts with id, type, domain, title, status, date,
file_path, and a list of (target_id, ref_type, note) cross-refs.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

HEADING_RE = re.compile(r"^###\s+((?:D|Q|R)-\d+):\s+(.+)$")
DATE_RE = re.compile(r"^\s*-\s+\*\*(?:Date|Rejected):\*\*\s+(\d{4}-\d{2}-\d{2})")
STATUS_RE = re.compile(r"^\s*-\s+\*\*Status:\*\*\s+(.+)")
SUPERSEDES_RE = re.compile(r"^\s*-\s+\*\*Supersedes:\*\*", re.IGNORECASE)
SUPERSEDED_BY_RE = re.compile(r"^\s*-\s+\*\*Superseded\s+by:\*\*", re.IGNORECASE)
RESOLVES_RE = re.compile(r"^\s*-\s+\*\*Resolves:\*\*", re.IGNORECASE)
DEPENDS_RE = re.compile(r"^\s*-\s+\*\*Depends\s+on:\*\*", re.IGNORECASE)
AMENDS_RE = re.compile(r"^\s*\*\*Amendment\s*\(", re.IGNORECASE)
CROSS_REF_RE = re.compile(r"^\s*-\s+\*\*Cross-reference:\*\*", re.IGNORECASE)
REF_ID_RE = re.compile(r"(?:D|Q|R|T)-\d+")

TYPE_FROM_PREFIX = {"D": "confirmed", "Q": "question", "R": "rejected"}


@dataclass
class Record:
    id: str
    type: str
    domain: str
    title: str
    status: str
    date: str | None
    file_path: str
    refs: list[tuple[str, str, str]] = field(default_factory=list)


def _infer_status(rec_type: str, title: str, body: list[str]) -> str:
    if rec_type == "rejected":
        return "active"
    for line in body:
        if SUPERSEDED_BY_RE.match(line):
            return "superseded"
    if rec_type == "question":
        for line in body:
            m = STATUS_RE.match(line)
            if not m:
                continue
            s = m.group(1).strip().lower()
            if "partial" in s or "remaining" in s:
                return "open"
            if s.startswith("resolved"):
                return "resolved"
            return "open"
        return "open"
    return "active"


def _extract_date(body: list[str]) -> str | None:
    for line in body:
        m = DATE_RE.match(line)
        if m:
            return m.group(1)
    return None


def _extract_refs(rec_id: str, body: list[str]) -> list[tuple[str, str, str]]:
    refs: list[tuple[str, str, str]] = []
    seen: set[tuple[str, str]] = set()
    for line in body:
        if SUPERSEDES_RE.match(line):
            ref_type = "supersedes"
        elif SUPERSEDED_BY_RE.match(line):
            ref_type = "references"
        elif RESOLVES_RE.match(line):
            ref_type = "resolves"
        elif DEPENDS_RE.match(line):
            ref_type = "depends_on"
        elif AMENDS_RE.match(line):
            ref_type = "amends"
        else:
            ref_type = "references"
        for target in REF_ID_RE.findall(line):
            if target == rec_id or target.startswith("T-"):
                # T-NNN refs are ticket→decision, not decision↔decision
                continue
            key = (target, ref_type)
            if key in seen:
                continue
            seen.add(key)
            note = line.strip().lstrip("- ").rstrip()
            if len(note) > 200:
                note = note[:197] + "..."
            refs.append((target, ref_type, note))
    return refs


def parse_file(path: Path, repo_root: Path) -> list[Record]:
    domain = path.stem
    if domain.startswith("questions-"):
        domain = domain[len("questions-"):]
    rel_path = str(path.relative_to(repo_root))
    text = path.read_text(encoding="utf-8")

    records: list[Record] = []
    cur_id: str | None = None
    cur_title: str | None = None
    cur_body: list[str] = []

    def flush() -> None:
        nonlocal cur_id, cur_title, cur_body
        if cur_id is None:
            return
        rec_type = TYPE_FROM_PREFIX[cur_id[0]]
        records.append(
            Record(
                id=cur_id,
                type=rec_type,
                domain=domain,
                title=(cur_title or "").strip(),
                status=_infer_status(rec_type, cur_title or "", cur_body),
                date=_extract_date(cur_body),
                file_path=rel_path,
                refs=_extract_refs(cur_id, cur_body),
            )
        )
        cur_id = None
        cur_title = None
        cur_body = []

    for line in text.split("\n"):
        m = HEADING_RE.match(line)
        if m:
            flush()
            cur_id = m.group(1)
            cur_title = m.group(2)
            cur_body = []
        elif cur_id is not None:
            if line.strip() == "---":
                flush()
            else:
                cur_body.append(line)
    flush()
    return records


def parse_all(repo_root: Path) -> tuple[list[Record], list[str]]:
    decisions_dir = repo_root / "decisions"
    if not decisions_dir.is_dir():
        return [], [f"decisions/ not found at {decisions_dir}"]
    records: list[Record] = []
    warnings: list[str] = []
    for path in sorted(decisions_dir.glob("*.md")):
        if path.name.lower() == "readme.md":
            continue
        try:
            records.extend(parse_file(path, repo_root))
        except Exception as exc:  # noqa: BLE001 - we want a useful warning
            warnings.append(f"error parsing {path.name}: {exc}")
    return records, warnings


def validate(repo_root: Path) -> tuple[bool, list[str]]:
    """Return (ok, errors). Non-zero errors fail push-check."""
    records, warnings = parse_all(repo_root)
    errors: list[str] = list(warnings)

    ids_seen: dict[str, str] = {}
    for rec in records:
        if rec.id in ids_seen and ids_seen[rec.id] != rec.file_path:
            errors.append(
                f"duplicate id {rec.id}: {ids_seen[rec.id]} and {rec.file_path}"
            )
        ids_seen[rec.id] = rec.file_path
        if not rec.title:
            errors.append(f"{rec.id}: empty title")

    known = set(ids_seen)
    for rec in records:
        for target, ref_type, _ in rec.refs:
            if target not in known:
                errors.append(
                    f"{rec.id} → {target} ({ref_type}): target not found"
                )

    return (len(errors) == 0), errors


def next_id(repo_root: Path, prefix: str) -> str:
    prefix = prefix.upper()
    if prefix not in TYPE_FROM_PREFIX:
        raise ValueError(f"invalid prefix {prefix!r} — must be D, Q, or R")
    records, _ = parse_all(repo_root)
    highest = 0
    for rec in records:
        if rec.id.startswith(f"{prefix}-"):
            try:
                highest = max(highest, int(rec.id.split("-", 1)[1]))
            except ValueError:
                continue
    return f"{prefix}-{highest + 1:03d}"
