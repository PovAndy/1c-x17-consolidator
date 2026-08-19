#!/usr/bin/env python3
"""Управление очередью нативного fallback Codex."""

from __future__ import annotations

import argparse
import json

from omvl_resilience import ResilienceStore


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list")
    show = sub.add_parser("show")
    show.add_argument("--task-id", required=True)
    claim = sub.add_parser("claim")
    claim.add_argument("--task-id", required=True)
    claim.add_argument("--agent", required=True)
    finish = sub.add_parser("finish")
    finish.add_argument("--task-id", required=True)
    finish.add_argument("--status", choices=("complete", "stop"), required=True)
    finish.add_argument("--evidence-ref", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    store = ResilienceStore()
    if args.command == "list":
        print(json.dumps(store.list_pending(), ensure_ascii=False, indent=2))
        return 0
    if args.command == "show":
        print(store.work_order_path(args.task_id).read_text(encoding="utf-8"), end="")
        return 0
    if args.command == "claim":
        order = store.claim_native(args.task_id, args.agent)
        print(json.dumps({"task_id": args.task_id, "status": order["status"], "agent": args.agent}, ensure_ascii=False))
        return 0
    store.finish_native(args.task_id, args.status, args.evidence_ref)
    print(json.dumps({"task_id": args.task_id, "status": args.status}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
