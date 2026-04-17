import Testing
@testable import SwiftASB

@Test func packageNamespaceIsAvailable() async throws {
    _ = SwiftASB.self
}
