# EPF-002 Impact Map

## Scope
- Privileged mode lifecycle in dedup pipeline.
- Script credential source for decompile/compile pipeline.

## Affected files
- src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl
- scripts/decompile.win.ps1
- scripts/compile.win.ps1

## Expected behavior change
1. Privileged mode is explicitly turned off on successful completion and on exception paths in two critical dedup procedures.
2. Windows scripts can use `EPF_DB_USER` / `EPF_DB_PWD` env vars, reducing hardcoded credential dependency.

## Out of scope
- Algorithmic optimization of GUID patch loop.
- Refactoring chunk parser in predefined extraction.
