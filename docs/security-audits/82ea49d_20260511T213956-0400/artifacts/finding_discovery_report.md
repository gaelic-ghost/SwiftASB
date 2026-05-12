# Finding Discovery Report

## Scope

Repository-wide security discovery for SwiftASB at commit `82ea49d`, with artifacts stored under `docs/security-audits/82ea49d_20260511T213956-0400/`.

Subagents were used where the Codex Security workflow suggested them. One transport subagent was blocked by the platform security classifier; transport files were reviewed directly afterward. Other completed subagents reviewed protocol, startup/config, turn/approval, library/git/workspace, and MCP/hook/plugin surfaces.

## Promoted Candidates

### C1: Numeric JSON-RPC IDs are narrowed before identity binding

- Instance key: `jsonrpc-id-narrowing:Sources/SwiftASB/Protocol/CodexRPCEnvelope.swift:67`
- Affected location: `Sources/SwiftASB/Protocol/CodexRPCEnvelope.swift:67`
- Source: inbound JSON-RPC `id` value from the Codex app-server peer.
- Broken control: numeric IDs are checked only for whole-number shape, then converted with `NSNumber.intValue`.
- Sink: `CodexRPCRequestID.int(Int)` is used for response routing and server-request identity.
- Impact: large numeric peer-provided IDs can collapse, wrap, or collide before SwiftASB binds or routes a response/request.
- Closest control: boolean and fractional values are rejected; there is no range-preserving conversion or range check.
- CWE: CWE-190, CWE-681.
- Validation recommended: yes.

### C2: Unknown network-policy amendment actions fail open to `allow`

- Instance key: `fail-open-policy:Sources/SwiftASB/Public/CodexAppServer+ProtocolPayloads.swift:229`
- Affected location: `Sources/SwiftASB/Public/CodexAppServer+ProtocolPayloads.swift:226`
- Source: app-server wire `action` value on a network-policy amendment proposal.
- Broken control: `.init(rawValue: action) ?? .allow` maps unknown values to allow.
- Sink: public `CodexNetworkPolicyAmendment` shown to downstream apps and used when applying network-policy amendments.
- Impact: malformed or future-deny/unknown action values can be represented as an allow action in approval UI or app logic.
- Closest control: the public enum only has `allow` and `deny`; unknown values are not preserved or rejected.
- CWE: CWE-20, CWE-284.
- Validation recommended: yes.

## Suppressed Candidates

### S1: JSON-RPC error response missing expected-ID guard

Suppressed after transport validation. `decodeResponse` does not re-check `expectedID` in the error branch, but `CodexAppServerTransport` classifies each inbound message first and removes/resumes only the continuation matching the top-level envelope ID. Through the normal transport path, an error response for ID B is not delivered to the decoder for pending request A.

### S2: Compatibility enforcement after app-server launch

Suppressed as a reportable security finding. The resolver computes version and compatibility before app-server launch by running `codex --version`; the one-call startup API currently enforces the compatibility policy after launch, but the selected executable has already run during version probing regardless. This is a design hardening topic, not an exploitable bypass under the local-operator trust model.

### S3: Hook/plugin/skill local inventory exposure

Suppressed as a reportable finding under the current threat model. These APIs intentionally expose local app-server inventory to the linked local app. The fields include local paths, command strings, plugin source metadata, and diagnostics, so downstream apps should treat the values as sensitive local metadata, but SwiftASB does not currently claim to redact them.

### S4: MCP resource read as SwiftASB-side auth bypass

Deferred rather than promoted. SwiftASB forwards server/URI/thread ID to the app-server; resource authorization belongs to app-server. A lower-trust companion UI design would need separate app-server/resource-policy validation.

### S5: Git command injection through cwd

Suppressed. Git observability uses fixed argv arrays: `["git", "-C", cwd] + fixedArguments`. No shell interpolation was observed, and the helper applies output and timeout limits.

## Deferred Rows

- `LineDelimitedDataBuffer` and JSON materialization should receive a focused resource-limit review. No concrete untrusted peer path was proven in this scan.
- `ThreadHistoryStore` should receive a follow-up line-by-line review for local sensitive-history exposure and storage growth.
- Generated wire code should receive generated-code-oriented parser/codec review if upstream payloads become a higher-trust boundary.
