# KPI Matrix (Efficiency + Reliability)

## Core KPIs
- `pipeline_success_rate`: successful compile/decompile runs per day.
- `preflight_pass_rate`: passed preflight runs per day.
- `rework_rate`: tasks that return from tested -> rework.
- `artifact_minimality`: required artifacts only for low-risk tasks.
- `log_compression_usage`: percent of failures with compressed summary.
- `research_gate_precision`: percent of triggered Research Gate tasks that actually used external evidence.

## Target thresholds
- pipeline_success_rate >= 90%
- preflight_pass_rate >= 85%
- rework_rate <= 20%
- artifact_minimality >= 80%
- log_compression_usage = 100% on failures
- research_gate_precision >= 90%

## Reporting cadence
- quick snapshot per task in `test-report.md`
- weekly review in `agents/runs/KPI-YYYY-WW.md`
