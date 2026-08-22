# GitHub publish scope / Контур публикации GitHub

**Repository / Репозиторий:** `PovAndy/1c-x17-consolidator`

**Audit date / Дата аудита:** 2026-08-22

**Local source / Локальный исходник:** `v25-123.10`
**Remote baseline / Удалённый baseline:** `339c289e2c83001ae4b0b225023e073089c1344b`, source `v25-123.03`

## Allowlist / Разрешённый контур

### Source and functions / Исходники и функции

The following code is source logic and may be published after the data-bound
template is redacted or replaced by a non-production fixture:

Следующая логика является исходным кодом и может публиковаться после удаления
производственных данных из макета или замены его безопасным fixture:

- `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная.xml` — metadata registration.
- `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Ext/ObjectModule.bsl` —
  `Адапт_ВерсияОбработки()` (`v25-123.10`), guarded `[18.8]` READY repair,
  ReadOnly `[18.12]` audit, and `[25.4]` sequential update-blocker pipeline.
- `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form.xml` —
  versioned title, commands and buttons for `[18.8]`, `[18.12]`, and `[25.4]`.
- `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная/Forms/Форма/Ext/Form/Module.bsl` —
  client/server wrappers and long-operation routes for those commands.

The publishable function contracts are:

- `Адапт_ИсправитьREADYНумерациюДокументовСвежейКопии()` — write route is
  restricted to the guarded `postgres3` fresh-copy contour, uses package
  transactions and post-control, and preserves opening-personal-account
  document numbers.
- `Адапт_АудитREADYНумерацииДокументовСвежейКопии()` and
  `Адапт_ПроверитьПланАудитаREADYНумерации12305()` — ReadOnly audit and
  fail-closed registry checks; no object write, delete, direct SQL, or link
  replacement.
- `Адапт_ЗавершитьБлокерыОбновления36_14СвежейКопии()` — sequential `[24.3]`,
  `[24.5]`, `[24.7]`, then ReadOnly `[24.1]`; stop on first error, with child
  transaction boundaries and no outer transaction.

### Tests and read-only tooling / Тесты и read-only-инструменты

These files contain static contracts or read-only helpers and are candidates
for the scoped repository once their paths are kept placeholder-safe:

```text
scripts/epf_test_utils.py
scripts/test_catalog_code_active_predefined_preview.py
scripts/test_catalog_code_final_dedup.py
scripts/test_document_numbering_readonly.py
scripts/test_fresh_copy_catalog_ready_fix.py
scripts/test_fresh_copy_update_blockers_fix.py
scripts/test_fresh_copy_document_numbering_ready_fix.py
scripts/test_regreports_consolidation_preview.py
scripts/test_tis_residual_diagnostic.py
scripts/run-epf-com-direct.win.ps1
scripts/export-tis-residual-donors-com.win.ps1
```

`test_document_numbering_ready_audit.py` remains local-only for now because its
assertions are tied to the production-derived registry; it may enter the
public set only after it is rewritten against a synthetic fixture.

### Documentation / Документация

Publishable documentation consists of reviewed bilingual Markdown such as:

- `README.md` and `README.en.md`;
- `docs/V25-123.10_RELEASE_NOTES_2026-08-22.md`;
- this scope inventory.

## Denylist / Запрещённый контур

The following must not be copied to the public repository:

- `src/.../Templates/ПланАудитаREADYНумерации12305/Ext/Template.txt` in its
  current form: it contains 14,672 production-derived UUID/date/number rows;
- logs, database dumps, XML/CSV exports, context/config dumps, local RAG or
  vector indexes, `.code-index`, build EPF files, temporary files and virtual
  environments;
- `.env`, `.env.*.local`, credentials, tokens, absolute home/Windows bridge
  paths, and the local `compile-with-protected-env.win.ps1` wrapper (it exposes
  a `-SkipAudit` path and belongs to the private environment);
- any live result or claim that cannot be reproduced from public source.

## Publication gate / Ворота сохранения

1. Replace the data-bearing READY registry with a synthetic/non-production
   fixture or keep the `[18.8]/[18.12]` feature outside the public source set.
2. Re-run `epf-validate`, `form-info`, `form-validate`, the scoped static tests,
   `py_compile`, and the bounded Critic QA review.
3. Stage named paths only, scan the staged snapshot for secrets and private
   paths, then compare the post-push remote SHA and version.

Until step 1 is complete, the public repository must not be described as a
complete `v25-123.10` source release.

Пока шаг 1 не выполнен, публичный репозиторий нельзя называть полным
исходным релизом `v25-123.10`.
