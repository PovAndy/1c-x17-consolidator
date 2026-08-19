# Room Structure Anomalies on x17_pg2 — 2026-04-14

## Context

After freezing the stabilized new-meter layer and confirming that:

1. targeted `unsafe-live` PVH pass is operational but returns zero actionable rows on current `x17_pg2`;
2. exact duplicate checks for characteristic registers are clean after `v25-120.2`;

…the next highest-value stabilization layer is the visible room/object characteristic structure.

## Probe

A new SQL read-only probe was added:

- `scripts/inventory-room-structure-anomalies-sql.py`

Artifacts from the first run:

- `logs/duplicates/room_structure_anomalies_20260414_175908.md`
- `logs/duplicates/room_structure_anomalies_suspicious_20260414_175908.csv`
- `logs/duplicates/room_structure_anomalies_core_20260414_175908.csv`

## Main Findings

### 1. Foreign room-structure code cluster `000000267..000000272` is live

The probe confirmed:

1. `27` rows in `ПВХ.икХарактеристикиОбъектовУчета` for codes `267..272`;
2. all rows are folders (`ЭтоГруппа = Да`);
3. total active register hits in `_inforg36811._fld36813rref` = `358`.

Live-hit totals by code:

1. `000000267` -> `103`
2. `000000268` -> `133`
3. `000000269` -> `77`
4. `000000270` -> `28`
5. `000000271` -> `16`
6. `000000272` -> `1`

These are not dead tails. This is a live visible layer contaminating room/object characteristics in the merged base.

### 2. Core residential duplicates remain live

For the canonical room metrics:

1. `Жилая площадь`
   - `000000009` -> `54` live hits
   - `000000019` -> `1` live hit

2. `Общая площадь`
   - `000000008` -> `57` live hits
   - `000000013` -> `0` live hits

Total active hits in the core duplicate layer = `112`.

### 3. Practical meaning

The next corrective layer on `x17_pg2` is not:

1. meter recovery;
2. exact duplicate cleanup in characteristic registers;
3. already-proven `unsafe-live` PVH merge.

It is:

1. visible room/object characteristic structure in `икХарактеристикиОбъектовУчета`;
2. live foreign folder-like groups `267..272`;
3. live duplicate residential metrics `Жилая площадь` / `Общая площадь`.

## Implication for the plan

Next professional step should be a dedicated corrective design for room-structure visible PVH, not another generic PVH merge.

Preferred order:

1. classify foreign folder groups `267..272` against district baseline `x1_14`;
2. determine whether they must be hidden, re-parented, separated by district, or excluded from visible residential structure;
3. prepare a safe x17-only corrective pass;
4. re-check room structure cards like `14-187` after the pass.
