# Knowledge Base EPF-008 (Research Gate)

## Hypotheses to Validate
- Structural context maps improve large-codebase navigation and reduce context waste.
- Compression of tool output decreases token usage without losing debugging signal.
- Typed memory improves consistency and reduces repeated mistakes.

## Sources
- URL: https://sourcegraph.com/blog/towards-infinite-context-for-code
  type: primary
  relevance: context filtering and retrieval for large codebases
  checked_at: 2026-03-12

- URL: https://www.honeycomb.io/blog/monitoring-agent-context-window-summarization-honeycomb-mcp
  type: primary
  relevance: summarization of large tool outputs and context reduction
  checked_at: 2026-03-12

- URL: https://blog.langchain.com/memory-for-agents
  type: primary
  relevance: typed memory patterns for agent systems
  checked_at: 2026-03-12

- URL: https://habr.com/ru/news/1005026/
  type: secondary
  relevance: user-provided article context about compressed MCP outputs
  checked_at: 2026-03-12

- URL: https://habr.com/ru/articles/1005800/
  type: secondary
  relevance: user-provided article context about structural context strategy
  checked_at: 2026-03-12

- URL: https://habr.com/ru/articles/1006756/
  type: secondary
  relevance: user-provided article context about memory MCP strategy
  checked_at: 2026-03-12

- URL: https://habr.com/ru/articles/1006602/
  type: secondary
  relevance: subagent architecture pillars: context isolation, specialization, parallelism
  checked_at: 2026-03-12

- URL: https://habr.com/ru/articles/1002200/
  type: secondary
  relevance: anti-vibe process discipline, security/reliability checklisting
  checked_at: 2026-03-12

- URL: https://habr.com/ru/articles/1000140/
  type: secondary
  relevance: warning against delivery-only approach without understanding/verification
  checked_at: 2026-03-12

- URL: https://habr.com/ru/companies/X5Tech/articles/995466/
  type: secondary
  relevance: Spec-Driven development chain: idea->spec->plan->decompose->code->checks
  checked_at: 2026-03-12

- URL: https://github.com/mraza007/echovault
  type: primary
  relevance: local-first typed memory with markdown + FTS index and compact pointers
  checked_at: 2026-03-12

- URL: https://github.com/can1357/oh-my-pi/tree/main/packages/react-edit-benchmark
  type: primary
  relevance: benchmark harness concept for edit quality/agent performance evaluation
  checked_at: 2026-03-12

## Confirmed Facts
- Compact, structured context maps reduce high-token blind file reads.
- Summarized tool output preserves actionable debugging signal.
- Typed memory with confidence/date/source improves decision consistency.
- Subagent orchestration quality depends on context isolation + specialization + parallelism.
- Spec-driven pipeline is a practical guardrail against unstable vibe-coding loops.

## Assumptions
- Team will consistently run bootstrap before deep analysis tasks.

## Impact on Solution
- Added bootstrap script and policy gates to institutionalize these practices.
- Kept optional path for adopting local memory engine (EchoVault-like) and benchmark harness.
