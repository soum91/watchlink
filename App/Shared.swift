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
    @Published var showDirectSender = false
    @Published var lastWatchReceipt = ""
    private var reportRequestID: UUID?
    let localLink = LocalReportLink()
    let bluetoothLink = BluetoothReportLink()
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
        localLink.onReport = { [weak self] data in
            guard let self else { throw CocoaError(.fileWriteUnknown) }
            try self.receive(data, channel: "local Wi-Fi")
        }
        bluetoothLink.onReport = { [weak self] data in
            guard let self else { throw CocoaError(.fileWriteUnknown) }
            try self.receive(data, channel: "Bluetooth")
        }
        bluetoothLink.reportProvider = {
            try Self.validatedData(Data(contentsOf: Self.reportURL))
        }
        if hasReport { try? report.write(to: Self.textReportURL, atomically: true, encoding: .utf8) }
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
                try? text.write(to: Self.textReportURL, atomically: true, encoding: .utf8)
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
    static let maxReportBytes = 128 * 1024
    static let maxMessageBytes = 48 * 1024
    @Published var transferDetails = "No transfer attempted."
    private var deliveryID: String?
    static var textReportURL: URL { reportURL.deletingPathExtension().appendingPathExtension("txt") }
    var hasReport: Bool { (try? Self.validatedData(Data(report.utf8))) != nil }
    var compactSummary: String {
        guard let data=report.data(using:.utf8), let json=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else { return "Run a scan first." }
        let checks=json["checks"] as? [[String:Any]] ?? []
        var lines=["WatchLink " + watchLinkVersion, reportSource]
        for check in checks {
            let normal=check["normalAccess"] as? [String:Any] ?? [:]
            lines.append("\(check["label"] as? String ?? "Candidate"): errno \(normal["errno"] ?? "?")")
        }
        let attempts=checks.flatMap { $0["protectedProbes"] as? [[String:Any]] ?? [] }
        let attempted=attempts.filter { (($0["result"] as? [String:Any])?["attempted"] as? Bool)==true }.count
        lines.append("Protected methods attempted: \(attempted)/\(attempts.count)")
        lines.append("Pairing changed: \(json["pairingChanged"] ?? false)")
        lines.append(transferDetails)
        return lines.joined(separator:"\n")
    }
    private static func validatedData(_ data: Data) throws -> Data {
        guard data.count <= maxReportBytes,
              let json=try JSONSerialization.jsonObject(with:data) as? [String:Any],
              json["app"] as? String == "WatchLink", json["schema"] as? Int == 1 else { throw CocoaError(.fileReadCorruptFile) }
        return data
    }
    private func connectionState(_ session: WCSession) -> String {
        var text="Activation=\(session.activationState.rawValue), reachable=\(session.isReachable)"
        #if os(iOS)
        text += ", paired=\(session.isPaired), Watch app installed=\(session.isWatchAppInstalled)"
        #else
        text += ", iPhone companion installed=\(session.isCompanionAppInstalled)"
        #endif
        return text
    }
    private func failure(_ channel: String, _ error: Error) {
        let e=error as NSError
        DispatchQueue.main.async {
            self.transferDetails="\(channel): \(e.domain) / \(e.code). " + (self.session.map(self.connectionState) ?? "No session")
            if !self.status.hasPrefix("iPhone received") && !self.status.hasPrefix("Received companion") {
                self.status="\(channel) failed: \(e.domain)/\(e.code). Use the nearby iPhone receiver."
                #if os(watchOS)
                self.showDirectSender=true
                #endif
            }
        }
    }
    private func receive(_ data: Data, channel: String) throws {
        let checked=try Self.validatedData(data)
        #if os(iOS)
        guard let origin=try JSONSerialization.jsonObject(with:checked) as? [String:Any], origin["platform"] as? String == "watchOS" else {
            throw CocoaError(.fileReadCorruptFile)
        }
        #endif
        try checked.write(to:Self.receivedReportURL,options:.atomic)
        guard let text=String(data:checked,encoding:.utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        DispatchQueue.main.async {
            self.reportRequestID=nil
            self.report=text
            self.lastWatchReceipt="Watch report saved via " + channel + " (\(checked.count) bytes)."
            self.status="Received companion report via " + channel + "."
            self.transferDetails="Receipt confirmed; \(checked.count) bytes saved locally."
        }
    }
    func showReceivedWatchReport() {
        do {
            let data=try Self.validatedData(Data(contentsOf:Self.receivedReportURL))
            let json=try JSONSerialization.jsonObject(with:data) as? [String:Any]
            guard json?["platform"] as? String == "watchOS", let text=String(data:data,encoding:.utf8) else { throw CocoaError(.fileReadCorruptFile) }
            report=text; status="Showing the saved Watch report."
        } catch { status="No verified Watch report has been received yet. The current report may be an iPhone scan." }
    }
    func refreshConnection() {
        guard let session else { status="Watch Connectivity is unavailable."; return }
        transferDetails=connectionState(session)
        if session.activationState != .activated { session.activate() }
    }
    private func useDirectReceiver(_ reason: String) {
        #if os(iOS)
        reportRequestID=nil
        bluetoothLink.startReceiving()
        localLink.ensureReceiving()
        status=reason + " Nearby iPhone receiver opened below. On Watch, tap Send report and choose this receiver."
        #endif
    }
    func requestWatchReport() {
        refreshConnection()
        // Installed-app registration can be false even while the Watch app is
        // running. Treat actual reachability as the route criterion and fall
        // back independently of registration, without prescribing a reinstall.
        guard let session, session.activationState == .activated, session.isReachable else {
            useDirectReceiver("Watch Connectivity is unavailable.")
            return
        }
        let requestID=UUID()
        reportRequestID=requestID
        status="Requesting saved Watch report…"
        DispatchQueue.main.asyncAfter(deadline:.now()+8) { [weak self] in
            guard let self, self.reportRequestID==requestID else { return }
            self.useDirectReceiver("The companion request timed out.")
        }
        session.sendMessage(["kind":"watchlink-request-report"],replyHandler:{ reply in
            if let data=reply["data"] as? Data {
                do { try self.receive(data,channel:"iPhone request") }
                catch {
                    DispatchQueue.main.async {
                        guard self.reportRequestID==requestID else { return }
                        self.useDirectReceiver("The companion returned an invalid report.")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    guard self.reportRequestID==requestID else { return }
                    self.status=(reply["reason"] as? String) ?? "Watch queued its report. Waiting for delivery."
                }
            }
        },errorHandler:{ error in
            DispatchQueue.main.async {
                guard self.reportRequestID==requestID else { return }
                let detail=error as NSError
                self.useDirectReceiver("Companion request failed: \(detail.domain)/\(detail.code).")
            }
        })
    }
    func sendHTTPReport() {
        do { localLink.sendHTTP(try Self.validatedData(Data(contentsOf:Self.reportURL))) }
        catch { localLink.status="Run a scan on this Watch first; no saved report is available." }
    }
    func sendLocalReport(to receiver: LocalReportLink.Receiver) {
        do { localLink.send(try Self.validatedData(Data(contentsOf: Self.reportURL)), to: receiver) }
        catch { localLink.status="Run a scan on this Watch first; no saved report is available." }
    }
    func sendReport() {
        refreshConnection()
        guard let session, session.activationState == .activated, session.isReachable else {
            #if os(watchOS)
            showDirectSender=true
            status="Choose the nearby iPhone receiver shown in WatchLink."
            #else
            useDirectReceiver("Watch Connectivity is unavailable.")
            #endif
            return
        }
        do {
            let data=try Self.validatedData(Data(report.utf8))
            let id=UUID().uuidString
            deliveryID=id
            // The queued file owns an immutable snapshot; a later scan cannot replace it.
            let directory=FileManager.default.temporaryDirectory.appendingPathComponent("WatchLinkTransfers",isDirectory:true)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let file=directory.appendingPathComponent(id).appendingPathExtension("json")
            try data.write(to:file,options:.atomic)
            session.transferFile(file,metadata:["kind":"watchlink-report","schema":1,"id":id])
            status="Report queued. Waiting for iPhone receipt."
            if data.count <= Self.maxMessageBytes {
                do { try session.updateApplicationContext(["kind":"watchlink-report","data":data,"id":id]) }
                catch { failure("Background context",error) }
                if session.isReachable {
                    session.sendMessageData(data,replyHandler:{ ack in
                        DispatchQueue.main.async {
                            if ack == Data("saved".utf8), self.deliveryID==id {
                                self.deliveryID=nil
                                self.status="iPhone received and saved the report."
                                self.transferDetails="Immediate delivery acknowledged."
                            }
                        }
                    },errorHandler:{ self.failure("Immediate send",$0) })
                }
            }
        } catch { failure("Prepare report",error) }
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.transferDetails=self.connectionState(session) }
        if let error { failure("Activate companion",error) }
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.transferDetails=self.connectionState(session) }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String:Any], replyHandler: @escaping ([String:Any])->Void) {
        if message["kind"] as? String == "watchlink-request-report" {
            do {
                let data=try Self.validatedData(Data(contentsOf:Self.reportURL))
                if data.count <= Self.maxMessageBytes { replyHandler(["data":data]) }
                else {
                    replyHandler(["reason":"Watch is sending a larger report through the file channel."])
                    DispatchQueue.main.async { self.sendReport() }
                }
            } catch { replyHandler(["reason":"Run a scan on the Watch first; no saved report is available."]) }
        } else if message["kind"] as? String == "watchlink-report-ack" {
            DispatchQueue.main.async {
                if self.deliveryID == message["id"] as? String {
                    self.deliveryID=nil; self.status="iPhone received and saved the report."
                }
            }
            replyHandler(["ok":true])
        } else { replyHandler(["ok":false]) }
    }
    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data)->Void) {
        do { try receive(messageData,channel:"immediate message"); replyHandler(Data("saved".utf8)) }
        catch { replyHandler(Data("rejected".utf8)); failure("Import",error) }
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String:Any]) {
        guard applicationContext["kind"] as? String == "watchlink-report", let data=applicationContext["data"] as? Data else { return }
        do { try receive(data,channel:"background context"); acknowledge(session,id:applicationContext["id"] as? String) }
        catch { failure("Import context",error) }
    }
    private func acknowledge(_ session: WCSession, id: String?) {
        guard let id, session.isReachable else { return }
        session.sendMessage(["kind":"watchlink-report-ack","id":id],replyHandler:{ _ in },errorHandler:{ _ in })
    }
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["kind"] as? String == "watchlink-report" else { return }
        do {
            let size=try file.fileURL.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? Int.max
            guard size <= Self.maxReportBytes else { throw CocoaError(.fileReadTooLarge) }
            try receive(Data(contentsOf:file.fileURL),channel:"file transfer")
            acknowledge(session,id:file.metadata?["id"] as? String)
        } catch { failure("Import file",error) }
    }
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let id=fileTransfer.file.metadata?["id"] as? String
        if let error { failure("File transfer",error) }
        else { DispatchQueue.main.async {
            if self.deliveryID==id { self.status="File delivered; waiting for companion receipt acknowledgement." }
        } }
        let parent=fileTransfer.file.fileURL.deletingLastPathComponent()
        if parent.lastPathComponent=="WatchLinkTransfers" { try? FileManager.default.removeItem(at:fileTransfer.file.fileURL) }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}
