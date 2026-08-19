# Coder Packet

## Objective
Implement a separate read-only diagnostics path for lost links after XML import.

## Files In Scope
- `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl`
- `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form.xml`
- `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form/Module.bsl`

## Constraints
- No write operations to business data
- Version bump required
- Keep output as markdown report
- Prefer runtime metadata inspection over hardcoded schema assumptions

## Deliverable
- New command/button `Диагностика ЛС/услуг`
- Exported object-module function that returns report structure
