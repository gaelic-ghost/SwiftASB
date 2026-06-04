from __future__ import annotations

from pathlib import Path


def run_local_evals() -> int:
    from evals.run_local import run

    root = Path(__file__).resolve().parents[1]
    return run(root / "evals" / "cases.jsonl", root / "evals" / "results" / "latest.json")
