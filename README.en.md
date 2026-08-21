# 1c-x17-consolidator

`1c-x17-consolidator` contains the XML sources of the external 1C:Enterprise
data processor **ВыгрузкаЗагрузкаДанныхXMLАдаптивная** and the supporting
read-only diagnostics for the consolidated x17 database.

## Scope

- Safe consolidation, integrity diagnostics, and recovery preparation for a
  1C 8.3 GKH/utility-management database.
- XML/BSL source of the external processor under `src/`.
- Supporting scripts, read-only SQL diagnostics, recovery notes, and operating
  runbooks under `scripts/`, `sql/readonly/`, and `docs/`.

The detailed Russian document remains the canonical project reference:
[README.md](README.md).

## Repository safety boundary

The repository contains reviewed source and reproducible documentation. It must
not contain passwords, tokens, local `.env` files, virtual environments, local
index databases, generated runtime logs, or unreviewed build output.

Every version is release-ready only after scoped review, structural EPF/form
validation, applicable BSL validation, an actual Designer build, and a
post-push comparison of the remote commit and source version. A local dirty
worktree is not a released version.

## Current remote snapshot

At the GitHub audit on 2026-08-21, `main` was
`29cc956e1ac9f38c3c4b4dbf28edd32625caa187`; its source declared
`v25-123.03`. This is a snapshot fact, not a claim about later local work.

## Documentation

- [Russian project reference](README.md)
- [Recovery/update checkpoint](docs/X17_RECOVERY_UPDATE_36_14_CHECKPOINT_2026-08-14.md)
