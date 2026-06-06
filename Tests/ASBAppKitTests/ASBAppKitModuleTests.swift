@testable import ASBAppKit
import Testing

@Suite("ASBAppKit module")
struct ASBAppKitModuleTests {
    @Test("module scaffold is available")
    func moduleScaffoldIsAvailable() {
        #expect(ASBAppKitModule.name == "ASBAppKit")
    }
}
