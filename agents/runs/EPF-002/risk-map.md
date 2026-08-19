# EPF-002 Risk Map

## Mitigated
- `CRITICAL`: leaked privileged mode (`УстановитьПривилегированныйРежим(Истина)` without guaranteed reset).
- `SECURITY`: fixed reliance on embedded creds by adding env-based override.

## Residual
- `HIGH`: O(N*M) replacement loop in `Адапт_ПрочитатьОбъектКакТекст` remains.
- `MEDIUM`: block parser in `Адапт_БыстроИзвлечьПредопределенные` remains fragile.
- `MEDIUM`: some catch blocks still suppress context without enriched logging.
