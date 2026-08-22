# GitHub publish scope / Контур публикации GitHub

**Repository / Репозиторий:** `PovAndy/1c-x17-consolidator`
**Audit date / Дата аудита:** 2026-08-22
**Source version / Версия исходника:** `v25-123.10`
**Public tag / Публичный тег:** `v25-123.10-public`

## Purpose / Назначение

The repository contains only source and reviewed tests/read-only diagnostics that fix or prevent errors in the 1C x17 processor. Full infrastructure belongs to `1c-nexus-infra` and is not copied here.

Репозиторий содержит только исходники и проверенные тесты/read-only-диагностику, которые исправляют или предупреждают ошибки обработки 1С x17. Полная рабочая среда относится к `1c-nexus-infra` и сюда не переносится.

## Allowlist / Разрешённый контур

- `README.md`, `README.en.md` and the two bilingual documents in `docs/`.
- `src/ВыгрузкаЗагрузкаДанныхXMLАдаптивная.xml` and the EPF XML/BSL source needed for the processor, form, `[18.8]`, `[18.12]`, and `[25.4]` contracts.
- `src/.../Templates/ПланАудитаREADYНумерации12305.xml` plus its three-row synthetic `Template.txt` fixture.
- Selected static tests and read-only contracts under `scripts/`; no credentials or environment configuration.

Разрешены README и двуязычная документация, XML/BSL-исходники обработки, форма, контракты `[18.8]`, `[18.12]`, `[25.4]`, а также синтетический fixture из трёх строк и выбранные статические тесты. Production registry, реальные выгрузки и рабочая среда не входят.

## Synthetic fixture gate / Ворота synthetic fixture

The public `Template.txt` contains exactly three synthetic rows with non-production UUIDs, dates, and numbers. It is a structural test fixture, not an audit result and not a production registry. The source must fail closed on any fixture/checksum/contour mismatch.

Публичный `Template.txt` содержит ровно три синтетические строки с непроизводственными UUID, датами и номерами. Это структурный fixture, а не результат аудита и не рабочий реестр. При несовпадении fixture, контрольной суммы или контура исходник обязан остановиться без записи.

## Denylist / Запрещённый контур

- 1C databases and dumps (`*.1CD`, `*.dt`, `*.cf`, `*.cfe`), backups, archives, and generated EPF/ERF artifacts;
- personal, confidential, or production-derived data: addresses, account numbers, raw UUID lists, document registries, screenshots, raw XML/CSV exports, and logs;
- passwords, API keys, access tokens, private keys, certificates, cookies, connection strings, `.env` values, and credential-bearing command lines;
- full working-environment parameters: real server/database names, hostnames, ports, bridge/proxy/MCP endpoints, absolute paths, provider configuration, RAG/vector indexes, `.code-index`, virtual environments, and runtime logs;
- claims of live execution or production success that cannot be reproduced from the public source.

- базы и дампы 1С, резервные копии, архивы и generated EPF/ERF;
- персональные, конфиденциальные и производственные данные, адреса, номера ЛС, сырые UUID-списки, реестры документов, скриншоты, XML/CSV-выгрузки и логи;
- пароли, ключи, токены, сертификаты, cookies, connection strings, значения `.env` и команды с учётными данными;
- полные параметры рабочей среды: реальные имена серверов и баз, host/port, bridge/proxy/MCP endpoint-ы, абсолютные пути, конфигурация провайдеров, RAG/vector indexes, `.code-index`, виртуальные окружения и runtime-логи;
- неподтверждённые claims о live execution или production-успехе.

## Bilingual documentation gate / Двуязычные документы

Every public version must update both `README.md` and `README.en.md`. Release notes and scope/security documents must contain paired Russian and English sections. A one-language README or release note is a publication failure.

Каждая публичная версия обязана обновлять `README.md` и `README.en.md`. Release notes и документы контура/безопасности должны содержать парные разделы на русском и английском языках. Одноязычный README или release note считается ошибкой публикации.

## Verification gate / Ворота проверки

1. Stage named paths only; inspect the staged snapshot.
2. Run EPF/form validators, scoped static tests, `py_compile`, `git diff --check`, and bounded Critic QA.
3. Scan staged content for secrets, production paths/data, databases, archives, logs, and full environment parameters.
4. Push `main` with the annotated public tag and compare remote SHA, tag target, source version, README pair, release notes, scope document, and fixture hash.

1. Добавлять только именованные пути и проверять staged snapshot.
2. Выполнить EPF/form-валидаторы, scoped static tests, `py_compile`, `git diff --check` и bounded Critic QA.
3. Сканировать staged content на секреты, production paths/data, базы, архивы, логи и полные параметры среды.
4. Отправить `main` с annotated public tag и сравнить remote SHA, цель тега, версию исходника, пару README, release notes, scope document и hash fixture.
