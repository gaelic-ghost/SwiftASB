# AgentSB Evals

AgentSB evals exercise the real tool path around deterministic inspection,
report rendering, and safety classification.

Run local evals without an OpenAI API key:

```bash
uv run agentsb eval local
```

Results are written to `evals/results/latest.json`, which is ignored by git.

Run AI-assisted evals only when an OpenAI API key is available:

```bash
OPENAI_API_KEY=... uv run agentsb eval ai
```

AI-assisted evals verify that the coordinator keeps generated-wire changes in
the report-only lane and refuses unsupported public API promotion.
