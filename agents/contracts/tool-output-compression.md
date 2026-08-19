# Tool Output Compression Policy

## Goal
Reduce token waste while preserving actionable signal.

## Rules
- Never pass raw logs > 200 lines into decision context.
- Extract only: error signatures, file paths, line numbers, exit codes, affected commands.
- Keep a short summary (<= 12 lines) + reference to full log path.
- For repetitive errors, keep one representative sample and count frequency.

## Required summary fields
- command
- status
- key_errors[]
- affected_files[]
- next_action
