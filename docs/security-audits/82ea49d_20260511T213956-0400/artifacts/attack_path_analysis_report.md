# Attack Path Analysis

## F1: Numeric JSON-RPC ID narrowing

Attack path:

1. A peer sends a JSON-RPC response or server request with a numeric `id` outside the C `int` range but still representable by `NSNumber`.
2. `CodexRPCEnvelope.parseRequestID(_:)` checks that the number is whole, then converts it with `number.intValue`.
3. The narrowed value becomes `CodexRPCRequestID.int`.
4. SwiftASB uses that parsed ID to classify a response or bind an interactive server request.
5. If two peer-provided numeric IDs collide after narrowing, SwiftASB can route or answer the wrong logical request.

Preconditions:

- The app-server peer must emit numeric IDs large enough to narrow or collide.
- The affected flow must involve peer-provided IDs; SwiftASB's own outgoing request IDs are UUID strings.

Impact:

- Request/response correlation confusion.
- Wrong interactive request identity binding in malformed or future protocol conditions.

Severity:

- Medium. The local app-server trust model limits exploitability, but this is a protocol boundary bug in a library whose job is to safely wrap a moving wire protocol.

## F2: Unknown network-policy amendment actions fail open

Attack path:

1. Codex app-server sends a command-execution approval request with a proposed network-policy amendment.
2. The wire action is malformed, future-versioned, or otherwise not one of the current public cases.
3. SwiftASB maps the unknown value to `.allow`.
4. A downstream app displays or applies the public value as though Codex requested an allow rule.

Preconditions:

- App-server emits an unknown network action value.
- Downstream app trusts SwiftASB's public value for approval presentation or response construction.

Impact:

- Permission intent is represented fail-open.
- A user or app can approve a broader network permission than the app-server actually encoded.

Severity:

- Medium. This directly touches permission vocabulary and should fail closed or preserve unknown values.

## Non-Reportable Paths

- Error-response expected-ID mismatch is blocked by transport routing in the normal path.
- Compatibility-after-launch is not a security barrier against malicious executable selection because version probing already executes the selected binary.
- Hook/plugin inventory exposure is local trusted-app metadata exposure under the current package model.
- MCP resource reads require app-server authorization validation; no SwiftASB-side bypass was proven.
