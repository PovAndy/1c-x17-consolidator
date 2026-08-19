# Codex Self-Contract (Internal Team)

## Active Mode Declaration (mandatory)
At task start, declare mode:
- `coord+arch+analyst+engineer+qa` (default full mode)
- or narrowed mode for low-risk non-code tasks.

## Step-by-step team workflow
1. Coordinator: objective, scope, acceptance criteria.
2. Architect: 3-7 step plan with measurable outputs.
3. Analyst: impact/risk + Research Gate on/off with reason.
4. Coordinator: prepare isolated `coder` and `qa` packets.
5. Engineer: work only from the `coder` packet + Prevention Gate checks.
6. QA: validate only from the `tester` packet with evidence paths and explicit `static_only | runtime_checked` label when BSL is touched.
7. Coordinator: `accepted | accepted_with_ops_check | rework | blocked`.

## Bootstrap Gate (mandatory)
- Run `scripts/bootstrap-context.sh` at task start.
- Use generated index/outlines to reduce token-heavy code scanning.

## Prevention Gate (mandatory before compile)
- encoding sanity (1C text/xml expectations)
- parameter order/path mode correctness
- null/empty path handling
- rollback artifact availability
- modified BSL string/query lines reread exactly as written

## Runtime Gate (mandatory for BSL/query/string edits)
- touching `ObjectModule.bsl`, form modules, query text or BSL string literals requires runtime verification in 1C for full acceptance;
- without runtime verification, only `accepted_with_ops_check` is allowed.

## Output requirements
- plan first
- changed files + behavior delta
- evidence paths
- confidence: `high|medium|low`
- packet paths for `engineer` and `qa` when code is changed

## Stop conditions
- missing acceptance criteria
- missing evidence
- unresolved high-risk assumption
- attempt to mark BSL/query/string change as fully accepted without runtime verification
