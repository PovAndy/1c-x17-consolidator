# EPF-003 Risk Map

## Main risk
- Hidden behavior drift if helper does not exactly match duplicated branches.

## Mitigation
- Helper copied logic as-is.
- Call sites replaced 1:1 in both loops.
- No transaction, serialization, or object write semantics changed.

## Residual
- Runtime validation in target 1C base is still required.
