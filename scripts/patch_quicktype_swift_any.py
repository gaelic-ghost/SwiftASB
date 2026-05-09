#!/usr/bin/env python3
"""Patch quicktype Swift output to replace dynamic JSON helper holes with JSONValue.

This keeps quicktype as the source of truth for the generated wire graph while
giving obviously dynamic JSON surfaces a typed placeholder that can still
conform to `Equatable` and `Sendable`.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


JSON_VALUE_DECLARATION = """
indirect enum CodexWireJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int)
    case double(Double)
    case string(String)
    case array([CodexWireJSONValue])
    case object([String: CodexWireJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let integer = try? container.decode(Int.self) {
            self = .integer(integer)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([CodexWireJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: CodexWireJSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value while decoding CodexWireJSONValue."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .integer(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}
""".strip()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True, help="Path to the generated Swift file.")
    parser.add_argument("--output", type=Path, required=True, help="Where to write the patched Swift file.")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    source = args.input.read_text()

    if "import Foundation\n" not in source:
        raise SystemExit("Expected generated Swift file to contain `import Foundation`.")

    if "class JSONAny: Codable" in source:
        patched = patch_codable_output(source)
    else:
        patched = patch_just_types_output(source)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(patched)
    print(f"Wrote patched Swift file to {args.output}")
    return 0


def patch_just_types_output(source: str) -> str:
    patched = source.replace(
        "import Foundation\n",
        f"import Foundation\n\n{JSON_VALUE_DECLARATION}\n\n",
        1,
    )

    replacements = [
        ("[String: Any?]?", "[String: CodexWireJSONValue]?"),
        ("[Any?]", "[CodexWireJSONValue]"),
        ("Any?", "CodexWireJSONValue?"),
    ]
    for old, new in replacements:
        patched = patched.replace(old, new)

    return patched


def patch_codable_output(source: str) -> str:
    helper_pattern = re.compile(
        r"\n// MARK: - Encode/decode helpers\n[\s\S]*$",
        re.MULTILINE,
    )
    if not helper_pattern.search(source):
        raise SystemExit("Expected Codable quicktype output to contain the JSON helper block.")

    patched = helper_pattern.sub(f"\n{JSON_VALUE_DECLARATION}\n", source)
    patched = patched.replace("JSONAny", "CodexWireJSONValue")
    patched = patched.replace("JSONNull", "CodexWireJSONValue")
    patched = patch_cross_version_compatibility(patched)
    return patched


def patch_cross_version_compatibility(source: str) -> str:
    """Keep the promoted v0.130 graph tolerant of older guardrail payloads."""
    replacements = [
        ("    let completedAtMS: Int\n", "    let completedAtMS: Int?\n"),
        ("    let startedAtMS: Int\n", "    let startedAtMS: Int?\n"),
        ("    let sessionID: String\n", "    let sessionID: String?\n"),
    ]

    patched = source
    for old, new in replacements:
        patched = patched.replace(old, new)
    return patched


if __name__ == "__main__":
    raise SystemExit(main())
