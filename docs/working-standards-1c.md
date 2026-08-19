# Working Standards: 1C / BSL / Integration

## Local Mandatory Source
- Local document:
  - `{WORKSPACE_ROOT}/docs/Методология разработки внешних компонент.md`
- Status:
  - accepted as a mandatory local methodology source for integration-related decisions

## Scope Clarification
- The local methodology is primarily about external components (`Native API`, `COM`).
- For the current EPF/XML project, only the relevant parts are mandatory:
  - Unicode / string handling
  - memory ownership discipline
  - exception handling and error propagation
  - server-safe behavior
  - avoiding UI dependencies in server logic

## Mandatory Rules For This Project
1. BSL/server code
- No UI calls from server-side logic.
- Exceptions must be caught at boundaries where failure would otherwise produce opaque behavior.
- Query text must be assembled carefully; no assumptions about optional metadata fields.
- Read-only diagnostics must remain read-only.

2. XML/integration
- XML exchange files are treated as `UTF-8`.
- File patching must preserve byte stability assumptions.
- For large XML, avoid full in-memory DOM load for the whole file.

3. Strings/encoding
- 1C runtime strings are Unicode.
- External component interoperability must respect `WCHAR_T`/Unicode behavior from the local methodology.
- Script/tooling files outside 1C runtime should avoid Cyrillic in fragile shell contexts.

4. Error discipline
- Prefer exact failure localization over generic catches.
- New diagnostics must degrade gracefully on metadata differences between configurations.
- Before changing query logic, check whether the metadata object is hierarchical or has optional fields.

## Official Reference Sources
- `https://v8.1c.ru/platforma/vstroennyy-yazyk/`
  - official overview of the built-in language
- `https://1c-dn.com/1c_enterprise/1c_programming_language/`
  - official overview of 1C programming language usage
- `https://1c-dn.com/library/1c_enterprise_script/`
  - official guide to 1C:Enterprise script concepts
- `https://1c-dn.com/library/`
  - official 1C knowledge base / developer documentation hub
- `https://1c-dn.com/library/tutorials/practical_developer_guide_for_1c_enterprise_8_3/`
  - practical 8.3 guide

## Confirmed Working Principles
- 1C built-in language is event/context-driven, not a general-purpose standalone codebase model.
- Metadata structure drives available runtime fields and object behavior.
- Query compatibility must be checked against actual metadata capabilities.
- Unicode handling is fundamental both in platform script and in external integrations.

## Practical Consequence For Current Work
- All next refactorings and diagnostics in `epf1129` must:
  - inspect metadata capabilities before building queries
  - keep server logic UI-free
  - preserve encoding discipline
  - prefer minimal, configuration-aware changes over abstract "universal" rewrites
