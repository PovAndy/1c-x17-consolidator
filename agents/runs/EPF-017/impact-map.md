# Impact Map

- Added `BSL Syntax Gate` and `Runtime QA Gate` to runbook.
- QA checklist now distinguishes `static_only` vs `runtime_checked`.
- Tester role now forbids plain `pass` for BSL/query/string changes without runtime 1C verification.
- Codex self-contract and task state machine now support `accepted_with_ops_check` explicitly for pending runtime validation.

## Risk
- Low.
- Process/governance only.
- No runtime behavior change in EPF code.
