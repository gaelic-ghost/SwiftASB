# ``CodexMCP``

Install MCP servers through Codex app-server configuration writes.

## Overview

`CodexMCP` is exposed through ``CodexAppServer/mcp``. Use it when a consumer
needs to install a stdio or streamable HTTP MCP server without editing
`config.toml` directly or sending raw config-write requests.

```swift
try await appServer.mcp.install(
    .stdio(
        name: "docs",
        command: "/usr/bin/env",
        arguments: ["node", "/path/to/server.js"],
        options: .init(toolPolicy: .automatic)
    )
)
```

Install writes user-level Codex config under `mcp_servers.<name>`, asks the
app-server to reload user config, and refreshes SwiftASB's global MCP status
snapshot after the write succeeds.

Server names must contain only ASCII letters, numbers, hyphens, or underscores
because Codex's config-write method receives a dotted key path. Use
``CodexAppServer/mcpServerStatusSnapshot()`` for the full post-install catalog
or observable companions such as ``CodexAppServer/Library/mcpServers`` for
compact UI summaries.

## Topics

### Installing

- ``install(_:)``
- ``InstallResult``

### Server Definitions

- ``ServerDefinition``
- ``StdioServer``
- ``HTTPServer``
- ``HTTPAuthorization``

### Options

- ``InstallOptions``
- ``ToolPolicy``
- ``ToolApprovalMode``
