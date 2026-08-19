# Entry Points EPF-001

## User-Facing Entry Points
- Form actions for export/import.

## Procedure/Function Entry Points
- `ВыполнитьВыгрузку`
- adaptive import flow (`Адапт_*` parse/write pipeline)
- dedup replacement flow (`Адапт_ОбработатьПорциюЗамен`)

## Event Handlers
- form handlers in processor forms (to inspect before behavior changes).

## External Integrations
- `ОбщегоНазначения.ЗаменитьСсылки`
- XDTO serializer/deserializer

## Notes for Tester
- Mandatory smoke cases: large import, duplicate references, DataVersion conflicts, no-overwrite mode.
