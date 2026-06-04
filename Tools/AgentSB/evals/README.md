# AgentSB Evals

AgentSB evals exercise the real tool path around deterministic inspection,
report rendering, and safety classification.

Run local evals without an OpenAI API key:

```bash
uv run agentsb eval local
```

Results are written to `evals/results/latest.json`, which is ignored by git.

AI-assisted evals are planned for coordinator behavior and require
`OPENAI_API_KEY`. They should verify that the coordinator keeps ownership of the
final answer, refuses unsupported public API promotion, and routes specialist
work through the intended boundaries.
