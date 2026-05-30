# MCP Configuration Writing

SwiftASB exposes MCP installation through `CodexMCP`, but does not expose a
generic public config editor. The v0.135.0 app-server schema adds generic
config-write methods that back this API internally while the public Swift shape
stays opinionated.

This note is based on the app-server schema bundled with Codex v0.135.0 plus
the official Codex configuration reference and live config schema:

- <https://developers.openai.com/codex/config-reference#configtoml>
- <https://developers.openai.com/codex/config-schema.json>

## Current Behavior

MCP service reads are already owned by SwiftASB:

- `CodexAppServer.mcpServerStatusSnapshot()` keeps the full app-wide status
  catalog for compatibility and inspector-style callers. `CodexMCP.statusSnapshot()`
  is the preferred MCP-owned route to the same cached detail.
- `CodexAppServer.Inventory.mcpServers` and `CodexAppServer.Library.mcpServers`
  publish global-only `McpServerSummary` values for app-wide observable UI.
- `CodexThread.mcpServers` and `CodexThread.Dashboard.mcpServers` publish the
  effective MCP services visible to a thread, with global services appended by
  the app-server status response.
- `CodexAppServer.mcp.readResource(...)` is the preferred MCP-owned helper for
  reading one advertised MCP resource.
- `CodexAppServer.mcp.install(_:)` writes user-level MCP server definitions
  through app-server `config/batchWrite`, reloads user config, and refreshes
  SwiftASB's global MCP status snapshot.
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

## Codex MCP Config Shape

Codex stores MCP server definitions under `mcp_servers.<id>`. User-level
configuration lives in `~/.codex/config.toml`. Trusted projects may also have
project-scoped `.codex/config.toml` overlays; the official docs list the
project-local keys Codex ignores, and `mcp_servers` is not in that ignored
set.

The official schema currently accepts these server fields:

- Stdio transport: `command`, `args`, `cwd`, `env`, `env_vars`.
- Streamable HTTP transport: `url`, `bearer_token_env_var`,
  `http_headers`, `env_http_headers`.
- OAuth support: `scopes`, `oauth_resource`, and nested `oauth.client_id`;
  global OAuth callback and credentials-store settings live outside the server
  definition.
- Availability and behavior: `enabled`, `required`, `startup_timeout_sec`,
  `startup_timeout_ms`, `tool_timeout_sec`, `supports_parallel_tool_calls`.
- Tool policy: `enabled_tools`, `disabled_tools`,
  `default_tools_approval_mode`, and
  `tools.<tool>.approval_mode`.
- Experimental placement: `experimental_environment`, `environment_id`.

Installed plugins have a narrower override surface at
`plugins.<plugin>.mcp_servers.<server>`. Those entries intentionally exclude
transport fields; user config can only change enablement and tool policy for a
plugin-provided server.

## Future Public Shape

The public Swift API is an MCP install surface, not a generic config editor.
The first durable building block supports stdio and HTTP transports, plus one
small policy/options object:

```swift
try await appServer.mcp.install(
    .stdio(
        name: "docs",
        command: "/usr/bin/env",
        arguments: ["node", "/path/to/server.js"],
        options: .init(
            enabled: true,
            required: false,
            startupTimeout: .seconds(10),
            toolPolicy: .automatic
        )
    )
)

try await appServer.mcp.install(
    .http(
        name: "search",
        url: URL(string: "https://example.com/mcp")!,
        authorization: .bearerTokenEnvironmentVariable("SEARCH_MCP_TOKEN"),
        options: .init(toolPolicy: .allowOnly(["search"]))
    )
)
```

SwiftASB should translate that into config writes under `mcp_servers.<name>`
and use `reloadUserConfig: true` when batch writing.

Recommended public-model boundaries:

- Keep transport-specific values separate: stdio owns `command`, `arguments`,
  `currentDirectoryPath`, `environment`, and whitelisted environment variable
  names; HTTP owns `url`, bearer-token environment variable, and headers.
- Keep operational options shared: enabled, required, startup timeout, tool
  timeout, and tool policy.
- Prefer enum-backed approval modes: `automatic`, `prompt`, and `approve`.
- Prefer tool policy presets: all tools, allow-only, deny, default approval,
  and per-tool approval overrides.
- Do not expose `experimental_environment`, `environment_id`,
  `supports_parallel_tool_calls`, OAuth client settings, or plugin MCP
  overrides in the first install API. They can become deliberate follow-up
  surfaces after the basic install path is live-probed.

Use `install` for adding or staging an MCP server into active config,
`uninstall` for removing it from active config, and `enable` or `disable` for
changing its config state without removing the definition.

Scope should be explicit. A good first surface is user-level install only,
because omitting `filePath` writes the user's `config.toml`. A later
project-scoped install can accept an explicit trusted project config URL and
write that file path. Thread-scoped MCP state should remain a read/hydration
concept unless app-server exposes a thread-owned config destination.

## Probe Result

A disposable live app-server probe against Codex v0.135.0 confirmed:

- `config/batchWrite` accepts `keyPath: "mcp_servers.<name>"` for whole-table
  replacement.
- `mergeStrategy: "replace"` updates only the named server table and preserves
  unrelated MCP servers.
- `reloadUserConfig: true` makes `mcpServerStatus/list` see the written server
  without restarting app-server.
- The write response returns `status: "ok"`, a version string, the canonical
  file path, and null overridden metadata for a normal user-level write.

## Probe Before Widening

Before widening beyond the current user-level install API, validate these
behaviors against a disposable Codex home/config file:

- Whether `upsert` creates missing parent tables for nested MCP config.
- Whether `expectedVersion` rejects stale writes with a recoverable app-server
  error shape.
- Whether streamable HTTP configs become visible through `mcpServerStatus/list`
  in the same way as disabled stdio configs.
- Whether `reloadUserConfig: true` reliably emits `mcpServerStatus/updated` and
  whether loaded thread-scoped status pages include the new service without
  reopening threads.
- How `overriddenMetadata` behaves when managed or repo-scoped configuration
  overrides the user config.

Until those widening probes are captured, SwiftASB should keep config writing
as an internal backing behavior and avoid exposing raw config write methods.
