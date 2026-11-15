import Foundation

@main struct BluetoothReportProtocolTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fputs("Bluetooth protocol test failed: \(message)\n", stderr); exit(1) }
    }
    static func rejects(_ frames: [Data]) {
        var receiver = ReportBluetoothProtocol.Receiver()
        do {
            for frame in frames { _ = try receiver.accept(frame) }
            require(false, "malformed stream accepted")
        } catch {
            // A failed stream must not allow a later commit of partial bytes.
            do { _ = try receiver.accept(Data([3])); require(false, "failed stream survived reset") } catch { }
        }
    }
    static func main() throws {
        for length in [1, 65000, ReportBluetoothProtocol.limit] {
            let payload = Data((0..<length).map { UInt8($0 % 251) })
            for mtu in [20, 185, 512] {
                let frames = try ReportBluetoothProtocol.frames(payload, maximumWrite: mtu)
                require(frames.allSatisfy { $0.count <= mtu }, "frame exceeds negotiated write size")
                var receiver = ReportBluetoothProtocol.Receiver()
                var saved: [Data] = []
                for (index, frame) in frames.enumerated() {
                    if let report = try receiver.accept(frame) {
                        require(index == frames.count - 1, "report released before commit")
                        saved.append(report)
                    }
                }
                require(saved == [payload], "report must arrive exactly once and byte-for-byte")
                do { _ = try receiver.accept(Data([3])); require(false, "duplicate commit accepted") } catch { }
            }
        }
        rejects([Data()]); rejects([Data([2, 1])]); rejects([Data([3])]); rejects([Data([7])])
        rejects([Data([1, 0, 0, 0, 0])]); rejects([Data([1, 255, 255, 255, 255])])
        rejects([Data([1, 0, 0, 0, 2]), Data([2, 1]), Data([3])])
        rejects([Data([1, 0, 0, 0, 1]), Data([2, 1, 2])])
        rejects([Data([1, 0, 0, 0, 1]), Data([2])])
        do { _ = try ReportBluetoothProtocol.frames(Data(repeating: 0, count: ReportBluetoothProtocol.limit + 1), maximumWrite: 20); require(false, "oversized report encoded") } catch { }
        print("Bluetooth report framing passed: exact delivery, MTU bounds, incomplete/duplicate/malformed/overflow rejection")
    }
}
