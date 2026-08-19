# EPF-012 Test Report

- Static:
  - `preflight.sh`: PASS
- Verified manually in code:
  - metadata-aware query generation
  - no unconditional use of optional fields `ЭтоГруппа`, `Родитель`, `Код`
  - dedicated form command wiring added
- Runtime pending:
  - Windows compile
  - open processing
  - run `Анализ структуры базы`
  - run `Исправить дубли ПВХ`
  - run `Анализ структуры базы` again and compare totals
