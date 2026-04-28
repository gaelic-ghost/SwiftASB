import Foundation

private enum CodexWirePermissionProfileFileSystemPermissionsCompatibilityCodingKeys: String, CodingKey {
    case entries
    case globScanMaxDepth
}

// Hand-owned compatibility shim for the rolling Codex CLI support window.
// Remove this once the supported window no longer includes the older loose
// `permissionProfile.fileSystem.entries` shape and the promoted generated
// snapshot owns the v0.125 tagged filesystem shape directly.
extension CodexWirePermissionProfileFileSystemPermissions {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodexWirePermissionProfileFileSystemPermissionsCompatibilityCodingKeys.self
        )
        entries = try container.decodeIfPresent([CodexWireFileSystemSandboxEntry].self, forKey: .entries) ?? []
        globScanMaxDepth = try container.decodeIfPresent(Int.self, forKey: .globScanMaxDepth)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodexWirePermissionProfileFileSystemPermissionsCompatibilityCodingKeys.self
        )
        try container.encode(entries, forKey: .entries)
        try container.encodeIfPresent(globScanMaxDepth, forKey: .globScanMaxDepth)
    }
}
