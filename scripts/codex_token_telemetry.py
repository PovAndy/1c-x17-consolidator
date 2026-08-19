#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

CODEX_HOME = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser()
SESSION_INDEX = CODEX_HOME / "session_index.jsonl"
SESSIONS_ROOT = CODEX_HOME / "sessions"
DEFAULT_MARKERS = Path("{PROJECT_ROOT}/logs/token-telemetry/stage_markers.jsonl")


def iso_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_ts(s: str) -> datetime:
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def load_jsonl(path: Path):
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            yield json.loads(line)


def session_file_from_id(session_id: str) -> Path | None:
    if not SESSIONS_ROOT.exists():
        return None
    matches = list(SESSIONS_ROOT.rglob(f"*{session_id}.jsonl"))
    if not matches:
        return None
    return max(matches, key=lambda p: p.stat().st_mtime)


def infer_latest_session_id_from_index() -> str | None:
    if not SESSION_INDEX.exists():
        return None
    last = None
    for line in SESSION_INDEX.open("r", encoding="utf-8"):
        line = line.strip()
        if line:
            last = json.loads(line)
    return last.get("id") if last else None


def infer_latest_session_file() -> Path:
    candidates = list(SESSIONS_ROOT.rglob("*.jsonl"))
    if not candidates:
        raise FileNotFoundError(f"No session files under {SESSIONS_ROOT}")
    # Prefer the file that is actively being appended to in this environment.
    # session_index can lag behind for long-lived threads and subagent forks.
    return max(candidates, key=lambda p: p.stat().st_mtime)


def resolve_session_file(args) -> Path:
    if getattr(args, "session_file", None):
        return Path(args.session_file).expanduser().resolve()
    if getattr(args, "session_id", None):
        sf = session_file_from_id(args.session_id)
        if not sf:
            raise FileNotFoundError(f"Session id not found: {args.session_id}")
        return sf
    return infer_latest_session_file()


def estimate_tokens_from_text(text: str) -> int:
    if not text:
        return 0
    # conservative heuristic for mixed RU/EN logs: 1 token ~= 4 chars
    return max(1, len(text) // 4)


@dataclass
class TokenPoint:
    ts: datetime
    total: dict[str, int]
    last: dict[str, int]


def normalize_usage(d: dict[str, Any] | None) -> dict[str, int]:
    keys = [
        "input_tokens",
        "cached_input_tokens",
        "output_tokens",
        "reasoning_output_tokens",
        "total_tokens",
    ]
    d = d or {}
    return {k: int(d.get(k, 0) or 0) for k in keys}


def parse_session(path: Path) -> dict[str, Any]:
    token_points: list[TokenPoint] = []
    tool_calls: list[dict[str, Any]] = []
    tool_outputs: list[dict[str, Any]] = []
    user_msgs: list[dict[str, Any]] = []
    agent_msgs: list[dict[str, Any]] = []
    response_items: Counter[str] = Counter()
    event_types: Counter[str] = Counter()
    session_meta = []

    for obj in load_jsonl(path):
        ts = parse_ts(obj["timestamp"])
        typ = obj.get("type")
        payload = obj.get("payload", {})
        event_types[typ] += 1
        if typ == "session_meta":
            session_meta.append(payload)
        elif typ == "event_msg":
            ptype = payload.get("type")
            if ptype == "token_count" and payload.get("info"):
                info = payload["info"]
                token_points.append(TokenPoint(
                    ts=ts,
                    total=normalize_usage(info.get("total_token_usage")),
                    last=normalize_usage(info.get("last_token_usage")),
                ))
            elif ptype == "user_message":
                user_msgs.append({"ts": ts, "message": payload.get("message", "")})
            elif ptype == "agent_message":
                agent_msgs.append({"ts": ts, "message": payload.get("message", ""), "phase": payload.get("phase")})
        elif typ == "response_item":
            ptype = payload.get("type")
            response_items[ptype] += 1
            if ptype == "function_call":
                tool_calls.append({
                    "ts": ts,
                    "name": payload.get("name"),
                    "arguments": payload.get("arguments", ""),
                    "call_id": payload.get("call_id"),
                })
            elif ptype == "function_call_output":
                out = payload.get("output", "")
                tool_outputs.append({
                    "ts": ts,
                    "call_id": payload.get("call_id"),
                    "chars": len(out),
                    "estimated_tokens": estimate_tokens_from_text(out),
                })

    tool_output_by_call = {x["call_id"]: x for x in tool_outputs if x.get("call_id")}
    tool_stats: dict[str, dict[str, int]] = defaultdict(lambda: {"calls": 0, "output_chars": 0, "estimated_output_tokens": 0, "argument_chars": 0})
    for call in tool_calls:
        name = call.get("name") or "<unknown>"
        tool_stats[name]["calls"] += 1
        tool_stats[name]["argument_chars"] += len(call.get("arguments") or "")
        fo = tool_output_by_call.get(call.get("call_id"))
        if fo:
            tool_stats[name]["output_chars"] += fo["chars"]
            tool_stats[name]["estimated_output_tokens"] += fo["estimated_tokens"]

    totals = token_points[-1].total if token_points else normalize_usage(None)
    return {
        "path": str(path),
        "session_id": path.stem.split("-")[-1],
        "session_meta": session_meta[-1] if session_meta else {},
        "token_points": token_points,
        "totals": totals,
        "tool_calls": tool_calls,
        "tool_outputs": tool_outputs,
        "tool_stats": dict(sorted(tool_stats.items(), key=lambda kv: (-kv[1]["estimated_output_tokens"], kv[0]))),
        "response_items": dict(response_items),
        "event_types": dict(event_types),
        "user_message_count": len(user_msgs),
        "agent_message_count": len(agent_msgs),
        "first_ts": token_points[0].ts.isoformat().replace("+00:00", "Z") if token_points else None,
        "last_ts": token_points[-1].ts.isoformat().replace("+00:00", "Z") if token_points else None,
    }


def last_token_before(token_points: list[TokenPoint], boundary: datetime) -> dict[str, int]:
    current = normalize_usage(None)
    for tp in token_points:
        if tp.ts <= boundary:
            current = tp.total
        else:
            break
    return current


def usage_delta(a: dict[str, int], b: dict[str, int]) -> dict[str, int]:
    return {k: b.get(k, 0) - a.get(k, 0) for k in set(a) | set(b)}


def load_markers(path: Path, session_id: str | None = None):
    if not path.exists():
        return []
    out = []
    for obj in load_jsonl(path):
        if session_id and obj.get("session_id") != session_id:
            continue
        obj["_ts"] = parse_ts(obj["timestamp"])
        out.append(obj)
    out.sort(key=lambda x: x["_ts"])
    return out


def cmd_stage_mark(args) -> int:
    session_file = resolve_session_file(args)
    session_id = session_file.stem.split("-")[-1]
    marker = {
        "timestamp": iso_now(),
        "session_id": session_id,
        "session_file": str(session_file),
        "stage": args.stage,
        "label": args.label,
        "note": args.note,
        "tool_scope": args.tool_scope,
        "kind": args.kind,
    }
    args.markers.parent.mkdir(parents=True, exist_ok=True)
    with args.markers.open("a", encoding="utf-8") as f:
        f.write(json.dumps(marker, ensure_ascii=False) + "\n")
    if args.json:
        print(json.dumps(marker, ensure_ascii=False, indent=2))
    else:
        print(f"[stage-mark] {marker['timestamp']} {marker['stage']} :: {marker['label']} (session={session_id})")
    return 0


def cmd_session_report(args) -> int:
    session_file = resolve_session_file(args)
    data = parse_session(session_file)
    if args.json:
        out = {k: v for k, v in data.items() if k != "token_points"}
        print(json.dumps(out, ensure_ascii=False, indent=2, default=str))
        return 0
    print(f"Session: {data['session_id']}")
    print(f"File: {data['path']}")
    meta = data['session_meta']
    if meta:
        print(f"Model provider: {meta.get('model_provider')}")
        print(f"Agent nickname: {meta.get('agent_nickname')}")
        print(f"Originator: {meta.get('originator')}")
    print(f"Window: {data['first_ts']} .. {data['last_ts']}")
    print("Totals:")
    for k, v in data['totals'].items():
        print(f"  {k}: {v}")
    print(f"User messages: {data['user_message_count']}")
    print(f"Agent messages: {data['agent_message_count']}")
    print("Top tool consumers (by estimated function_call_output tokens):")
    for name, stats in list(data['tool_stats'].items())[: args.top]:
        print(f"  {name}: calls={stats['calls']} est_output_tokens={stats['estimated_output_tokens']} output_chars={stats['output_chars']} arg_chars={stats['argument_chars']}")
    return 0


def cmd_stage_report(args) -> int:
    session_file = resolve_session_file(args)
    data = parse_session(session_file)
    token_points = data['token_points']
    markers = load_markers(args.markers, data['session_id'])
    if not markers:
        raise SystemExit(f"No markers found in {args.markers} for session {data['session_id']}")
    end_ts = token_points[-1].ts if token_points else markers[-1]['_ts']
    stages = []
    for i, marker in enumerate(markers):
        start = marker['_ts']
        raw_end = markers[i + 1]['_ts'] if i + 1 < len(markers) else end_ts
        end = raw_end if raw_end >= start else start
        before = last_token_before(token_points, start)
        after = last_token_before(token_points, end)
        delta = usage_delta(before, after)
        pending = raw_end < start
        tool_counts = Counter()
        est_tool_tokens = Counter()
        for call in data['tool_calls']:
            if start <= call['ts'] < end:
                tool_counts[call.get('name') or '<unknown>'] += 1
        output_by_call = {o['call_id']: o for o in data['tool_outputs'] if o.get('call_id')}
        for call in data['tool_calls']:
            if start <= call['ts'] < end:
                fo = output_by_call.get(call.get('call_id'))
                if fo:
                    est_tool_tokens[call.get('name') or '<unknown>'] += fo['estimated_tokens']
        stages.append({
            'stage': marker['stage'],
            'label': marker.get('label'),
            'kind': marker.get('kind'),
            'note': marker.get('note'),
            'start': start.isoformat().replace('+00:00', 'Z'),
            'end': end.isoformat().replace('+00:00', 'Z'),
            'token_delta': delta,
            'tool_calls': dict(tool_counts),
            'tool_estimated_output_tokens': dict(est_tool_tokens),
            'pending_token_flush': pending,
        })
    if args.json:
        print(json.dumps({'session_id': data['session_id'], 'session_file': data['path'], 'stages': stages}, ensure_ascii=False, indent=2))
        return 0
    print(f"Session: {data['session_id']}")
    for s in stages:
        td = s['token_delta']
        print(f"- {s['stage']} :: {s['label']}")
        print(f"  window: {s['start']} .. {s['end']}")
        print(f"  tokens: input={td['input_tokens']} cached={td['cached_input_tokens']} output={td['output_tokens']} reasoning={td['reasoning_output_tokens']} total={td['total_tokens']}")
        if s.get('pending_token_flush'):
            print("  note: no newer token_count event yet; stage is still pending flush in local session log")
        if s['tool_calls']:
            top_calls = ', '.join(f"{k} x{v}" for k,v in sorted(s['tool_calls'].items(), key=lambda kv:(-kv[1], kv[0]))[:6])
            print(f"  tools: {top_calls}")
        if s['tool_estimated_output_tokens']:
            top_cost = ', '.join(f"{k}~{v}" for k,v in sorted(s['tool_estimated_output_tokens'].items(), key=lambda kv:(-kv[1], kv[0]))[:6])
            print(f"  est tool-output tokens: {top_cost}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Codex token telemetry for session/stage analysis")
    sp = ap.add_subparsers(dest='cmd', required=True)

    p = sp.add_parser('stage-mark', help='Append a stage marker for the current/latest session')
    p.add_argument('--stage', required=True)
    p.add_argument('--label', required=True)
    p.add_argument('--note', default='')
    p.add_argument('--tool-scope', default='all')
    p.add_argument('--kind', default='checkpoint')
    p.add_argument('--markers', type=Path, default=DEFAULT_MARKERS)
    p.add_argument('--session-file')
    p.add_argument('--session-id')
    p.add_argument('--json', action='store_true')
    p.set_defaults(func=cmd_stage_mark)

    p = sp.add_parser('session-report', help='Exact token report from local Codex session JSONL')
    p.add_argument('--session-file')
    p.add_argument('--session-id')
    p.add_argument('--top', type=int, default=12)
    p.add_argument('--json', action='store_true')
    p.set_defaults(func=cmd_session_report)

    p = sp.add_parser('stage-report', help='Stage-level token deltas by joining markers with session token_count events')
    p.add_argument('--session-file')
    p.add_argument('--session-id')
    p.add_argument('--markers', type=Path, default=DEFAULT_MARKERS)
    p.add_argument('--json', action='store_true')
    p.set_defaults(func=cmd_stage_report)

    args = ap.parse_args()
    return args.func(args)


if __name__ == '__main__':
    raise SystemExit(main())
