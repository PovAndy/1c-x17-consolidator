# EPF-015

## Goal
Fix organizations quick-check query compatibility in 1C query language and restore honest preflight verdict for the database readiness report.

## Scope
- replace problematic `НЕ ... ПУСТАЯСТРОКА(...)` condition with compatible non-empty key filter;
- bump processing version;
- validate with preflight.
