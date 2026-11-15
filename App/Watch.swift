import SwiftUI

@main struct WatchLinkWatch: App {
    @StateObject private var model = WatchLinkModel()
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("WatchLink", systemImage: "applewatch").font(.headline)
                        Text("\(watchLinkVersion) · research probe").font(.caption2)
                        Text("No pairing changes. Phone switching is not implemented.").font(.caption2).foregroundStyle(.orange)
                        Toggle("Protected access", isOn: $model.protectedAccess).disabled(model.running)
                        Text("Needs a dedicated App Group. Only the group's temporary cache link is changed.").font(.caption2)
                        Button(model.running ? "Scanning…" : "Run scan") { model.scan() }.disabled(model.running)
                        Button("Send report") { model.sendReport() }.disabled(model.running)
                        ShareLink(item: model.report, subject: Text("WatchLink Watch report")) {
                            Label("Share report text", systemImage: "square.and.arrow.up")
                        }.disabled(!model.hasReport || model.running)
                        ShareLink(item: WatchLinkModel.textReportURL) {
                            Label("Share report file", systemImage: "doc")
                        }.disabled(!model.hasReport || model.running)
                        Text("On iPhone, tap Get Watch report. Send report finds nearby iPhone receivers automatically.").font(.caption2)
                        Button("Check connection") { model.refreshConnection() }
                        Text(model.status).font(.caption2)
                        Text(model.transferDetails).font(.caption2)
                        NavigationLink("Compact summary") {
                            ScrollView { Text(model.compactSummary).font(.system(size: 11, design: .monospaced)).padding() }
                        }
                        NavigationLink("Nearby iPhones") {
                            NearbyPhoneSender(link: model.bluetoothLink, model: model)
                        }
                        NavigationLink("Read report") {
                            ScrollView { Text(model.report).font(.system(size: 10, design: .monospaced)).padding() }
                        }
                    }.padding()
                }
            }
            .sheet(isPresented: $model.showDirectSender) {
                NearbyPhoneSender(link: model.bluetoothLink, model: model)
            }.tint(.cyan)
        }
    }
}

struct LocalWatchSender: View {
    @ObservedObject var link: LocalReportLink
    @ObservedObject var model: WatchLinkModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Start Wi-Fi receiver in the iPhone app first.").font(.caption2)
                TextField("iPhone address:port", text: $link.enteredAddress)
                TextField("6-digit iPhone code", text: $link.enteredCode)
                Button("Send report over HTTP") { model.sendHTTPReport() }
                Text("Use the address shown on iPhone. No Watch Connectivity or receiver discovery is required.").font(.caption2)
                Text(link.status).font(.caption2)

            }.padding()
        }
    }
}

struct NearbyPhoneSender: View {
    @ObservedObject var link: BluetoothReportLink
    @ObservedObject var model: WatchLinkModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nearby iPhones").font(.headline)
                Text("Tap Get Watch report on iPhone. Choose the matching receiver name here.").font(.caption2)
                if link.scanning || link.sending { ProgressView() }
                ForEach(link.receivers) { receiver in
                    Button(receiver.name) { link.send(to: receiver.id) }.disabled(link.sending)
                }
                if !link.sending {
                    Button("Find iPhone") { link.startScanning() }
                } else {
                    Button("Cancel transfer") { link.stopSending(); link.status = "Transfer cancelled." }
                }
                Text(link.status).font(.caption2)
                Text("The last successful receiver is selected automatically next time.").font(.caption2)
                NavigationLink("Manual Wi-Fi fallback") {
                    LocalWatchSender(link: model.localLink, model: model)
                }
            }.padding()
        }
        .onAppear { link.startScanning() }
        .onDisappear { link.stopScanning() }
    }
}
