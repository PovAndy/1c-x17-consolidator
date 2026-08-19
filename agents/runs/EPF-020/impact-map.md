# Impact Map

## UI
- Main form gets a new diagnostic button for account/service link analysis

## Object module
- Added runtime metadata inspection helpers
- Added read-only diagnostics for:
  - `Документ.икОткрытиеЛицевогоСчета`
  - `РегистрСведений.икУслугиЛицевыхСчетов`
  - `РегистрСведений.икОпределениеПредоставляемыхУслугЛицевыхСчетов`

## Risks
- Runtime metadata names may differ from pattern assumptions
- Requires 1C compile and in-app smoke for confirmation
