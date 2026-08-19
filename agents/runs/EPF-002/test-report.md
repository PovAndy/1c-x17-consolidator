# EPF-002 Test Report

## Static checks
- `rg -n "^Процедура ВыполнитьУдалениеДублей|^Процедура Адапт_ОбработатьПорциюЗамен|УстановитьПривилегированныйРежим\(" src/.../ObjectModule.bsl`
- Verified explicit `УстановитьПривилегированныйРежим(Ложь)` in both procedures on normal and exception paths.
- `sed -n` inspection confirmed no syntax corruption in modified blocks.

## Script checks
- `decompile.win.ps1` now reads `EPF_DB_USER/EPF_DB_PWD` with fallback.
- `compile.win.ps1` now reads `EPF_DB_USER/EPF_DB_PWD` with fallback.

## Not executed
- Real decompile/compile runtime in Windows Designer (cannot run from this Linux session).
