from __future__ import annotations

import asyncio
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from agents import Runner

from agentsb.coordinator import build_coordinator, default_openai_model


@dataclass
class AIEvalResult:
    case_id: str
    passed: bool
    model: str
    output: str
    details: list[str]

    def as_dict(self) -> dict[str, Any]:
        return {
            "case_id": self.case_id,
            "passed": self.passed,
            "model": self.model,
            "output": self.output,
            "details": self.details,
        }


def run(cases_path: Path | None = None, results_path: Path | None = None, *, model: str | None = None) -> int:
    if not os.environ.get("OPENAI_API_KEY"):
        raise RuntimeError("OPENAI_API_KEY is required for `agentsb eval ai`.")

    resolved_model = model or default_openai_model()
    cases_path = cases_path or ROOT / "evals" / "ai_cases.jsonl"
    results_path = results_path or ROOT / "evals" / "results" / "ai-latest.json"
    cases = _load_cases(cases_path)
    results = asyncio.run(_run_cases(cases, model=resolved_model))
    payload = {
        "model": resolved_model,
        "passed": sum(1 for result in results if result.passed),
        "failed": sum(1 for result in results if not result.passed),
        "results": [result.as_dict() for result in results],
    }
    results_path.parent.mkdir(parents=True, exist_ok=True)
    results_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for result in results:
        status = "PASS" if result.passed else "FAIL"
        print(f"{status} {result.case_id} ({result.model})")
        if result.output:
            print(f"  output: {result.output}")
        for detail in result.details:
            print(f"  {detail}")
    return 0 if payload["failed"] == 0 else 1


async def _run_cases(cases: list[dict[str, Any]], *, model: str) -> list[AIEvalResult]:
    coordinator = build_coordinator(model)
    results: list[AIEvalResult] = []
    for case in cases:
        result = await Runner.run(coordinator, case["prompt"])
        output = str(result.final_output).strip()
        results.append(_grade_case(case, output, model=model))
    return results


def _grade_case(case: dict[str, Any], output: str, *, model: str) -> AIEvalResult:
    required_text = case["expect"]["required_text"]
    normalized_output = output.lower()
    normalized_required = required_text.lower()
    details: list[str] = []
    if normalized_required not in normalized_output:
        details.append(f"missing required text: {required_text}")
    return AIEvalResult(case["id"], not details, model, output, details)


def _load_cases(path: Path) -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as file:
        for line_number, line in enumerate(file, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                cases.append(json.loads(stripped))
            except json.JSONDecodeError as error:
                raise ValueError(f"Invalid JSONL at {path}:{line_number}: {error}") from error
    return cases


if __name__ == "__main__":
    raise SystemExit(run())
