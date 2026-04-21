"""`plan ticket …` subcommands."""
from __future__ import annotations

import argparse
import sys

from . import db, repo_tickets
from .format import emit, emit_board, rows_to_dicts


def add_subparsers(parent: argparse._SubParsersAction) -> None:
    p = parent.add_parser("ticket", help="ticket subcommands")
    sub = p.add_subparsers(dest="subcmd", required=True)

    new = sub.add_parser("new", help="create a ticket")
    new.add_argument("type", choices=["initiative", "epic", "story", "task", "bug"])
    new.add_argument("title")
    new.add_argument("--parent")
    new.add_argument("--priority", choices=["critical", "high", "medium", "low"], default="medium")
    new.add_argument("--decision", dest="decision_ref")
    new.add_argument("--team")
    new.add_argument("--description")

    ls = sub.add_parser("list", help="list tickets")
    ls.add_argument("--status")
    ls.add_argument("--team")
    ls.add_argument("--assigned")
    ls.add_argument("--decision")
    ls.add_argument("--label")
    ls.add_argument("--output", choices=["table", "json"])

    show = sub.add_parser("show", help="show a ticket")
    show.add_argument("id")
    show.add_argument("--with-decision", action="store_true")
    show.add_argument("--with-blockers", action="store_true")
    show.add_argument("--with-children", action="store_true")
    show.add_argument("--output", choices=["table", "json"])

    st = sub.add_parser("status", help="change status")
    st.add_argument("id")
    st.add_argument("new_status", choices=[
        "backlog", "ready", "in_progress", "review", "done", "cancelled",
    ])

    asg = sub.add_parser("assign", help="assign to agent")
    asg.add_argument("id")
    asg.add_argument("agent")

    tm = sub.add_parser("team", help="set team")
    tm.add_argument("id")
    tm.add_argument("team")

    blk = sub.add_parser("block", help="mark <id> as blocked by <other>")
    blk.add_argument("id")
    blk.add_argument("--by", required=True, dest="by")

    ublk = sub.add_parser("unblock", help="remove a blocker")
    ublk.add_argument("id")
    ublk.add_argument("--from", required=True, dest="from_")

    lbl = sub.add_parser("label", help="add/rm labels")
    lbl.add_argument("id")
    lbl.add_argument("op", choices=["add", "rm"])
    lbl.add_argument("label")

    srch = sub.add_parser("search", help="search title + description")
    srch.add_argument("query")
    srch.add_argument("--output", choices=["table", "json"])

    brd = sub.add_parser("board", help="kanban columns")
    brd.add_argument("--team")
    brd.add_argument("--output", choices=["table", "json"])


def dispatch(args: argparse.Namespace) -> int:
    conn = db.connect()
    try:
        if args.subcmd == "new":
            tid = repo_tickets.create(
                conn,
                type_=args.type,
                title=args.title,
                description=args.description,
                parent_id=args.parent,
                priority=args.priority,
                decision_ref=args.decision_ref,
                team=args.team,
            )
            print(tid)
            return 0

        if args.subcmd == "list":
            rows = repo_tickets.list_(
                conn,
                status=args.status,
                team=args.team,
                assigned=args.assigned,
                decision=args.decision,
                label=args.label,
            )
            emit(rows_to_dicts(rows), mode=args.output)
            return 0

        if args.subcmd == "show":
            row = repo_tickets.get(conn, args.id)
            if row is None:
                print(f"error: {args.id} not found", file=sys.stderr)
                return 3
            data: dict = dict(row)
            if args.with_decision and row["decision_ref"]:
                dec = conn.execute(
                    "SELECT * FROM decisions WHERE id = ?", (row["decision_ref"],)
                ).fetchone()
                data["decision"] = dict(dec) if dec else None
            if args.with_blockers:
                data["blocked_by"] = rows_to_dicts(repo_tickets.blockers(conn, args.id))
            if args.with_children:
                data["children"] = rows_to_dicts(repo_tickets.children(conn, args.id))
            emit(data, mode=args.output)
            return 0

        if args.subcmd == "status":
            n = repo_tickets.set_status(conn, args.id, args.new_status)
            if n == 0:
                print(f"error: {args.id} not found", file=sys.stderr)
                return 3
            print(f"{args.id} → {args.new_status}")
            return 0

        if args.subcmd == "assign":
            n = repo_tickets.set_field(conn, args.id, "assigned_to", args.agent)
            if n == 0:
                print(f"error: {args.id} not found", file=sys.stderr)
                return 3
            print(f"{args.id} assigned to {args.agent}")
            return 0

        if args.subcmd == "team":
            n = repo_tickets.set_field(conn, args.id, "team", args.team)
            if n == 0:
                print(f"error: {args.id} not found", file=sys.stderr)
                return 3
            print(f"{args.id} team = {args.team}")
            return 0

        if args.subcmd == "block":
            repo_tickets.block(conn, args.id, args.by)
            print(f"{args.id} blocked by {args.by}")
            return 0

        if args.subcmd == "unblock":
            n = repo_tickets.unblock(conn, args.id, args.from_)
            if n == 0:
                print(f"(no such blocker)")
            else:
                print(f"{args.id} unblocked from {args.from_}")
            return 0

        if args.subcmd == "label":
            if args.op == "add":
                repo_tickets.label_add(conn, args.id, args.label)
            else:
                repo_tickets.label_rm(conn, args.id, args.label)
            print(f"{args.id} labels {args.op} {args.label}")
            return 0

        if args.subcmd == "search":
            rows = repo_tickets.search(conn, args.query)
            emit(rows_to_dicts(rows), mode=args.output)
            return 0

        if args.subcmd == "board":
            columns = repo_tickets.board(conn, team=args.team)
            emit_board(columns, mode=args.output)
            return 0
    finally:
        conn.close()
    return 1
