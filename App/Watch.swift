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
                        Text("For copy: share to Messages, then copy on iPhone. Or use Get Watch report in the iPhone app.").font(.caption2)
                        Button("Check connection") { model.refreshConnection() }
                        Text(model.status).font(.caption2)
                        Text(model.transferDetails).font(.caption2)
                        NavigationLink("Compact summary") {
                            ScrollView { Text(model.compactSummary).font(.system(size: 11, design: .monospaced)).padding() }
                        }
                        NavigationLink("Wi-Fi report transfer") {
                            LocalWatchSender(link: model.localLink, model: model)
                        }
                        NavigationLink("Read report") {
                            ScrollView { Text(model.report).font(.system(size: 10, design: .monospaced)).padding() }
                        }
                    }.padding()
                }
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
                TextField("6-digit iPhone code", text: $link.enteredCode)
                Button("Find iPhone receiver") { link.findReceivers() }
                ForEach(link.receivers) { receiver in
                    Button("Send to " + receiver.id) { model.sendLocalReport(to: receiver) }
                }
                Text(link.status).font(.caption2)
                Button("Stop searching") { link.stopSearching() }
            }.padding()
        }
    }
}
