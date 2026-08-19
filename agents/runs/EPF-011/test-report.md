# EPF-011 Test Report

- Static checks:
  - `preflight.sh`: PASS
- Reviewed risks:
  - Form command wiring
  - XML form command/button insertion
  - Read-only PVH analysis query generation
- Runtime still required on Windows:
  - `compile.win.bat`
  - open processing form
  - click `Анализ структуры базы`
  - verify report opens and contains PVH summary
