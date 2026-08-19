# Tester Packet

## Validate
- Form command is wired correctly
- Report is read-only and writes only to a temp markdown file
- New BSL uses runtime metadata, not hardcoded field certainty
- No new code path mutates infobase data

## Mandatory Runtime Checks
- Compile the EPF in 1C
- Open the form and run `Диагностика ЛС/услуг`
- Confirm markdown report opens without exception
- Review whether detected field names match real metadata in target base

## Acceptance Status Rule
- Until compile + in-app run are confirmed, verdict may only be `accepted_with_ops_check`
