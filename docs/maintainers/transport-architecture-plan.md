# Transport Architecture Plan

## Chosen Direction

Use the "full middle option":

- one small internal stdio transport layer
- one internal protocol layer above it
- one public client layer above that
- higher-level thread and turn wrappers on top of the public client

This keeps a real seam between:

- how bytes and framed messages move
- what Codex app-server messages mean

without prematurely abstracting beyond the single stdio transport we actually
intend to ship first.

## Planned Layers

### Transport

Primary files:

- `Sources/SwiftASB/Transport/CodexAppServerTransport.swift`
- `Sources/SwiftASB/Transport/CodexRPCRequestID.swift`
- `Sources/SwiftASB/Transport/CodexTransportError.swift`

Responsibilities:

- launch `codex app-server --listen stdio://`
- manage `Process`, stdin, stdout, and stderr
- frame newline-delimited JSON messages
- correlate requests and responses by request ID
- fan out non-response inbound messages to internal subscribers

Non-goals:

- no Codex method names here
- no public wrapper logic here
- no public API shaping here

### Protocol

Primary files:

- `Sources/SwiftASB/Protocol/CodexRPCEnvelope.swift`
- `Sources/SwiftASB/Protocol/CodexAppServerProtocol.swift`
- `Sources/SwiftASB/Protocol/CodexProtocolError.swift`

Responsibilities:

- classify raw JSON-RPC envelopes
- build typed Codex app-server requests
- decode typed Codex app-server responses
- decode notifications and server requests into internal protocol events

Non-goals:

- no process ownership here
- no pipe handling here

### Public client

Primary files:

- `Sources/SwiftASB/Public/CodexAppServer.swift`
- `Sources/SwiftASB/Public/CodexErrors.swift`

Responsibilities:

- own transport + protocol
- expose startup and shutdown lifecycle
- expose high-level client methods
- map wire and transport failures into public-facing Swift errors

### Higher-level handles

Primary files:

- `Sources/SwiftASB/Public/CodexThread.swift`
- `Sources/SwiftASB/Public/CodexTurnHandle.swift`

Responsibilities:

- wrap thread and turn identity
- present ergonomic async APIs
- hide raw protocol details behind Swift-native handles

## Planned Implementation Passes

### Pass 1

Transport spine only.

Deliverables:

- `CodexAppServerTransport`
- `CodexRPCRequestID`
- `CodexRPCEnvelope` inbound classification helpers
- `CodexTransportError`

Validation:

- `swift build`
- `swift test`

### Pass 2

Protocol layer on top of transport.

First methods:

- `initialize`
- `initialized`
- `thread/start`
- `turn/start`

### Pass 3

Public client object.

First public surface:

- `CodexAppServer.start()`
- `CodexAppServer.stop()`
- `CodexAppServer.initialize(...)`
- `CodexAppServer.startThread(...)`
- `CodexAppServer.startTurn(...)`

Current status:

- implemented as a public `CodexAppServer` actor
- public API currently returns small hand-owned value types rather than exposing
  generated `CodexWire...` models directly
- successful `initialize(...)` sends the follow-up `initialized` notification as
  part of the same handshake path
- thread and turn start paths are gated on a completed initialize handshake
- tests use a tiny internal transport protocol seam for deterministic public
  client coverage without subprocess buffering or shell-fixture flakiness

### Pass 4

Ergonomic thread and turn wrappers.

First wrapper goals:

- `CodexThread`
- `CodexTurnHandle`
- turn event streaming
- typed notification mapping

## Current Pass 1 boundary

Pass 1 is intentionally internal-first.

The transport layer may be real and testable before `SwiftASB` exposes any
public runtime client object. That keeps the process and framing mechanics
stable before public wrapper design starts to depend on them.
