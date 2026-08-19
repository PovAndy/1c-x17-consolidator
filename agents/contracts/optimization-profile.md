# Optimization Profile (2026, Lean+Reliable)

## Selected Techniques
- Plan-and-Solve: mandatory short plan before execution.
- ReAct-lite: think -> act -> observe loop with tool evidence.
- CoVe-lite: final self-check against acceptance criteria.
- Prompt Compression / SPR: compact artifacts and delta-only handoffs.
- Decomposed Prompting: separate analysis, implementation, verification roles.
- Evidence-first RAG-lite: external research only when triggered.

## Operational Enhancements
- Context Bootstrap Gate: auto-generated project/file outlines before deep reads.
- Tool Output Compression: summarize raw logs/tool output into compact signal.
- Typed Memory Policy: semantic/episodic/procedural/working with confidence/date/source.

## Reliability Defaults
- Primary sources first.
- Relevance note per source.
- Facts vs assumptions separation.
- Prevention Gate before compile.

## Rejected by Default (Token Cost vs Benefit)
- Multi-persona debate for routine tasks.
- Mega-prompts with repeated context.
- Mandatory heavy artifacts for low-risk tasks.

## Quality Guards
- measurable acceptance criteria
- evidence paths required for pass
- confidence field in each handoff packet
