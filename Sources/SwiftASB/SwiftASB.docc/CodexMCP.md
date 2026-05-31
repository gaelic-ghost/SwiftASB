# ``CodexExtensions/MCP``

Install MCP servers and inspect MCP details through SwiftASB-owned helpers.

## Overview

`CodexExtensions.MCP` is exposed through ``CodexAppServer/extensions`` as
``CodexExtensions/mcp``. Use it when a consumer needs to inspect the full cached
global MCP catalog or read one advertised MCP resource. For installs, prefer the
unified extension install surface.

```swift
try await appServer.extensions.install(
    .mcp(
        .stdio(
            name: "docs",
            command: "/usr/bin/env",
            arguments: ["node", "/path/to/server.js"],
            options: .init(toolPolicy: .automatic)
        )
    )
)
```

Install writes user-level Codex config under `mcp_servers.<name>`, asks the
app-server to reload user config, and refreshes SwiftASB's global MCP status
snapshot after the write succeeds.

Server names must contain only ASCII letters, numbers, hyphens, or underscores
because Codex's config-write method receives a dotted key path.

Use observable companions such as ``CodexExtensions/Inventory/mcpServers``,
``CodexAppServer/Library/mcpServers``, and ``CodexThread/Dashboard/mcpServers``
for compact UI summaries. Those properties intentionally expose
``CodexAppServer/McpServerSummary`` values: name, scope, auth state, and
advertised capability counts. Use ``statusSnapshot()`` when an inspector needs
the full cached catalog with resources, resource templates, and tool schemas.
Use ``readResource(_:)`` or ``readResource(server:uri:threadID:)`` to read the
contents for one advertised resource.

## Topics

### Installing

- ``install(_:)``
- ``InstallResult``

### Inspecting

- ``statusSnapshot()``
- ``readResource(_:)``
- ``readResource(server:uri:threadID:)``

### Server Definitions

- ``ServerDefinition``
- ``StdioServer``
- ``HTTPServer``
- ``HTTPAuthorization``

### Options

- ``InstallOptions``
- ``ToolPolicy``
- ``ToolApprovalMode``
