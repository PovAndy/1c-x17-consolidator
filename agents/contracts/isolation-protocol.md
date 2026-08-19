# Isolation Protocol

## Goal
Reduce context noise and token usage by giving `engineer` and `qa` only the task-local packet they need.

## Rule
- Do not hand the whole project to `engineer` or `qa`.
- Pass only:
  - objective;
  - acceptance criteria;
  - touched files;
  - relevant snippets or file paths;
  - known risks;
  - required checks.

## Required packets
- `coder-packet.md`
- `tester-packet.md`

## Coder packet contents
- task id
- narrow objective
- exact files allowed for edits
- context paths
- out-of-scope list
- acceptance criteria
- prevention checks

## Tester packet contents
- task id
- changed files
- expected behavior delta
- known risk list
- exact runtime/static checks
- verdict mode: `static_only` or `runtime_checked`

## Hard rules
- `engineer` does not see unrelated artifacts by default.
- `qa` does not see implementation reasoning beyond what is needed to verify behavior.
- If packet scope is insufficient, role returns `blocked` and requests one delta packet, not full project context.
- For BSL/query/string changes, `qa` packet must explicitly state whether runtime 1C verification is required.
