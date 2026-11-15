import Foundation

/// A bounded report stream over acknowledged GATT writes. Commit is acknowledged
/// only after the receiver validates and saves the complete report.
enum ReportBluetoothProtocol {
    static let limit = 128 * 1024
    enum Failure: Error { case malformed, tooLarge, incomplete }
    static func frames(_ report: Data, maximumWrite: Int) throws -> [Data] {
        guard !report.isEmpty, report.count <= limit, maximumWrite >= 5 else { throw Failure.tooLarge }
        let count = UInt32(report.count)
        var output = [Data([1, UInt8((count >> 24) & 255), UInt8((count >> 16) & 255), UInt8((count >> 8) & 255), UInt8(count & 255)])]
        var offset = 0
        let payload = min(maximumWrite - 1, 511)
        while offset < report.count {
            let end = min(offset + payload, report.count)
            var frame = Data([2]); frame.append(report.subdata(in: offset..<end))
            output.append(frame); offset = end
        }
        output.append(Data([3]))
        return output
    }
    struct Receiver {
        private var expected = 0
        private var bytes = Data()
        mutating func reset() { expected = 0; bytes.removeAll(keepingCapacity: false) }
        mutating func accept(_ frame: Data) throws -> Data? {
            do {
                guard let command = frame.first else { throw Failure.malformed }
                switch command {
                case 1:
                    guard frame.count == 5 else { throw Failure.malformed }
                    let length = frame.dropFirst().reduce(0) { ($0 << 8) | Int($1) }
                    guard length > 0, length <= limit else { throw Failure.tooLarge }
                    reset(); expected = length
                case 2:
                    guard expected > 0, frame.count > 1 else { throw Failure.malformed }
                    guard frame.count - 1 <= expected - bytes.count else { throw Failure.tooLarge }
                    bytes.append(frame.dropFirst())
                case 3:
                    guard frame.count == 1, expected > 0, bytes.count == expected else { throw Failure.incomplete }
                    let result = bytes; reset(); return result
                default: throw Failure.malformed
                }
                return nil
            } catch { reset(); throw error }
        }
    }
}
