# EPF-012 Impact Map

- Scope: targeted deduplication for two PVH objects only:
  - `икХарактеристикиОбъектовУчета`
  - `икХарактеристикиПрочихОбъектов`
- Added:
  - strict-key dedup logic in object module
  - dedicated UI command/button for safe execution
  - markdown result report
- Safety:
  - does not use generic dedup over all selected metadata
  - limited to two known-problem PVH
  - uses existing reference replacement + soft delete pipeline
