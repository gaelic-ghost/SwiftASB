# Codex App-Server Integration Plan

## Goal

Plan `SwiftASB` as a native Swift wrapper around the local Codex app-server surface, with a Cocoa-friendly, type-safe API that feels like Swift rather than a thin JSON-RPC transport dump.

## What The Current OpenAI Surfaces Show

### Official docs

- The current OpenAI Codex workflow guide describes the Python path as: launch Codex CLI locally, expose it as an MCP server, and orchestrate it from the OpenAI Agents SDK in Python.
- The guide's `MCPServerStdio` example launches Codex with `npx -y codex mcp-server`.
- The general Agents SDK docs frame the SDK path as the right fit when the host app wants to own orchestration, tool execution, state, and runtime behavior in typed application code.

Sources:

- <https://developers.openai.com/codex/guides/agents-sdk>
- <https://developers.openai.com/api/docs/guides/agents>
- <https://developers.openai.com/api/docs/libraries>

### `openai/codex` repo

The upstream repo currently contains an experimental Python SDK specifically for the app-server:

- `sdk/python/README.md`
- `sdk/python/docs/api-reference.md`
- `sdk/python/docs/faq.md`
- `codex-rs/app-server/README.md`
- `codex-rs/app-server-client/README.md`

Key takeaways from those files:

- The Python SDK is not just a wrapper over the public OpenAI API. It is a wrapper over `codex app-server` JSON-RPC v2 over stdio.
- The Python SDK exposes a deliberately small high-level surface:
  - `Codex` / `AsyncCodex`
  - `Thread` / `AsyncThread`
  - `TurnHandle` / `AsyncTurnHandle`
  - typed input items
  - generated protocol models
- The Python SDK intentionally keeps public kwargs in snake_case while mapping to camelCase on the wire.
- The published Python SDK is designed to pin an exact `codex-cli-bin` runtime dependency, not simply assume a random local `codex` install on `PATH`.
- For local development, the upstream SDK allows overriding the binary explicitly with `AppServerConfig(codex_bin=...)`.
- The app-server itself documents JSON-RPC v2 over stdio as the default transport, and the server can generate TypeScript or JSON Schema bindings for the current protocol version.

### Local CLI check on this machine

On April 17, 2026 in this repo, the local CLI reports:

- `codex app-server` exists.
- `codex app-server generate-ts`
- `codex app-server generate-json-schema`

That matters because it means native Swift code generation or validation can be driven directly from the user's installed Codex CLI during development.

## The Real Architectural Choice

The main decision is not "Python or Swift."

The real choice is:

1. Use the Python SDK as a runtime dependency and bridge that into Swift.
2. Use the Python SDK only as a reference model and implement a native Swift client directly against `codex app-server`.

## Option 1: Runtime Bridge Through The Python SDK

### Shape

`SwiftASB` would launch Python, import `codex_app_server`, and expose Swift wrappers around the Python SDK objects and methods.

### Upsides

- Reuses the upstream high-level API design immediately.
- Lets us mirror the current `Codex` / `Thread` / `TurnHandle` split very closely.
- Avoids implementing the JSON-RPC protocol details ourselves in the first pass.

### Downsides

- Native Swift apps on macOS do not get a clean, universal Python runtime story for free.
- We would need to solve Python environment discovery, package installation, version pinning, import failures, and user-facing diagnostics.
- The upstream published Python package expects a pinned `codex-cli-bin` runtime package, which cuts against the "just use the user's existing Codex CLI install" idea.
- Bridging Python objects and async event streams into Swift would add a second interop layer on top of the actual app-server protocol.
- For a Cocoa-first API, this path gives us the least control over enum shape, actor isolation, stream modeling, and error typing.

### Packaging implications

If we choose this path, we should assume a real packaging tool is required.

Likely candidates:

- `uv` for isolated environment bootstrap and repeatable installs.
- A managed project-local virtual environment.
- Explicit runtime checks for Python version, package presence, and SDK compatibility.

This is workable, but it is not the simplest user story.

## Option 2: Native Swift Client Against `codex app-server`

### Shape

`SwiftASB` would spawn `codex app-server --listen stdio://`, speak newline-delimited JSON-RPC directly, and expose a higher-level Swift API inspired by the Python SDK rather than depending on it.

### Upsides

- Best fit for a comfy, enum-heavy, Cocoa-native API.
- No Python runtime dependency for end users.
- Cleanest story if the user already has Codex CLI installed and authenticated locally.
- Lets us model notifications, approvals, thread lifecycle, and turn streaming natively with Swift enums, structs, and async sequences.
- Keeps the transport boundary simple:
  - Swift process
  - spawned `codex app-server`
  - stdio JSON-RPC

### Downsides

- We own protocol binding generation, wire compatibility, and client lifecycle behavior.
- We need to choose how generated schema types relate to the higher-level public Swift API.
- We need to decide how much of the app-server surface to expose in v1 instead of blindly wrapping every message.

### Packaging implications

This path likely needs no Python packaging at runtime.

The practical runtime assumptions become:

- user has a working `codex` CLI install
- user is already authenticated in Codex
- `SwiftASB` can locate the `codex` binary or accept an explicit override path

Development-time tooling may still benefit from Python or other generators, but that would be maintainer tooling, not an end-user runtime dependency.

## Option 3: Hybrid Development Model

This is the most attractive near-term direction.

### Shape

- Use the Python SDK and upstream docs as the behavioral reference.
- Implement the shipped library natively in Swift against `codex app-server`.
- Treat the Python SDK as a design oracle for:
  - high-level lifecycle shape
  - naming expectations
  - common convenience APIs
  - event and result semantics

### Why this is likely the best fit

- It preserves the native Swift experience.
- It avoids forcing Python packaging onto users.
- It still gives us a grounded reference implementation to compare behavior against.
- It keeps open the option of building development fixtures or compatibility tests from upstream schema artifacts later.

## Recommended Direction

Build `SwiftASB` as a native Swift client for `codex app-server`, not as a runtime wrapper around the Python SDK.

Use the upstream Python SDK as a reference surface, not as an end-user dependency.

That recommendation is based on three things:

1. The package goal is explicitly Cocoa-friendly and type-safe.
2. The upstream Python SDK's published packaging model is optimized for its own pinned runtime package, not for "reuse whatever local Codex install the user already has."
3. The local CLI already exposes codegen-friendly app-server schema commands, which makes a native Swift implementation more realistic than it would otherwise be.

## Suggested Swift Public Shape

The Python SDK surface is a good starting point for the conceptual model, but the Swift API should feel like Swift.

### Candidate top-level types

- `CodexAppServer`
- `CodexAppServer.Configuration`
- `CodexThread`
- `CodexTurn`
- `CodexTurnHandle`
- `CodexRunResult`
- `CodexInputItem`
- `CodexNotification`
- `CodexRPCError`

### Candidate enum-heavy surfaces

- `CodexApprovalPolicy`
- `CodexSandboxMode`
- `CodexPersonality`
- `CodexReasoningEffort`
- `CodexServiceTier`
- `CodexThreadSortKey`
- `CodexNotificationPayload`

### Concurrency model

Likely Swift-native shape:

- `CodexAppServer` as an owning actor or reference type with explicit startup/shutdown.
- `CodexTurnHandle.events` as `AsyncThrowingStream<CodexNotification, Error>`.
- one high-level `run(...)` convenience path for the common case.
- one lower-level turn path for streaming, steering, and interrupt support.

## Packaging Recommendation

### Runtime

Assume no Python packaging tool is required for end users.

Runtime requirements should instead be:

- local Codex CLI installed
- local Codex auth/session already working
- optional explicit path override for the Codex binary

### Maintainer tooling

Python tooling may still be useful for maintainers if it saves time on schema or fixture work, but it should stay out of the shipped runtime contract unless we discover a hard blocker.

If we do need Python tooling for development, prefer:

- `uv` for isolated, reproducible maintainer workflows

That keeps any Python dependency contained to development scripts instead of becoming part of the library's public install story.

Current repo direction:

- use the bundled Codex protocol schema dumps as the source of truth
- derive quicktype-friendly synthetic roots from those bundles
- generate consolidated Swift wire files from the derived schemas
- patch dynamic JSON holes to a typed `CodexWireJSONValue`
- keep the resulting generated layer staged and internal-first

That gives maintainers a repeatable codegen path without turning Python into an
end-user runtime dependency.

## Good First Implementation Slice

1. Start `codex app-server --listen stdio://`.
2. Implement `initialize` + `initialized`.
3. Support `thread/start`.
4. Support a simple turn/run path for text-only input.
5. Decode the most important notifications needed for turn completion.
6. Return a small high-level result type similar to the Python SDK's `RunResult`.

That gets us to a useful first vertical slice without needing the full protocol on day one.

## Open Questions

- Should `SwiftASB` expose generated wire models publicly, or keep them internal and vend only hand-shaped Swift types?
- Do we want strict version matching against the local `codex` binary, or a softer compatibility window with capability checks?
- Should the first release support only stdio, even though websocket transport exists experimentally?
- Do we want schema generation as part of the repo toolchain from day one, or begin with a hand-curated subset of the protocol?

## Initial Conclusion

Use the Python SDK to understand the app-server's intended ergonomic shape.

Do not make the Python SDK a runtime dependency unless we later discover a capability that is genuinely too expensive to reproduce natively.

The strongest current path is:

- native Swift client
- local `codex app-server` subprocess
- stdio JSON-RPC transport
- development-time schema/codegen support from the user's or maintainer's installed Codex CLI
