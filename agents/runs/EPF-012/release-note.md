# EPF-012 Release Note

- Added a dedicated safe operation: `Исправить дубли ПВХ`.
- Operation is limited to:
  - `икХарактеристикиОбъектовУчета`
  - `икХарактеристикиПрочихОбъектов`
- Dedup key is strict:
  - `ЭтоГруппа + Наименование + Код + Родитель + ТипЗначения`
- Output is a markdown report for audit and follow-up validation.
