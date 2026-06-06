from __future__ import annotations

from pathlib import Path


def run_local_evals() -> int:
    from evals.run_local import run

    root = Path(__file__).resolve().parents[1]
    return run(root / "evals" / "cases.jsonl", root / "evals" / "results" / "latest.json")


def run_ai_evals(*, model: str | None = None) -> int:
    from evals.run_ai import run

    root = Path(__file__).resolve().parents[1]
    return run(root / "evals" / "ai_cases.jsonl", root / "evals" / "results" / "ai-latest.json", model=model)
