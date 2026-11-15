import Foundation
import Network
import SwiftUI

/// User-started, short-lived report receiver. No Internet endpoint or automatic upload.
final class LocalReportLink: ObservableObject {
    struct Receiver: Identifiable {
        let id: String
        let endpoint: NWEndpoint
    }
    private struct Packet: Codable { let code: String; let report: Data }
    @Published var status = "Local Wi-Fi transfer is stopped."
    @Published var receiverCode = ""
    @Published var enteredCode = ""
    @Published var receiverName = ""
    @Published var receiving = false
    @Published var searching = false
    @Published var receivers: [Receiver] = []
    var onReport: ((Data) throws -> Void)?
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [UUID: NWConnection] = [:]
    private var expiry: Timer?
    private var rejectedCodes = 0
    private var acceptedConnections = 0
    private let service = "_watchlink._tcp"
    private let frameLimit = 192 * 1024
    private func parameters() -> NWParameters {
        let value = NWParameters.tcp
        value.includePeerToPeer = true
        value.requiredInterfaceType = .wifi
        return value
    }
    private func describe(_ error: Error) -> String {
        let e=error as NSError
        return "\(e.domain)/\(e.code)"
    }
    func stopReceiving() {
        expiry?.invalidate(); expiry=nil
        listener?.cancel(); listener=nil
        for connection in connections.values { connection.stateUpdateHandler=nil; connection.cancel() }
        connections.removeAll()
        receiving=false; receiverCode=""
    }
    func startReceiving() {
        stopReceiving()
        rejectedCodes=0; acceptedConnections=0
        receiverCode=String(format:"%06d",Int.random(in:0...999999))
        receiverName="WatchLink-" + String(UUID().uuidString.prefix(8))
        do {
            let current=try NWListener(using:parameters())
            listener=current
            current.service=NWListener.Service(name:receiverName,type:service)
            current.stateUpdateHandler={ [weak self, weak current] state in
                guard let self, self.listener === current else { return }
                switch state {
                case .ready: self.receiving=true; self.status="Receiver ready for 2 minutes. Enter this code on Watch."
                case .failed(let error): self.status="Receiver failed: " + self.describe(error); self.stopReceiving()
                default: break
                }
            }
            current.newConnectionHandler={ [weak self] connection in self?.accept(connection) }
            current.start(queue:.main)
            expiry=Timer.scheduledTimer(withTimeInterval:120,repeats:false) { [weak self] _ in
                self?.stopReceiving(); self?.status="Receiver expired. Start again for a new code."
            }
        } catch { status="Cannot start receiver: " + describe(error); stopReceiving() }
    }
    private func finish(_ id: UUID) {
        if let connection=connections.removeValue(forKey:id) { connection.stateUpdateHandler=nil; connection.cancel() }
    }
    private func accept(_ connection: NWConnection) {
        guard connections.count<2, acceptedConnections<8 else { connection.cancel(); return }
        acceptedConnections+=1
        let id=UUID(); connections[id]=connection
        connection.start(queue:.main)
        DispatchQueue.main.asyncAfter(deadline:.now()+15) { [weak self] in self?.finish(id) }
        connection.receive(minimumIncompleteLength:8,maximumLength:8) { [weak self] header,_,_,_ in
            guard let self, let header, header.count==8, header.prefix(4)==Data("WLR1".utf8) else { self?.finish(id); return }
            let length=header.suffix(4).reduce(0) { ($0<<8)|Int($1) }
            guard length>0, length<=self.frameLimit else { self.finish(id); return }
            connection.receive(minimumIncompleteLength:length,maximumLength:length) { [weak self] body,_,_,_ in
                guard let self, let body, body.count==length else { self?.finish(id); return }
                do {
                    let packet=try JSONDecoder().decode(Packet.self,from:body)
                    guard self.receiving, packet.code==self.receiverCode, packet.report.count<=128*1024 else {
                        self.rejectedCodes+=1
                        connection.send(content:Data("NO".utf8),completion:.contentProcessed { _ in self.finish(id) })
                        if self.rejectedCodes>=3 { self.stopReceiving(); self.status="Receiver stopped after incorrect codes. Start again." }
                        return
                    }
                    guard let receive=self.onReport else { throw CocoaError(.fileWriteUnknown) }
                    try receive(packet.report)
                    self.status="Watch report received and saved. Use Copy, Share or Save below."
                    connection.send(content:Data("OK".utf8),completion:.contentProcessed { _ in self.finish(id) })
                } catch {
                    self.status="Report rejected: " + self.describe(error)
                    connection.send(content:Data("NO".utf8),completion:.contentProcessed { _ in self.finish(id) })
                }
            }
        }
    }
    func stopSearching() {
        browser?.cancel(); browser=nil; searching=false; receivers=[]
    }
    func findReceivers() {
        stopSearching()
        let current=NWBrowser(for:.bonjour(type:service,domain:nil),using:parameters())
        browser=current; searching=true; status="Looking for an iPhone receiver on local Wi-Fi…"
        current.browseResultsChangedHandler={ [weak self, weak current] results,_ in
            guard let self, self.browser === current else { return }
            self.receivers=results.compactMap { result in
                if case let .service(name,_,_,_) = result.endpoint, name.hasPrefix("WatchLink-") {
                    return Receiver(id:name,endpoint:result.endpoint)
                }
                return nil
            }.sorted { $0.id<$1.id }
            self.status=self.receivers.isEmpty ? "No receiver found. Start it on iPhone; allow Local Network and use the same Wi-Fi." : "Choose the receiver name shown on iPhone."
        }
        current.stateUpdateHandler={ [weak self, weak current] state in
            guard let self, self.browser === current else { return }
            if case .failed(let error)=state { self.status="Discovery failed: " + self.describe(error); self.stopSearching() }
        }
        current.start(queue:.main)
    }
    func send(_ data: Data, to receiver: Receiver) {
        guard enteredCode.count==6, enteredCode.allSatisfy(\.isNumber) else { status="Enter the 6-digit receiver code from iPhone."; return }
        guard data.count<=128*1024 else { status="Report exceeds the transfer limit."; return }
        do {
            let body=try JSONEncoder().encode(Packet(code:enteredCode,report:data))
            guard body.count<=frameLimit else { throw CocoaError(.fileReadTooLarge) }
            let length=UInt32(body.count)
            var frame=Data("WLR1".utf8)
            frame.append(contentsOf:[UInt8((length>>24)&255),UInt8((length>>16)&255),UInt8((length>>8)&255),UInt8(length&255)])
            frame.append(body)
            let connection=NWConnection(to:receiver.endpoint,using:parameters())
            let id=UUID(); connections[id]=connection
            status="Connecting to iPhone…"
            var sent=false
            connection.stateUpdateHandler={ [weak self] state in
                guard let self, self.connections[id] != nil else { return }
                switch state {
                case .ready:
                    guard !sent else { return }; sent=true
                    self.status="Sending saved Watch report…"
                    connection.send(content:frame,completion:.contentProcessed { [weak self] error in
                        guard let self else { return }
                        if let error { self.status="Send failed: " + self.describe(error); self.finish(id); return }
                        connection.receive(minimumIncompleteLength:2,maximumLength:2) { [weak self] data,_,_,error in
                            guard let self else { return }
                            self.status=data==Data("OK".utf8) ? "iPhone received and saved the Watch report." : "No receipt. Check receiver code and restart receiver." + (error.map { " " + self.describe($0) } ?? "")
                            self.finish(id)
                        }
                    })
                case .failed(let error): self.status="Connection failed: " + self.describe(error); self.finish(id)
                default: break
                }
            }
            connection.start(queue:.main)
            DispatchQueue.main.asyncAfter(deadline:.now()+20) { [weak self] in
                guard let self, self.connections[id] != nil else { return }
                self.status="Local transfer timed out. Keep both apps open on the same Wi-Fi."; self.finish(id)
            }
        } catch { status="Cannot prepare local transfer: " + describe(error) }
    }
}
