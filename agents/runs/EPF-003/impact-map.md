# EPF-003 Impact Map

## Goal
Safe refactor without behavior change: eliminate duplicated Smart Merge existence check.

## Files
- src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl

## Change
- Added helper `Адапт_НужноПропуститьСуществующийОбъект`.
- Reused helper in both packet write loops of `Адапт_ЗаписатьПакетОбъектов_Safe`.

## Expected effect
- Single source of truth for skip logic.
- Lower risk of divergence in future edits.
