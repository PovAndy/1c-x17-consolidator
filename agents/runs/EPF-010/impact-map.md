# Impact Map EPF-010

## Changed Entry Points
- `Адапт_ПолучитьОбъектБД`
- new helper functions for PVH semantic matching and GUID remap

## Expected Behavior Delta
- For `ПланыВидовХарактеристик`, incoming elements with foreign GUID are matched to existing base elements by safe key before creating a new object.
- When a unique match is found, old GUID is remapped to existing base GUID in the in-memory replacement map.

## Expected Non-Impacted Areas
- Documents, catalogs, registers, constants.
- Existing predefined-data remap flow.

## Risks and Mitigations
- Risk: false positive match for PVH elements with identical business key.
- Mitigation: match is strict and only accepted when exactly one candidate is found.
