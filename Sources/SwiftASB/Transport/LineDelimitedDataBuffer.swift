import Foundation

struct LineDelimitedDataBuffer {
    private var buffer = Data()

    init() {}

    var isEmpty: Bool {
        buffer.isEmpty
    }

    mutating func append(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        return drainCompleteLines()
    }

    mutating func removeAll(keepingCapacity: Bool = false) {
        buffer.removeAll(keepingCapacity: keepingCapacity)
    }

    mutating func finishPartialLine() -> Data? {
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
