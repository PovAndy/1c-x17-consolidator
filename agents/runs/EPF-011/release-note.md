# EPF-011 Release Note

- Added a new diagnostic command on the processing form: `Анализ структуры базы`.
- The command analyzes the current database structure for `ПланыВидовХарактеристик` and reports:
  - duplicate groups by strict structural key
  - elements without `ТипЗначения`
  - total counts per plan
- The feature is intended to establish a factual baseline before further XML load tuning.
