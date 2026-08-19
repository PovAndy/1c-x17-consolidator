# Impact Map

- Fixed organizations analysis query in `ObjectModule.bsl`.
- Added `ЕстьОшибкаАнализа` flag to organizations analysis result.
- Updated readiness verdict logic to treat organizations-analysis failure as `WARN`.
- Bumped processing version to `v25-113.8`.

## Risk
- Low.
- Read-only analysis/reporting logic only.
- No intended change to XML load/write behavior.
