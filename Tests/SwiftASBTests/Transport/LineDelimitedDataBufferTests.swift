import Foundation
@testable import SwiftASB
import Testing

@Suite(.serialized)
struct LineDelimitedDataBufferTests {
    @Test("drains complete lines and preserves partial trailing data")
    func drainsCompleteLines() {
        var buffer = LineDelimitedDataBuffer()

        #expect(buffer.append(Data("one".utf8)).isEmpty)
        #expect(buffer.append(Data("\ntwo\nthree".utf8)) == [
            Data("one".utf8),
            Data("two".utf8),
        ])
        #expect(buffer.finishPartialLine() == Data("three".utf8))
        #expect(buffer.isEmpty)
    }

    @Test("removes a complete line before returning it to the caller")
    func removesLineBeforeReturningIt() {
        var buffer = LineDelimitedDataBuffer()

        let lines = buffer.append(Data("malformed-json\nnext-json\npartial".utf8))

        #expect(lines == [
            Data("malformed-json".utf8),
            Data("next-json".utf8),
        ])
        buffer.removeAll()
        #expect(buffer.isEmpty)
    }
}
