import Foundation
import SwiftUI
import WatchConnectivity

let watchLinkVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
    + " (" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?") + ")"

final class WatchLinkModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var report: String
    @Published var running = false
    @Published var status = "Ready. Pairing state is unchanged."
    @Published var protectedAccess = false
    private let worker = DispatchQueue(label: "dev.watchlink.probe")
    private var session: WCSession?
    static var reportURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WatchLink-report.json")
    }
    static var receivedReportURL: URL {
        reportURL.deletingLastPathComponent().appendingPathComponent("WatchLink-received-report.json")
    }
    var reportSource: String {
        guard let data = report.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let platform = json["platform"] as? String else { return "No scan report loaded" }
        let source = platform == "watchOS" ? "Watch" : (platform == "iOS" ? "iPhone" : platform)
        return "Report source: " + source + " · " + (json["os"] as? String ?? "OS unknown")
    }
    override init() {
        let candidates = [Self.reportURL, Self.receivedReportURL].sorted {
            let first = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let second = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return first > second
        }
        report = candidates.lazy.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.first
            ?? "Run a scan to create a report."
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    func scan() {
        guard !running else { return }
        running = true
        let requested = protectedAccess
        status = requested ? "Checking protected access…" : "Checking normal access…"
        worker.async { [weak self] in
            let text = DWRunProbe(requested)
            do {
                try text.write(to: Self.reportURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    self?.report = text; self?.running = false
                    self?.status = "Report saved. No pairing changes made."
                }
            } catch {
                DispatchQueue.main.async {
                    self?.report = text; self?.running = false
                    self?.status = "Scan finished; report could not be saved."
                }
            }
        }
    }
    func sendReport() {
        guard let session, session.activationState == .activated else {
            status = "Companion connection is not activated."; return
        }
        guard FileManager.default.fileExists(atPath: Self.reportURL.path) else {
            status = "Run a scan first."; return
        }
        session.transferFile(Self.reportURL, metadata: ["kind": "watchlink-report", "schema": 1])
        status = "Transfer queued; delivery is not yet confirmed."
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if error != nil { DispatchQueue.main.async { self.status = "Companion connection failed to activate." } }
    }
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["kind"] as? String == "watchlink-report" else { return }
        do {
            let values = try file.fileURL.resourceValues(forKeys: [.fileSizeKey])
            guard let size = values.fileSize, size <= 128 * 1024 else { return }
            let data = try Data(contentsOf: file.fileURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["app"] as? String == "WatchLink", json["schema"] as? Int == 1,
                  let text = String(data: data, encoding: .utf8) else { return }
            let destination = Self.receivedReportURL
            try data.write(to: destination, options: .atomic)
            DispatchQueue.main.async { self.report = text; self.status = "Received companion report." }
        } catch { DispatchQueue.main.async { self.status = "Could not import companion report." } }
    }
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        DispatchQueue.main.async {
            self.status = error == nil ? "Report transfer completed." : "Report transfer failed. Keep the report and retry."
        }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
