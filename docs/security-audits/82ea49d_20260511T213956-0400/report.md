# SwiftASB Repository-Wide Security Audit

Scan ID: `82ea49d_20260511T213956-0400`  
Commit: `82ea49d`  
Date: 2026-05-11  
Tooling workflow: Codex Security repository-wide scan phases: threat model, finding discovery, validation, attack-path analysis, final report.

## Summary

The audit found two medium-severity protocol/policy hardening findings and no critical or high-severity findings in the reviewed surfaces.

One subagent was blocked by the platform security classifier, so transport files were reviewed directly. Several large or lower-priority areas remain explicitly deferred in the coverage ledger rather than marked complete.

## Findings

### F1: Numeric JSON-RPC IDs are narrowed before identity binding

Severity: Medium  
Status: Reportable  
CWE: CWE-190, CWE-681

Affected location:

- `Sources/SwiftASB/Protocol/CodexRPCEnvelope.swift:67`

SwiftASB classifies inbound JSON-RPC envelope IDs by parsing Foundation JSON, checking numeric values for whole-number shape, then converting `NSNumber` with `intValue`. On the supported macOS platform this is narrower than Swift `Int`, so large numeric peer-provided IDs can wrap or collide before becoming `CodexRPCRequestID.int`.

This matters because SwiftASB uses parsed request IDs to route responses and bind app-server interactive requests. SwiftASB's own outgoing request IDs are UUID strings, which limits normal exploitability, but peer-provided server-request IDs still cross this boundary.

Recommended fix:

- Convert numeric IDs with a range-preserving path, such as decoding through `Int64` or `Int` with explicit exactness checks.
- Reject out-of-range numeric IDs with `invalidJSONRPCEnvelope`.
- Add boundary tests around 32-bit and 64-bit limits.

### F2: Unknown network-policy amendment actions fail open to `allow`

Severity: Medium  
Status: Reportable  
CWE: CWE-20, CWE-284

Affected location:

- `Sources/SwiftASB/Public/CodexAppServer+ProtocolPayloads.swift:229`

`CodexProtocolNetworkPolicyAmendment.publicValue` maps unknown wire action strings with `.init(rawValue: action) ?? .allow`. If the app-server sends a malformed or future action value, SwiftASB represents it to downstream apps as an allow action.

This is a fail-open permission representation bug. Network-policy amendment values should preserve unknown data or fail closed so approval UI and app logic do not accidentally widen permissions.

Recommended fix:

- Change the public enum to include `unknown(String)` or throw during conversion.
- Prefer fail-closed behavior for approval and permission surfaces.
- Add tests proving unknown action values are not represented as allow.

## Suppressed Or Deferred Items

- JSON-RPC error-response expected-ID mismatch was suppressed because transport routing resumes continuations by the same top-level envelope ID before protocol decode.
- Compatibility enforcement after app-server launch was suppressed as a security finding. The selected executable already runs during `--version` probing, so this is product hardening rather than a meaningful malicious-executable barrier.
- Hook/plugin/skill metadata exposure was suppressed under the current local trusted-app threat model. Downstream apps should still treat this as sensitive local inventory.
- MCP resource reads were deferred to app-server authorization validation; no SwiftASB-side bypass was proven.
- Stdio line/message size limits and JSON materialization were deferred as resource-hardening work.
- `ThreadHistoryStore`, generated wire code, and some observable companion files remain deferred for full line-by-line audit coverage.

## Evidence

Primary artifacts:

- `artifacts/threat_model.md`
- `artifacts/runtime_inventory.md`
- `artifacts/exhaustive-file-checklist.md`
- `artifacts/repository_coverage_ledger.md`
- `artifacts/finding_discovery_report.md`
- `artifacts/validation_report.md`
- `artifacts/attack_path_analysis_report.md`

Subagent-assisted reviewed areas:

- Protocol decode and JSON-RPC envelope files.
- Startup, compatibility, config, and error files.
- Turn lifecycle, approval, elicitation, and turn handle files.
- Library, loaded thread, thread management, Git observability, and workspace files.
- MCP, hooks, models, extensions, and protocol-payload files.

Directly reviewed areas:

- Transport launch and line-buffer files.
- Filesystem access surface.
- Key app-server methods around thread, filesystem, config, MCP, extensions, and turn start.
- Schema dump/generation and release-maintenance scripts.

Validation commands:

- No build or test suite was run because this task was an audit/report artifact pass with no code behavior changes.
- `git diff --check` should be run before commit if this docs artifact is committed.

## Residual Risk

This scan did not claim exhaustive closure for every source file. The coverage ledger preserves deferred areas explicitly. The strongest next pass would be a focused fix branch for F1 and F2, followed by targeted Swift tests, then a second audit slice for `ThreadHistoryStore`, generated wire parsing, and resource limits.
