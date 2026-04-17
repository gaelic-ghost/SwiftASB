import Foundation

// The current bundled v2 schema dump does not expose InitializeResponse, so we
// keep this tiny handshake shape hand-owned alongside the generated v2 wire
// snapshot until upstream schema convergence makes it unnecessary.
struct CodexWireInitializeResponse: Codable, Equatable, Sendable {
    /// Absolute path to the server's $CODEX_HOME directory.
    let codexHome: String
    /// Platform family for the running app-server target, for example "unix" or "windows".
    let platformFamily: String
    /// Operating system for the running app-server target, for example "macos", "linux", or "windows".
    let platformOS: String
    let userAgent: String

    enum CodingKeys: String, CodingKey {
        case codexHome
        case platformFamily
        case platformOS = "platformOs"
        case userAgent
    }
}
