# Risk Map EPF-001

## High Risks
- Breaking XML wrapper namespaces (`core`, `xsi`, `v8`).
- Changing DataVersion bypass behavior.
- Altering reference replacement map semantics.

## Medium Risks
- Progress/ETA regressions.
- Smart merge flag behavior drift.

## Low Risks
- Logging message wording.
- Non-functional report text.

## Regression Triggers
- Large file import (>100MB+).
- Duplicate references in dictionaries/PVH.
- Empty subkonto / undefined typed values.

## Mitigations
- Keep parser and wrapper structure intact.
- Patch only isolated blocks with explicit before/after logs.
- Validate with decompile->compile->smoke import loop.
