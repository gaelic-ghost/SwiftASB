import Foundation
import Testing

@Suite("ASBPresentation framework boundary")
struct ASBPresentationBoundaryTests {
    @Test("presentation sources do not import renderer frameworks")
    func presentationSourcesAvoidRendererFrameworkImports() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourceRoot = packageRoot.appending(path: "Sources/ASBPresentation")
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }

        #expect(!fileURLs.isEmpty)

        for fileURL in fileURLs {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            #expect(!source.contains("import AppKit"), "\(fileURL.lastPathComponent) imports AppKit")
            #expect(!source.contains("import SwiftUI"), "\(fileURL.lastPathComponent) imports SwiftUI")
        }
    }
}
