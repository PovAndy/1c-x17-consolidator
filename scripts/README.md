# Scripts

Назначение:
- держать в `scripts/` только актуальные и повторно используемые инструменты проекта.

## Основные рабочие скрипты

1. Сборка:
- `compile.win.ps1`

2. Выкладка:
- `deploy-build-to-server.win.ps1`

3. Открытие базы:
- `open-base.win.ps1`

4. Housekeeping:
- `workspace-housekeeping.sh`

5. Быстрый поиск:
- `find-project-asset.sh`
- `find-archive.sh`
- `find-archive-context.sh`

6. Работа с дампами конфигурации:
- `dump-config.win.ps1`
- `copy-config-dump-to-linux.sh`

7. Bootstrap runtime:
- `bootstrap-local-onescript-runtime.sh`

## Runtime baseline

1. Основной compile/decompile путь проекта:
- Windows bridge (`compile.win.ps1`, `decompile.win.ps1`)

2. Legacy shell scripts:
- `compile.sh`
- `decompile.sh`
- автоматически fallback'ятся к `EPF_DB_USER` / `EPF_DB_PWD`, если `DB_USER` / `DB_PWD` не заданы отдельно

3. OneScript runtime:
- рабочие `oscript` и `opm` перекрыты в `~/.local/bin`
- `vrunner` использует `{WORKSPACE_ROOT}/venv/bin/oscript`
- `Vanessa-ADD` доступен через symlink:
  - `{WORKSPACE_ROOT}/venv/lib/add -> {WORKSPACE_ROOT}/add`
- при повторной инициализации среды использовать:
  - `scripts/bootstrap-local-onescript-runtime.sh`

## Правило

Version-specific и одноразовые скрипты не держать в активной зоне.
Переносить их в:
- `Archive/scripts/versioned-copy/`

Актуальная структура скриптов отражена в:
- `scripts/MANIFEST.csv`

## SQL read-only diagnostics
- `sql_ro_probe.py`: connection smoke-check for direct PostgreSQL read-only access to `MergedBase`
- `sql_ro_query.py`: safe runner for read-only SQL templates and ad-hoc `SELECT`/`WITH`/`EXPLAIN` queries
- `inventory-critical-catalog-duplicates-com.win.ps1`: read-only inventory of duplicate codes/names in curated critical catalogs; validated on file bases, intended as the first step before any duplicate-index corrective plan

## Дампы конфигурации
- `dump-config.win.ps1`: штатная распаковка конфигурации 1С на Windows-сторону
- `copy-config-dump-to-linux.sh`: перенос распакованного дампа из `T:\\1S\\wsl_exchange\\work_epf_112_9\\config-dumps\\...` в локальную Linux-копию проекта для быстрого анализа через `rg`, `inspect` и обычные текстовые инструменты

## Token telemetry
- `token-stage-mark.sh`: mandatory stage marker (`plan`, `research`, `coder`, `tester`, `deploy`, `checkpoint`)
- `token-stage-report.sh`: stage-level token deltas from local Codex session logs
- `token-session-report.sh`: exact cumulative session totals from local Codex session logs
- `token-closeout.sh`: one-shot closeout that writes both reports to `logs/token-telemetry/`
- `token-usage-report.sh`: wrapper over `@ccusage/codex` for ad-hoc daily/monthly/session baseline reports
- operational runbook: `docs/token-telemetry-runbook-20260411.md`

Mandatory working rule:
- use telemetry on every substantial task;
- keep shell output minimal by default;
- prefer chunked scans and compact reports over broad dumps;
- prefer status/report files over interactive polling where possible.
