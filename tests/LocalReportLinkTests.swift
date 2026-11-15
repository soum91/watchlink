import Foundation
import Network

@main struct LocalReportLinkTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fputs("TCP test failed: \(message)\n",stderr); exit(1) }
    }
    static func wait(_ seconds: TimeInterval=8, until done: ()->Bool) {
        let end=Date().addingTimeInterval(seconds)
        while !done() && Date()<end { RunLoop.main.run(until:Date().addingTimeInterval(0.01)) }
        require(done(),"timed out")
    }
    static func pause() { RunLoop.main.run(until:Date().addingTimeInterval(1.1)) }
    static func main() throws {
        let server=LocalReportLink()
        var received: [Data]=[]
        server.onReport={ data in
            guard let json=try JSONSerialization.jsonObject(with:data) as? [String:Any], json["platform"] as? String == "watchOS" else { throw CocoaError(.fileReadCorruptFile) }
            received.append(data)
        }
        server.startReceiving()
        wait { server.receiving && server.testPort != nil }
        let port=server.testPort!
        let endpoint=NWEndpoint.hostPort(host:"127.0.0.1",port:port)
        let target=LocalReportLink.Receiver(id:"loopback",endpoint:endpoint)
        let payload=try JSONSerialization.data(withJSONObject:["app":"WatchLink","schema":1,"platform":"watchOS","padding":String(repeating:"x",count:65000)])
        let client=LocalReportLink(); client.enteredCode=server.receiverCode
        client.send(payload,to:target)
        wait { client.status=="iPhone received and saved the Watch report." }
        require(received==[payload],"large report must arrive exactly and once")
        pause()
        client.enteredCode=server.receiverCode=="000000" ? "000001" : "000000"
        client.send(payload,to:target)
        wait { client.status.contains("rejected the receiver code") }
        require(received.count==1,"wrong PIN must not import")
        pause()
        client.enteredCode=server.receiverCode
        client.send(Data("invalid JSON".utf8),to:target)
        wait { client.status.contains("rejected the report") }
        require(received.count==1,"invalid report must not import")
        pause()
        let packet=try JSONSerialization.data(withJSONObject:["code":server.receiverCode,"report":payload.base64EncodedString()])
        let length=UInt32(packet.count)
        var frame=Data("WLR1".utf8)
        frame.append(contentsOf:[UInt8((length>>24)&255),UInt8((length>>16)&255),UInt8((length>>8)&255),UInt8(length&255)])
        frame.append(packet)
        let chunks=[Data(frame.prefix(1)),Data(frame.dropFirst(1).prefix(2)),Data(frame.dropFirst(3).prefix(4)),Data(frame.dropFirst(7).prefix(20)),Data(frame.dropFirst(27))]
        let connection=NWConnection(to:endpoint,using:.tcp)
        var reply=Data(); var started=false
        func readReply() {
            connection.receive(minimumIncompleteLength:1,maximumLength:2-reply.count) { data,_,_,error in
                require(error==nil,"fragmented receipt error")
                require(data?.isEmpty == false,"empty or closed receipt")
                if let data { reply.append(data) }
                if reply.count<2 { readReply() }
            }
        }
        func sendChunk(_ index: Int) {
            guard index<chunks.count else { readReply(); return }
            connection.send(content:chunks[index],completion:.contentProcessed { error in
                require(error==nil,"fragment send error")
                DispatchQueue.main.asyncAfter(deadline:.now()+0.03) { sendChunk(index+1) }
            })
        }
        connection.stateUpdateHandler={ state in
            if case .ready=state, !started { started=true; sendChunk(0) }
        }
        connection.start(queue:.main)
        wait { reply.count==2 }
        require(reply==Data("OK".utf8),"fragmented frame must receive OK")
        require(received==[payload,payload],"split header and body must reconstruct exactly")
        connection.stateUpdateHandler=nil; connection.cancel()
        pause()
        let httpClient=LocalReportLink()
        httpClient.enteredAddress="127.0.0.1:\(port.rawValue)"
        httpClient.enteredCode=server.receiverCode
        httpClient.sendHTTP(payload)
        wait { httpClient.status=="iPhone received and saved the Watch report." }
        require(received==[payload,payload,payload],"URLSession HTTP must persist exact report")
        pause()
        httpClient.enteredCode=server.receiverCode=="000000" ? "000001" : "000000"
        httpClient.sendHTTP(payload)
        wait { httpClient.status.contains("rejected the code") }
        require(received.count==3,"HTTP wrong code must not persist")
        pause()
        httpClient.enteredCode=server.receiverCode
        httpClient.sendHTTP(Data("invalid JSON".utf8))
        wait { httpClient.status.contains("rejected HTTP report (status 400)") }
        require(received.count==3,"HTTP rejected import must not persist")
        httpClient.enteredAddress="10.0.0.1.example.com:\(port.rawValue)"
        httpClient.sendHTTP(payload)
        require(httpClient.status.contains("private IPv4"),"reject DNS names disguised as private IPv4")
        httpClient.enteredAddress="010.0.0.1:\(port.rawValue)"
        httpClient.sendHTTP(payload)
        require(httpClient.status.contains("private IPv4"),"reject noncanonical/octal address")
        server.stopReceiving()
        print("Real TCP tests passed: 65KB report, wrong PIN, rejected import, fragmented header/body, URLSession HTTP, HTTP rejection and acknowledged receipt.")
    }
}
