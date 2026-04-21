"""`plan decisions …` subcommands."""
from __future__ import annotations

import argparse
import sys

from . import db, parser, repo_decisions
from .format import emit, rows_to_dicts


def add_subparsers(parent: argparse._SubParsersAction) -> None:
    p = parent.add_parser("decisions", help="decisions subcommands")
    sub = p.add_subparsers(dest="subcmd", required=True)

    sub.add_parser("sync", help="parse decisions/*.md → upsert into sqlite")
    sub.add_parser("validate", help="dry-run parser; exit non-zero on errors")

    claim = sub.add_parser("claim", help="print next available D/Q/R id")
    claim.add_argument("prefix", choices=["D", "Q", "R"])
    claim.add_argument("domain", nargs="?")
    claim.add_argument("title", nargs="*")

    ls = sub.add_parser("list", help="list decisions")
    ls.add_argument("--type", choices=["confirmed", "question", "rejected"])
    ls.add_argument("--domain")
    ls.add_argument("--status")
    ls.add_argument("--output", choices=["table", "json"])

    show = sub.add_parser("show", help="show a decision")
    show.add_argument("id")
    show.add_argument("--with-refs", action="store_true")
    show.add_argument("--with-tickets", action="store_true")
    show.add_argument("--output", choices=["table", "json"])

    cov = sub.add_parser("coverage", help="D-records without implementing tickets")
    cov.add_argument("--output", choices=["table", "json"])


def dispatch(args: argparse.Namespace) -> int:
    root = db.repo_root()

    if args.subcmd == "sync":
        conn = db.connect(root)
        try:
            result = repo_decisions.sync(conn, root)
        finally:
            conn.close()
        emit(result, mode="json" if not sys.stdout.isatty() else "table")
        return 0

    if args.subcmd == "validate":
        ok, errors = parser.validate(root)
        if ok:
            print("decisions validate: ok")
            return 0
        for err in errors:
            print(f"error: {err}", file=sys.stderr)
        return 1

    if args.subcmd == "claim":
        new_id = parser.next_id(root, args.prefix)
        if args.domain is None:
            print(new_id)
            return 0
        title = " ".join(args.title) if args.title else "(unclaimed)"
        print(f"{new_id}  {args.domain}  {title}")
        print(
            "(claim is advisory in the stopgap — write the record to "
            f"decisions/{args.domain}.md manually, then `plan decisions sync`)"
        )
        return 0

    conn = db.connect(root)
    try:
        if args.subcmd == "list":
            rows = repo_decisions.list_decisions(
                conn, type_=args.type, domain=args.domain, status=args.status
            )
            emit(rows_to_dicts(rows), mode=args.output)
            return 0

        if args.subcmd == "show":
            row = repo_decisions.get(conn, args.id)
            if row is None:
                print(f"error: {args.id} not found", file=sys.stderr)
                return 3
            data: dict = dict(row)
            if args.with_refs:
                data["refs"] = rows_to_dicts(repo_decisions.refs_of(conn, args.id))
            if args.with_tickets:
                data["tickets"] = rows_to_dicts(
                    repo_decisions.tickets_for(conn, args.id)
                )
            emit(data, mode=args.output)
            return 0

        if args.subcmd == "coverage":
            rows = repo_decisions.coverage(conn)
            emit(rows_to_dicts(rows), mode=args.output)
            return 0
    finally:
        conn.close()

    return 1
