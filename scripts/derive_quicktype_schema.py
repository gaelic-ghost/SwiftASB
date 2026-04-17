#!/usr/bin/env python3
"""Derive a quicktype-friendly root schema from the bundled Codex protocol schema.

The bundled protocol schema stores nearly everything under `definitions`, which
quicktype does not expand when the top-level schema is just a plain container.
This script creates a synthetic top-level object with one property per selected
definition, while preserving the original shared definitions map so all local
`#/definitions/...` references still resolve.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--bundle",
        type=Path,
        required=True,
        help="Path to the bundled protocol JSON Schema file.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        required=True,
        help="Output path for the derived schema.",
    )
    parser.add_argument(
        "--title",
        default="CodexLifecycleBatch",
        help="Title for the synthetic top-level schema.",
    )
    parser.add_argument(
        "definitions",
        nargs="+",
        help="Definition names to expose as top-level properties.",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    bundle: dict[str, Any] = json.loads(args.bundle.read_text())
    definitions: dict[str, Any] = bundle.get("definitions", {})
    missing = [name for name in args.definitions if name not in definitions]
    if missing:
        parser.error(f"Bundle is missing definitions: {', '.join(missing)}")

    properties = {
        name[0].lower() + name[1:]: {"$ref": f"#/definitions/{name}"}
        for name in args.definitions
    }

    derived = {
        "$schema": bundle.get("$schema", "http://json-schema.org/draft-07/schema#"),
        "title": args.title,
        "description": (
            "Synthetic quicktype root generated from the bundled Codex app-server "
            "protocol schema. Each top-level property references one selected "
            "definition from the original bundle."
        ),
        "type": "object",
        "properties": properties,
        "additionalProperties": False,
        "definitions": definitions,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(derived, indent=2) + "\n")
    print(f"Wrote derived schema to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
