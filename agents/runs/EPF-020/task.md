# EPF-020

## Goal
Add a read-only diagnostic report for lost links:
- `Вид объекта учёта` in `Документ.икОткрытиеЛицевогоСчета`
- service linkage for personal accounts (`Лицевой счёт -> Услуга`)

## Scope
- New form button and command
- Server-side markdown report
- Runtime metadata inspection
- Read-only queries for document and service-link registers

## Out of Scope
- Data recovery
- Loader fix
- Any write operation in target infobase

## Acceptance
- The form exposes a separate diagnostics command
- The report shows detected fields and problem counters
- No data changes are performed
