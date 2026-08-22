# 1c-x17-consolidator

Public source repository for the 1C external processor `ВыгрузкаЗагрузкаДанныхXMLАдаптивная` and the reviewed checks that fix errors in the 1C x17 project.

Russian reference: [README.md](README.md).

## Version and publication boundary

- Processor source version: **v25-123.10**.
- GitHub public release: **v25-123.10-public**.
- The release contains only processor source, a safe synthetic fixture, scoped static tests, read-only contracts, and bilingual documentation.
- Production registries, 1C databases, archives, logs, dumps, generated EPF/ERF files, keys, tokens, passwords, confidential data, and full working-environment parameters are excluded.
- The complete working environment is maintained separately in [1c-nexus-infra](https://github.com/PovAndy/1c-nexus-infra); this repository does not replace it.

## Published scope

- `[18.8]` — guarded batch READY-numbering repair with protection for personal-account-opening document numbers and post-control.
- `[18.12]` — ReadOnly READY-numbering audit covering structure, UUID, dates, numbers, and MD5.
- `[25.4]` — sequential 36.14 update-blocker pipeline with stop-on-error and separate stage transactions.
- `src/` — XML/BSL source of the external processor and its forms.
- `scripts/` — selected static tests and read-only contracts for these fixes only.
- `src/.../Templates/ПланАудитаREADYНумерации12305/Ext/Template.txt` — three fully synthetic rows; it is not a production export.

The public fixture is intentionally not a production registry. `[18.8]` and `[18.12]` fail closed when the fixture or contour does not match; this repository is not authorization to write to a live database.

## Publication checks

Each version is checked with `epf-validate`, `form-info`, `form-validate`, scoped static tests, `py_compile`, `git diff --check`, secret scanning, and a post-push SHA/tag/version audit. No Designer build or live execution is claimed without separate evidence.

See [v25.10 release notes](docs/V25-123.10_RELEASE_NOTES_2026-08-22.md) and the [publication scope](docs/GITHUB_PUBLISH_SCOPE_2026-08-22.md).

## Publication security

Every update is reviewed against an explicit path allowlist. Archives, 1C databases and dumps, generated artifacts, raw XML/CSV exports, logs, screenshots, personal or production data, secrets and credential-bearing command lines, real host/database names, ports/endpoints, absolute paths, `.env` files, virtual environments, local indexes/RAG, and full working-environment configuration are forbidden.
