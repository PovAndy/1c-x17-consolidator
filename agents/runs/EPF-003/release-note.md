# EPF-003 Release Note

## Type
- Safe refactor (no intended behavior change)

## Summary
- Extracted duplicated Smart Merge existence check into helper:
  - `Адапт_НужноПропуститьСуществующийОбъект`
- Replaced two duplicated branches in `Адапт_ЗаписатьПакетОбъектов_Safe` with helper calls.

## Baseline
- Saved stable artifact:
  - `build/releases/v112_9_baseline_2026-03-12.epf`

## Validation status
- Static checks passed.
- Runtime smoke in target 1C base: pending.
