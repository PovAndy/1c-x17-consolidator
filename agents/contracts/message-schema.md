# Message Schema (Lean+Reliable)

```json
{
  "task_id": "EPF-###",
  "from_role": "lead|analyst|engineer|qa|packager",
  "to_role": "lead|analyst|engineer|qa|packager",
  "status": "ready|blocked|failed|done|rework",
  "summary": "<=240 chars, delta only",
  "packet_path": "agents/runs/EPF-###/coder-packet.md",
  "artifacts": ["path"],
  "risks": ["max 3"],
  "next_action": "single step",
  "confidence": "high|medium|low",
  "research_gate": "on|off",
  "sources": [
    {
      "url": "https://...",
      "type": "primary|secondary",
      "relevance": "<=120 chars",
      "checked_at": "YYYY-MM-DD"
    }
  ]
}
```
