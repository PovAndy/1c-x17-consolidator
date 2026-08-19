# EPF-014

## Goal
Fix organizations quick-check in database structure analysis and prevent false `PASS/OK` when organizations analysis fails.

## Scope
- repair query syntax in organizations quick analysis;
- add explicit analysis-error flag;
- block `PASS` verdict if organizations analysis is not completed successfully;
- bump processing version.
