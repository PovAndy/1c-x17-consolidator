# Impact Map EPF-001

## Target Area
- `ObjectModule.bsl` import/export core pipeline and dedup routines.

## Upstream Callers
- UI form actions in this external processor.
- Export entry: `ВыполнитьВыгрузку`.
- Import entry: adaptive load procedures around line parsing + packet writing.

## Downstream Effects
- XML content shape and compatibility.
- Object write semantics in target DB.
- Link integrity after dedup replacement.

## Data and State Touchpoints
- `TotalObjects` attribute in XML root.
- `мПлоскоеСоответствиеЗамен` map.
- Flags like `НеПерезаписыватьСуществующиеЭлементы`.

## Expected Non-Impacted Areas
- Static metadata declarations.
- Help and template resources not tied to import core.
