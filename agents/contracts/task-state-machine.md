# Task State Machine (Lean)

`draft -> planned -> analyzed -> implemented -> tested -> accepted`

Fallback transitions:
- `any -> blocked`
- `tested -> rework`
- `implemented -> rework`
- `tested -> accepted_with_ops_check`

Rules:
- only Lead sets `accepted`
- `tested` requires evidence paths
- for low-risk tasks, `risk-map.md` may be skipped
- `accepted_with_ops_check` is mandatory for BSL/query/string changes when runtime 1C verification is pending
