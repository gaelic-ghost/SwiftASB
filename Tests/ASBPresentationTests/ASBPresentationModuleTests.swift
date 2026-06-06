@testable import ASBPresentation
import Testing

@Suite("ASBPresentation module")
struct ASBPresentationModuleTests {
    @Test("module scaffold is available")
    func moduleScaffoldIsAvailable() {
        #expect(ASBPresentationModule.name == "ASBPresentation")
    }
}
