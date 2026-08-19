# QA Checklist (Lean+Reliable)

- Compile/decompile pass or failure captured.
- Smoke scenario executed.
- Known failure modes checked.
- Logs paths attached.
- Verdict: pass or rework.
- For `ObjectModule.bsl`, form module, BSL query text or string-literal changes:
  - classify validation as `static_only` or `runtime_checked`;
  - no final `pass` without runtime 1C verification evidence.
- If runtime check is pending, verdict must be `rework` or `accepted_with_ops_check`, never plain `pass`.
