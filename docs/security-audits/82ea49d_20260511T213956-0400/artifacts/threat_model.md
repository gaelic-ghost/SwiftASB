# SwiftASB Security Threat Model

## Overview

SwiftASB is a Swift Package Manager library that wraps a locally launched Codex app-server subprocess for Swift, SwiftUI, and macOS clients. Its main runtime value is a typed Swift API over the Codex JSON-RPC app-server protocol, observable thread and turn companions, app-server-owned filesystem/config/MCP/plugin/hook surfaces, and local history reconciliation.

The package does not expose a network service of its own. The most important security boundary is therefore local and process-oriented: a downstream app links SwiftASB, SwiftASB launches or talks to a local Codex CLI app-server over stdio, and Codex owns the effective sandbox, approval, filesystem, command execution, plugin, hook, and MCP policies.

Primary runtime code lives under `Sources/SwiftASB/`. Generated Codex wire models under `Sources/SwiftASB/Generated/CodexWire/Latest/` are internal scaffolding and should not be treated as the final public API. Maintainer scripts under `scripts/` are privileged developer tooling for schema refreshes, validation, live probes, and releases.

## Threat Model, Trust Boundaries, and Assumptions

Trusted or high-trust actors:

- The local user/operator who installs Codex, links SwiftASB into an app, chooses the Codex executable, and grants filesystem or network permissions.
- The local Codex app-server subprocess selected by SwiftASB's executable resolver.
- Maintainers running schema generation, validation, and release scripts from the repository checkout.

Potentially attacker-controlled or lower-trust inputs:

- App-server JSON-RPC envelopes and event payloads, especially because SwiftASB tracks a moving Codex CLI/app-server surface.
- Prompt text, local-image paths, mentions, skill/plugin names, cwd values, thread IDs, turn IDs, MCP server names, MCP resource URIs, hook/plugin inventory strings, and filesystem paths passed by downstream apps.
- Environment and PATH values used during executable discovery when a downstream app does not pin an explicit Codex executable.
- Repository contents, hook config, plugin metadata, generated schema dumps, and local git metadata when a user opens an untrusted project.

Important assumptions:

- SwiftASB itself should preserve straight data flow and avoid silently widening Codex permissions.
- Codex app-server remains responsible for sandbox enforcement, permission prompts, command execution policy, filesystem authorization, MCP resource authorization, and plugin/hook loading.
- Downstream SwiftASB clients may display sensitive local metadata. SwiftASB should preserve enough source/type information for clients to make safe UI decisions, but it is not a redaction layer unless explicitly documented as one.
- Maintainer scripts are run by trusted maintainers in a trusted checkout. They should still avoid shell injection, unsafe unquoted variables, and accidental deletion outside repo-owned temp/output directories.

## Attack Surface, Mitigations, and Attacker Stories

Primary attack surfaces:

- `CodexAppServerTransport` launches Codex, frames JSON-RPC payloads over stdio, stores pending continuations by request ID, and broadcasts server events.
- `CodexRPCEnvelope` and `CodexAppServerProtocol` classify and decode inbound JSON-RPC responses, requests, and notifications.
- `CodexAppServer` exposes thread, turn, filesystem, config, MCP, hook, model, extension, plugin, and history APIs.
- `CodexFS` routes filesystem metadata, directory, file-read, watch, and local fuzzy discovery requests through the app-server.
- `ThreadHistoryStore` persists and reconciles local thread, turn, command, file, and token history.
- Maintainer scripts launch tools including `codex`, `quicktype`, `uv`, `swiftc`, `git`, and `gh`.

Existing mitigations observed:

- Public request IDs for interactive approvals are internal, and turn-handle response APIs pass expected thread and turn IDs before delegating.
- `CodexAppServerTransport` routes responses by top-level JSON-RPC envelope ID before protocol-specific decode.
- Command-exec helpers use argv arrays, not shell-interpolated command strings.
- Git observability uses fixed `git -C <cwd> ...` argv shapes with output caps and timeouts.
- Feature-owned mutation surfaces such as plugin marketplace upgrade are gated by `SwiftASBFeaturePolicy`.
- Compatibility diagnostics distinguish supported, outside-window, and unknown Codex CLI versions.

Realistic attacker stories:

- A malformed or future Codex app-server response uses surprising JSON-RPC ID shapes, unknown policy enum values, or very large payloads and causes SwiftASB to misrepresent state to a downstream app.
- A lower-trust SwiftASB client displays or acts on hook/plugin/MCP/filesystem metadata without treating it as sensitive local inventory.
- A local environment or explicit configuration selects an unexpected Codex executable.
- A maintainer runs schema/release tooling in a checkout where local environment variables point tools at unexpected executables or output paths.

Out-of-scope or lower-severity stories:

- A fully trusted downstream app intentionally granting session-wide permissions is not a SwiftASB vulnerability by itself.
- The local user explicitly choosing a malicious executable path is operator-controlled configuration, though SwiftASB should make diagnostics clear.
- Codex app-server enforcement failures are upstream Codex issues unless SwiftASB misrepresents or bypasses the app-server-owned boundary.

## Severity Calibration

Critical:

- SwiftASB directly bypasses Codex's sandbox or approval layer and executes attacker-controlled commands, reads arbitrary local files, or writes executable/startup files without Codex policy.
- SwiftASB accepts a forged approval/request identity and answers a different pending request than the UI displayed.

High:

- A malformed JSON-RPC or policy payload causes SwiftASB to grant or represent broader permissions than the app-server requested.
- Downstream apps can read MCP resources, filesystem bytes, or thread history across a meaningful thread/workspace boundary because SwiftASB drops or rewrites the app-server's scoping fields.

Medium:

- SwiftASB misclassifies malformed permission/policy fields, accepts lossy protocol IDs, or exposes sensitive local inventory to lower-trust UI surfaces without source classification or documentation.
- Stdio framing accepts unbounded single-line app-server messages that can exhaust memory in normal local app use.

Low:

- Diagnostics leak local paths to the same trusted local app that requested diagnostics.
- Maintainer scripts have developer-experience hardening gaps that require a trusted maintainer to run them in an already-controlled local environment.
