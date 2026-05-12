# Validation Report

## V1: Numeric JSON-RPC ID narrowing

Disposition: reportable hardening finding.

Evidence:

- `CodexRPCRequestID` stores numeric IDs as Swift `Int`.
- `CodexRPCRequestID.init(from:)` decodes `Int` directly when the decoder is used.
- `CodexRPCEnvelope.parseRequestID(_:)` uses `JSONSerialization`, receives numeric IDs as `NSNumber`, rejects booleans and fractional values, then uses `number.intValue`.
- On macOS, `NSNumber.intValue` is a C `int` conversion, which is narrower than Swift `Int` on the supported platform.

Validation result:

The lossy conversion exists at the boundary where inbound JSON-RPC envelope IDs are classified for both responses and server requests. The practical severity is limited because SwiftASB-generated client request IDs are UUID strings and the local Codex app-server is the expected peer. The finding remains valid as protocol hardening because server-request IDs are peer-provided and approval/elicitation response identity is bound from this parsed value.

Severity: Medium.

## V2: Unknown network-policy amendment actions fail open

Disposition: reportable finding.

Evidence:

- `CodexProtocolNetworkPolicyAmendment.publicValue` maps `action` with `.init(rawValue: action) ?? .allow`.
- Public `CodexNetworkPolicyAmendment.Action` supports `.allow` and `.deny`.
- Approval UI or downstream logic may use the public action value when deciding whether to apply a proposed network policy amendment.

Validation result:

This is a direct fail-open representation bug. Unknown app-server action values should not become `allow`. A safer shape would preserve `unknown(String)` or fail closed.

Severity: Medium.

## V3: JSON-RPC error responses do not enforce expected ID

Disposition: suppressed.

Evidence:

- `CodexAppServerProtocol.decodeResponse` checks success response IDs after successful decode.
- The JSON-RPC error branch throws `rpcError` without checking `rpcError.id` against `expectedID`.
- `CodexAppServerTransport.handleStandardOutputLine` classifies the top-level envelope first, removes `pendingResponses[id]`, and only resumes the continuation associated with that same envelope ID.

Validation result:

The missing guard is locally inconsistent and worth test coverage, but the normal transport path already routes by the same top-level ID before decode. No cross-continuation failure or approval confusion was proven.

Severity: Not reportable in this scan.

## V4: Compatibility validation after app-server launch

Disposition: suppressed as security finding; keep as design hardening.

Evidence:

- `CodexCLIExecutableResolver.resolve()` probes `--version`, computes compatibility, and returns a `Resolution`.
- `CodexAppServerTransport.start()` stores the resolution, then launches `codex app-server --listen stdio://`.
- `CodexAppServer.start(_:)` calls `startTransport()` before `cliExecutableDiagnostics()` and `validateStartupCompatibility(...)`.

Validation result:

The selected executable is already executed during `--version` probing before any policy rejection can happen. Under the local operator trust model, delaying app-server initialization is not a meaningful security barrier against a malicious executable path. This remains a useful product-hardening note: one-call startup could enforce stored compatibility before app-server launch for clearer behavior.

Severity: Not reportable in this scan.

## V5: Hook/plugin/MCP inventory exposure

Disposition: suppressed/deferred depending on downstream app trust model.

Validation result:

Hook and plugin APIs expose local metadata by design. MCP resource reads delegate authorization to the app-server. No SwiftASB-side redaction promise or lower-trust export sink was found in this scan. If SwiftASB later supports a remote or lower-trust companion, these surfaces should be revisited as explicit data-classification boundaries.
