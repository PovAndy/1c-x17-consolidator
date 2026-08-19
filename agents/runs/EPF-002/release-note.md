# EPF-002 Release Note

## Changes
- Hardened dedup privileged mode lifecycle in:
  - `ВыполнитьУдалениеДублей`
  - `Адапт_ОбработатьПорциюЗамен`
- Added environment-variable credential override in:
  - `scripts/decompile.win.ps1`
  - `scripts/compile.win.ps1`

## Ops usage
In Windows CMD/PowerShell before running scripts:
- `set EPF_DB_USER=Администратор`
- `set EPF_DB_PWD=<пароль>`

Fallback to existing embedded credentials is preserved.
