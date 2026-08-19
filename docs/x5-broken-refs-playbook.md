# X5 Broken Refs Playbook

Purpose:
- test donor-based recovery of broken refs before applying the same approach to `x17_pg2`.

## Scope
This playbook is for the `other-pvh` layer:
- `ПВХ.икХарактеристикиПрочихОбъектов`
- `РегистрСведений.икХарактеристикиПрочихОбъектов`

## Principle
1. Read facts from target.
2. Export live donor data from source bases.
3. Normalize and build `restore_map.csv`.
4. Run preview first.
5. Fix only on a disposable polygon (`x5` test copy or equivalent).
6. Re-run the same map on `x17_pg2` only after evidence.

## Donor export
Primary path:
- use the built-in XML export of the EPF from donor bases, with `ДополнительныеОбъектыДляВыгрузки`
- prefer exporting the exact donor PVH elements and related register/object rows through the same processing that we already trust for transfer

Secondary helper path:
- `scripts/export-other-pvh-recovery-com.win.ps1`
- use only as a probe or fallback when we need quick donor fact collection outside the main XML exchange path

Recommended aliases:
- `x1_01`
- `x1_10`
- `x1_14`
- `x1_20`
- `x1_21`
- plus any available donor polygon such as `x5`

## Normalization
Run:
```bash
python3 {PROJECT_ROOT}/scripts/normalize-other-pvh-exports.py \
  --inbox {PROJECT_ROOT}/context/recovery/other-pvh/inbox \
  --out {PROJECT_ROOT}/context/recovery/other-pvh/out
```

## Acceptance on polygon
A polygon run is acceptable only if:
- preview resolves the intended broken refs;
- no unexpected duplicate growth appears;
- control objects still open correctly;
- before/after counts are recorded.

## Current tester path
For local file-base validation, use the direct COM runner with an explicit Windows path to `restore_map.csv`.

Recommended path:
```text
T:\1S\wsl_exchange\work_epf_112_9\context\recovery\other-pvh\out\restore_map.csv
```

Reason:
- the local tester path is already proven with explicit `C:\...` file resolution;
- this avoids UNC escaping issues in PowerShell command lines;
- it keeps the tester contour stable while server-base no-UI launch is still being isolated.

## Why built-in export is preferred
1. It already supports exact object export through `ДополнительныеОбъектыДляВыгрузки`.
2. It serializes references in the same exchange model as the rest of this EPF.
3. It reduces the chance of building a second inconsistent donor pipeline just for recovery.
4. It keeps donor export and target import inside one controlled recovery contour.

## Transfer to x17
Only after polygon evidence:
1. keep the same `restore_map.csv`;
2. run preview on `x17_pg2`;
3. run fix in portions;
4. record result in `docs/recovery-progress-118.md`.
