@testable import ASBSwiftUI
import Testing

@Suite("ASBSwiftUI module")
struct ASBSwiftUIModuleTests {
    @Test("module scaffold is available")
    func moduleScaffoldIsAvailable() {
        #expect(ASBSwiftUIModule.name == "ASBSwiftUI")
    }
}
