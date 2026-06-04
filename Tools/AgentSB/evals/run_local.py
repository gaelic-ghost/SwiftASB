from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from agentsb.reports import REPORT_SECTIONS, render_schema_review_report
from agentsb.safety import classify_candidate


@dataclass
class EvalResult:
    case_id: str
    passed: bool
    details: list[str]

    def as_dict(self) -> dict[str, Any]:
        return {
            "case_id": self.case_id,
            "passed": self.passed,
            "details": self.details,
        }


def run(cases_path: Path | None = None, results_path: Path | None = None) -> int:
    cases_path = cases_path or ROOT / "evals" / "cases.jsonl"
    results_path = results_path or ROOT / "evals" / "results" / "latest.json"
    cases = _load_cases(cases_path)
    results = [_run_case(case) for case in cases]
    payload = {
        "passed": sum(1 for result in results if result.passed),
        "failed": sum(1 for result in results if not result.passed),
        "results": [result.as_dict() for result in results],
    }
    results_path.parent.mkdir(parents=True, exist_ok=True)
    results_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    for result in results:
        status = "PASS" if result.passed else "FAIL"
        print(f"{status} {result.case_id}")
        for detail in result.details:
            print(f"  {detail}")
    return 0 if payload["failed"] == 0 else 1


def _run_case(case: dict[str, Any]) -> EvalResult:
    kind = case["kind"]
    if kind == "report":
        return _run_report_case(case)
    if kind == "safety":
        return _run_safety_case(case)
    return EvalResult(case.get("id", "(unknown)"), False, [f"unknown case kind: {kind}"])


def _run_report_case(case: dict[str, Any]) -> EvalResult:
    rendered = render_schema_review_report(case["input"]["facts"])
    details: list[str] = []
    for section in case["expect"].get("required_sections", REPORT_SECTIONS):
        if f"## {section}" not in rendered:
            details.append(f"missing section: {section}")
    for text in case["expect"].get("required_text", []):
        if text not in rendered:
            details.append(f"missing text: {text}")
    return EvalResult(case["id"], not details, details)


def _run_safety_case(case: dict[str, Any]) -> EvalResult:
    classification = classify_candidate(case["input"]["candidate"])
    expected = case["expect"]
    details: list[str] = []
    if classification.decision != expected["decision"]:
        details.append(f"expected {expected['decision']}, got {classification.decision}")
    required_reason = expected.get("required_reason")
    reason_text = " ".join(classification.reasons)
    if required_reason and required_reason not in reason_text:
        details.append(f"missing reason text: {required_reason}")
    return EvalResult(case["id"], not details, details)


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
