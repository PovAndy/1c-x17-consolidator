# Codex Orchestration: Internal Team -> External Agents

## Principle
Codex internal team works first, then manages external agent artifacts under the main project plan.

## Orchestration sequence
1. Internal team run (coord/arch/analyst/engineer/qa).
2. Emit/refresh external artifacts:
- `task.md`
- `impact-map.md`
- `test-report.md`
- `release-note.md`
3. Update `agents/state/board.md`.
4. If needed, engage optional packager for release bundle.

## Escalation policy
- If high-risk unresolved: stop and mark `blocked`.
- If hypothesis uncertain >= 20%: trigger Research Gate.
- If evidence incomplete: no acceptance.
