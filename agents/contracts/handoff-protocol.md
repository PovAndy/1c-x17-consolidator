# Handoff Protocol (Lean+Reliable)

## Sequence
1. Lead -> Analyst
2. Analyst -> Engineer
3. Engineer -> QA
4. QA -> Lead

## Packet Rules
- Use message schema JSON.
- Max 12 lines equivalent.
- Include only deltas and evidence paths.

## Required Fields
- `task_id`, `from_role`, `to_role`, `status`
- `summary` (<= 240 chars)
- `artifacts` (paths)
- `risks` (0-3 bullets)
- `next_action`
- `confidence` (`high|medium|low`)

## Source Evidence Rule
When Research Gate is triggered, handoff must include:
- at least 1 primary source link;
- relevance note per source;
- extraction date.

## Stop Conditions
- no measurable acceptance criteria
- missing evidence paths
- unresolved high-risk item without mitigation
- missing source evidence when Research Gate required it
