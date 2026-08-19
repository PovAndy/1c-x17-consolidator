# Impact Map

## Installed additions
- `inspect`
- `validate`
- `web-info`

## Expected benefits
- Smaller context during inspection of large 1C XML objects
- Broader explicit validation before runtime compile/smoke
- Faster diagnosis of web publication issues before browser tests

## Affected files
- [AGENT_OPERATIONS.md]({PROJECT_ROOT}/AGENT_OPERATIONS.md)
- [PROFESSIONAL_SETUP.md]({PROJECT_ROOT}/PROFESSIONAL_SETUP.md)
- [skills-profile.md]({PROJECT_ROOT}/docs/skills-profile.md)

## Rejected candidates
- `1c-test-runner` — requires `1c-ai-debug` MCP
- `subagent-dev` — depends on a different Task/subagent stack
- `write-plan` — depends on MCP/tooling not present in this Codex workflow
