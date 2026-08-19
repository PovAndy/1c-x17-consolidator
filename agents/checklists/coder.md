# Engineer Checklist (Lean+Reliable)

- Minimal diff only.
- No unrelated file changes.
- Behavior delta documented.
- Prevention Gate completed before compile.
- Build commands and outputs recorded.
- Large command outputs compressed per policy.
- For BSL strings and query text, do not use C-style escaping. Use doubled quotes or query parameters.
- After changing BSL query/string code, reread the exact modified lines before handing off.
