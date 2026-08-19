# Project Constitution

Purpose:
- keep `epf1129` development stable, reviewable and token-efficient;
- make every serious change pass the same compact engineering loop.

## Authority
This file is the compact top-level operating contract for coding work in this repository.
If a longer runbook conflicts with this file, prefer this file and then reconcile the runbook.

## Core loop
Every non-trivial task follows:
1. Plan
2. Work
3. Check
4. Correct
5. Test
6. Record evidence

Short form:
- `plan -> work -> check -> correct -> test`

## Roles
Use isolated roles instead of one giant context:
- planner
- coder
- tester
- reviewer

For small tasks one person/agent can cover multiple roles, but the role boundaries stay explicit.

## Context rules
- Keep active context narrow.
- Prefer stable project artifacts over long conversational recap.
- When context grows too much, write a checkpoint instead of dragging the whole session forward.
- Do not load large logs or old runs unless they are needed for the current step.

## Memory tiers
1. Procedural memory
- rules, scripts, standard commands, checklists

2. Semantic memory
- domain facts, gotchas, mapping knowledge, architecture

3. Episodic memory
- what happened in a specific run, version, or incident

Store these separately and retrieve only the needed tier.

## Examples-first policy
When a format matters, prefer a short canonical example over a long abstract explanation.
Applicable to:
- plans
- coder packets
- tester packets
- release notes
- recovery notes
- log summaries

## Acceptance rule
A code-bearing step is not finished until we have:
- the change itself;
- a check/review result;
- a test or an explicit runtime gap;
- a short evidence note;
- token telemetry closeout for the task when it is substantial or tool-heavy.

## Token telemetry rule
For every substantial task and every token-spending workflow, token measurement is mandatory.
Minimum required artifacts:
- stage markers for `plan`, `research`, `coder`, `tester`, `deploy`, `checkpoint`;
- session totals from local Codex logs;
- stage-level token deltas stored in project logs.

Operational command baseline:
- `python3 scripts/codex_token_telemetry.py stage-mark --stage <plan|research|coder|tester|deploy|checkpoint> --label "<task-id>" --note "<summary>"`
- `bash scripts/token-stage-report.sh --json`
- if the automatic session resolver is wrong, telemetry must be rerun with `--session-file` or `--session-id`.

A substantial task is not operationally complete until this telemetry is recorded.

## Token optimization rule
Token optimization is mandatory, but never at the expense of correctness, reproducibility or test depth.
Operational defaults:
- minimize shell/tool output before trying to reduce reasoning depth;
- reuse local evidence before re-reading or re-querying;
- prefer chunked/filtered scans over broad scans;
- prefer stable status artifacts over interactive polling;
- for common infrastructure failures, search for an existing professional solution before inventing a new workaround.

## For `118.x` recovery
- diagnostics first;
- preview before fix when the scope is not obvious;
- fix in controlled batches;
- preserve evidence in `docs/recovery-progress-118.md` and `logs/<version>/`.
