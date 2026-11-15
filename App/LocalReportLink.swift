import Foundation
import Network
import Darwin
#if os(iOS)
import UIKit
#endif
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
    @Published var receiverAddress = ""
    @Published var enteredAddress = ""
    private var httpSession: URLSession?
    private var httpTask: URLSessionDataTask?
    private var httpRequestID: UUID?
    @Published var receiving = false
    @Published var searching = false
    @Published var receivers: [Receiver] = []
    var onReport: ((Data) throws -> Void)?
    #if os(iOS)
    private var previousIdleTimer: Bool?
    #endif
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
        value.prohibitedInterfaceTypes = [.cellular]
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
        #if os(iOS)
        if let previousIdleTimer { UIApplication.shared.isIdleTimerDisabled=previousIdleTimer; self.previousIdleTimer=nil }
        #endif
    }
    func startReceiving() {
        stopReceiving()
        #if os(iOS)
        previousIdleTimer=UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled=true
        #endif
        rejectedCodes=0; acceptedConnections=0
        receiverCode=String(format:"%06d",Int.random(in:0...999999))
        receiverName="WatchLink-" + String(UUID().uuidString.prefix(8))
        do {
            let current=try NWListener(using:parameters())
            listener=current
            #if !WATCHLINK_TRANSPORT_TESTS
            current.service=NWListener.Service(name:receiverName,type:service)
            #endif
            current.stateUpdateHandler={ [weak self, weak current] state in
                guard let self, self.listener === current else { return }
                switch state {
                case .ready:
                    self.receiving=true
                    if let address=Self.localIPv4(), let port=current?.port { self.receiverAddress="\(address):\(port.rawValue)" }
                    self.status="HTTP receiver ready for 2 minutes. Enter its address and code on Watch."
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
    #if WATCHLINK_TRANSPORT_TESTS
    var testPort: NWEndpoint.Port? { listener?.port }
    #endif
    private func readExactly(_ count: Int, from connection: NWConnection, accumulated: Data = Data(), completion: @escaping (Result<Data, Error>) -> Void) {
        guard accumulated.count < count else { completion(.success(accumulated)); return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: count - accumulated.count) { [weak self] data, _, complete, error in
            if let error { completion(.failure(error)); return }
            var next=accumulated
            if let data { next.append(data) }
            if next.count==count { completion(.success(next)); return }
            guard !complete, let data, !data.isEmpty, let self else {
                completion(.failure(CocoaError(.fileReadCorruptFile))); return
            }
            self.readExactly(count, from: connection, accumulated: next, completion: completion)
        }
    }
    private func reply(_ value: String, on connection: NWConnection, id: UUID) {
        connection.send(content: Data(value.utf8), contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { [weak self] _ in
            // Let the peer consume the receipt before cancelling the connection.
            DispatchQueue.main.asyncAfter(deadline: .now()+1) { self?.finish(id) }
        })
    }
    private func accept(_ connection: NWConnection) {
        guard connections.count<2, acceptedConnections<8 else { connection.cancel(); return }
        acceptedConnections+=1
        let id=UUID(); connections[id]=connection
        connection.start(queue:.main)
        status="Watch connected. Reading report header…"
        DispatchQueue.main.asyncAfter(deadline:.now()+60) { [weak self] in
            guard let self, self.connections[id] != nil else { return }
            self.status="Receiver timed out while reading the report."; self.finish(id)
        }
        readExactly(8,from:connection) { [weak self] result in
            guard let self else { return }
            if case let .success(header)=result, header.prefix(4)==Data("POST".utf8) {
                self.readHTTPHeaders(connection, id:id, buffer:header); return
            }
            guard case let .success(header)=result, header.prefix(4)==Data("WLR1".utf8) else {
                self.status="Invalid or interrupted report header."; self.reply("HD",on:connection,id:id); return
            }
            let length=header.suffix(4).reduce(0) { ($0<<8)|Int($1) }
            guard length>0, length<=self.frameLimit else { self.status="Report frame exceeds limit."; self.reply("SZ",on:connection,id:id); return }
            self.status="Reading \(length) report bytes…"
            self.readExactly(length,from:connection) { [weak self] result in
                guard let self else { return }
                do {
                    let body=try result.get()
                    let packet=try JSONDecoder().decode(Packet.self,from:body)
                    guard self.receiving, packet.code==self.receiverCode else {
                        self.rejectedCodes+=1
                        self.status="Incorrect or expired receiver code."
                        self.reply("PC",on:connection,id:id)
                        if self.rejectedCodes>=3 {
                            DispatchQueue.main.asyncAfter(deadline:.now()+1) { self.stopReceiving(); self.status="Receiver stopped after incorrect codes. Start again." }
                        }
                        return
                    }
                    guard packet.report.count<=128*1024 else { self.reply("SZ",on:connection,id:id); return }
                    guard let receive=self.onReport else { throw CocoaError(.fileWriteUnknown) }
                    try receive(packet.report)
                    self.status="Watch report received and saved. Use Copy, Share or Save below."
                    self.reply("OK",on:connection,id:id)
                } catch {
                    self.status="Report rejected or interrupted: " + self.describe(error)
                    self.reply("RJ",on:connection,id:id)
                }
            }
        }
    }
    private static func localIPv4() -> String? {
        #if os(iOS) || os(macOS)
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list)==0 else { return nil }
        defer { freeifaddrs(list) }
        var current=list
        var fallback: String?
        while let item=current {
            defer { current=item.pointee.ifa_next }
            guard let address=item.pointee.ifa_addr, address.pointee.sa_family==UInt8(AF_INET) else { continue }
            var host=[CChar](repeating:0,count:Int(NI_MAXHOST))
            guard getnameinfo(address,socklen_t(address.pointee.sa_len),&host,socklen_t(host.count),nil,0,NI_NUMERICHOST)==0 else { continue }
            let ip=String(cString:host)
            guard privateAddress(ip) else { continue }
            if String(cString:item.pointee.ifa_name)=="en0" { return ip }
            if fallback==nil { fallback=ip }
        }
        return fallback
        #else
        return nil
        #endif
    }
    private static func privateAddress(_ host: String) -> Bool {
        let parts=host.split(separator:".").compactMap { Int($0) }
        guard parts.count==4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        #if WATCHLINK_TRANSPORT_TESTS
        if parts[0]==127 { return true }
        #endif
        return parts[0]==10 || (parts[0]==172 && (16...31).contains(parts[1])) || (parts[0]==192 && parts[1]==168)
    }
    private func replyHTTP(_ statusCode: Int, _ text: String, connection: NWConnection, id: UUID) {
        let payload=Data(text.utf8)
        var response=Data("HTTP/1.1 \(statusCode) Result\r\nContent-Type: text/plain\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n".utf8)
        response.append(payload)
        connection.send(content:response,contentContext:.finalMessage,isComplete:true,completion:.contentProcessed { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline:.now()+1) { self?.finish(id) }
        })
    }
    private func readHTTPHeaders(_ connection: NWConnection, id: UUID, buffer: Data) {
        let end=Data("\r\n\r\n".utf8)
        if let marker=buffer.range(of:end) {
            guard marker.upperBound<=4096, let header=String(data:buffer[..<marker.lowerBound],encoding:.utf8) else { replyHTTP(400,"HD",connection:connection,id:id); return }
            let lines=header.components(separatedBy:"\r\n")
            guard let first=lines.first, first.hasPrefix("POST /report HTTP/1.") else { replyHTTP(404,"HD",connection:connection,id:id); return }
            var fields: [String:String]=[:]
            for line in lines.dropFirst() {
                guard let colon=line.firstIndex(of:":") else { replyHTTP(400,"HD",connection:connection,id:id); return }
                let name=line[..<colon].lowercased()
                guard fields[name]==nil else { replyHTTP(400,"HD",connection:connection,id:id); return }
                fields[name]=line[line.index(after:colon)...].trimmingCharacters(in:.whitespaces)
            }
            guard receiving, fields["x-watchlink-code"]==receiverCode else {
                rejectedCodes+=1; status="Incorrect or expired receiver code."
                replyHTTP(403,"PC",connection:connection,id:id)
                if rejectedCodes>=3 { DispatchQueue.main.asyncAfter(deadline:.now()+1) { self.stopReceiving(); self.status="Receiver stopped after incorrect codes." } }
                return
            }
            guard fields["transfer-encoding"]==nil, let length=fields["content-length"].flatMap(Int.init), length>0, length<=128*1024 else { replyHTTP(413,"SZ",connection:connection,id:id); return }
            let initial=Data(buffer[marker.upperBound...])
            guard initial.count<=length else { replyHTTP(400,"HD",connection:connection,id:id); return }
            if fields["expect"]?.lowercased()=="100-continue" {
                connection.send(content:Data("HTTP/1.1 100 Continue\r\n\r\n".utf8),completion:.contentProcessed { _ in })
            }
            status="Receiving HTTP report (\(length) bytes)…"
            readExactly(length,from:connection,accumulated:initial) { [weak self] result in
                guard let self else { return }
                do {
                    let data=try result.get()
                    guard let receive=self.onReport else { throw CocoaError(.fileWriteUnknown) }
                    try receive(data)
                    self.status="Watch report received and saved. Use Copy, Share or Save below."
                    self.replyHTTP(200,"OK",connection:connection,id:id)
                } catch { self.status="HTTP report rejected: " + self.describe(error); self.replyHTTP(400,"RJ",connection:connection,id:id) }
            }
            return
        }
        guard buffer.count<4096 else { replyHTTP(400,"HD",connection:connection,id:id); return }
        connection.receive(minimumIncompleteLength:1,maximumLength:4096-buffer.count) { [weak self] data,_,complete,error in
            guard let self else { return }
            guard error==nil, let data, !data.isEmpty else { self.status="HTTP header interrupted."; self.finish(id); return }
            var next=buffer; next.append(data)
            if complete, next.range(of:end)==nil { self.finish(id); return }
            self.readHTTPHeaders(connection,id:id,buffer:next)
        }
    }
    func sendHTTP(_ data: Data) {
        guard enteredCode.count==6, enteredCode.allSatisfy(\.isNumber) else { status="Enter the 6-digit iPhone receiver code."; return }
        let address=enteredAddress.trimmingCharacters(in:.whitespacesAndNewlines)
        guard var parts=URLComponents(string:address.hasPrefix("http://") ? address : "http://"+address),
              parts.scheme=="http", let host=parts.host, Self.privateAddress(host), let port=parts.port, (1024...65535).contains(port), parts.user==nil, parts.password==nil,
              !data.isEmpty, data.count<=128*1024 else { status="Enter the private IPv4 address:port shown on iPhone."; return }
        parts.path="/report"; parts.query=nil; parts.fragment=nil
        guard let url=parts.url else { status="Invalid receiver address."; return }
        httpRequestID=nil; httpTask?.cancel(); httpSession?.invalidateAndCancel()
        let token=UUID(); httpRequestID=token
        let config=URLSessionConfiguration.ephemeral
        config.allowsCellularAccess=false
        config.timeoutIntervalForRequest=45; config.timeoutIntervalForResource=60
        let client=URLSession(configuration:config); httpSession=client
        var request=URLRequest(url:url); request.httpMethod="POST"; request.httpBody=data
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue(String(data.count),forHTTPHeaderField:"Content-Length")
        request.setValue(enteredCode,forHTTPHeaderField:"X-WatchLink-Code")
        status="Sending HTTP report to iPhone…"
        let task=client.dataTask(with:request) { [weak self] body,response,error in
            DispatchQueue.main.async {
                guard let self, self.httpRequestID==token else { return }
                self.httpRequestID=nil
                if let error { self.status="HTTP transfer failed: " + self.describe(error) + ". Check address, Local Network permission and receiver expiry." }
                else if let http=response as? HTTPURLResponse, http.statusCode==200, body==Data("OK".utf8) { self.status="iPhone received and saved the Watch report." }
                else {
                    let code=(response as? HTTPURLResponse)?.statusCode ?? 0
                    self.status=code==403 ? "iPhone rejected the code. Enter its current code." : "iPhone rejected HTTP report (status \(code)). Check its message."
                }
                client.finishTasksAndInvalidate()
            }
        }
        httpTask=task; task.resume()
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
                        self.status="Report sent. Waiting for iPhone to save it…"
                        self.readExactly(2,from:connection) { [weak self] result in
                            guard let self else { return }
                            switch result {
                            case .success(let data):
                                let code=String(data:data,encoding:.utf8) ?? "??"
                                let messages=["OK":"iPhone received and saved the Watch report.", "PC":"iPhone rejected the receiver code. Enter the current code.", "RJ":"iPhone rejected the report. Check its error message.", "SZ":"Report is too large.", "HD":"iPhone rejected the transfer header."]
                                self.status=messages[code] ?? "Unknown receipt: " + code
                            case .failure(let error): self.status="Receipt interrupted: " + self.describe(error)
                            }
                            self.finish(id)
                        }
                    })
                case .waiting(let error): self.status="Waiting for local route: " + self.describe(error)
                case .failed(let error): self.status="Connection failed: " + self.describe(error); self.finish(id)
                default: break
                }
            }
            connection.start(queue:.main)
            DispatchQueue.main.asyncAfter(deadline:.now()+60) { [weak self] in
                guard let self, self.connections[id] != nil else { return }
                self.status="Local transfer timed out. Keep both apps open on the same Wi-Fi."; self.finish(id)
            }
        } catch { status="Cannot prepare local transfer: " + describe(error) }
    }
}
