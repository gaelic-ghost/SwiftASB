# MCP Configuration Writing

SwiftASB does not currently expose a public MCP install or uninstall API. The
v0.135.0 app-server schema adds generic config-write methods that look like the
right backing surface for that future API, but the public Swift shape should
stay opinionated instead of exposing raw config editing to package consumers.

## Current Behavior

MCP service reads are already owned by SwiftASB:

- `CodexAppServer.mcpServerStatusSnapshot()` keeps the full app-wide status
  catalog for inspector-style callers.
- `CodexAppServer.Library.mcpServers` publishes global-only
  `McpServerSummary` values for app-wide observable UI.
- `CodexThread.mcpServers` and `CodexThread.Dashboard.mcpServers` publish the
  effective MCP services visible to a thread, with global services appended by
  the app-server status response.
- `CodexAppServer.listMcpServerStatuses(_:)` remains a deprecated
  compatibility method for callers that still need a direct list request.

Thread summaries classify a service as `global` when its name appears in
SwiftASB's global status cache and as `thread` otherwise. That is an inference,
not a first-class upstream field.

## v0.135.0 Config Write Schema

The v0.135.0 schema exposes two write requests:

- `config/value/write`
- `config/batchWrite`

Both write to the user's `config.toml` by default when `filePath` is omitted.
Both accept an optional `expectedVersion` string. `config/batchWrite` also
accepts `reloadUserConfig`; the schema describes this as hot-reloading the
updated user config into all loaded threads after writing.

Each edit uses:

- `keyPath`: a string path for the config value.
- `mergeStrategy`: `replace` or `upsert`.
- `value`: an arbitrary JSON-compatible value.

Both write methods return `ConfigWriteResponse`, which includes the canonical
written file path, a write status, a new version string, and optional overridden
metadata.

## Future Public Shape

The public Swift API should be an MCP install surface, not a generic config
editor. A likely first shape is:

```swift
try await appServer.mcp.install(
    .stdio(
        name: "docs",
        command: "/usr/bin/env",
        arguments: ["node", "/path/to/server.js"],
        enabled: true
    )
)
```

SwiftASB should translate that into config writes under `mcp_servers.<name>`
and use `reloadUserConfig: true` when batch writing. Tool approval policy can
be added as an explicit nested option once the install model has a small set of
consumer-facing defaults.

Use `install` for adding or staging an MCP server into active config,
`uninstall` for removing it from active config, and `enable` or `disable` for
changing its config state without removing the definition.

## Probe Before Shipping

Before promoting an install API, validate these behaviors against a disposable
Codex home/config file:

- Whether `keyPath` expects dotted paths such as `mcp_servers.docs` for tables.
- Whether `upsert` creates missing parent tables for nested MCP config.
- Whether `replace` removes omitted fields inside an existing table.
- Whether `expectedVersion` rejects stale writes with a recoverable app-server
  error shape.
- Whether `reloadUserConfig: true` causes `mcpServerStatus/updated` and whether
  loaded thread-scoped status pages include the new service without reopening
  threads.
- How `overriddenMetadata` behaves when managed or repo-scoped configuration
  overrides the user config.

Until those probes are captured, SwiftASB should keep config writing documented
as the intended backing behavior and avoid committing a public install method.
