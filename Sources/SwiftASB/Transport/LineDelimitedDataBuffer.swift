import Foundation

internal struct LineDelimitedDataBuffer: Sendable {
    private var buffer = Data()

    internal init() {}

    internal var isEmpty: Bool {
        buffer.isEmpty
    }

    internal mutating func append(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        return drainCompleteLines()
    }

    internal mutating func removeAll(keepingCapacity: Bool = false) {
        buffer.removeAll(keepingCapacity: keepingCapacity)
    }

    internal mutating func finishPartialLine() -> Data? {
        guard !buffer.isEmpty else {
            return nil
        }

        let partialLine = buffer
        buffer.removeAll(keepingCapacity: false)
        return partialLine
    }

    private mutating func drainCompleteLines() -> [Data] {
        var lines: [Data] = []

        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            lines.append(Data(buffer[..<newlineIndex]))
            buffer.removeSubrange(...newlineIndex)
        }

        return lines
    }
}
