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
                        Text(model.status).font(.caption2)
                        NavigationLink("Read report") {
                            ScrollView { Text(model.report).font(.system(size: 10, design: .monospaced)).padding() }
                        }
                    }.padding()
                }
            }.tint(.cyan)
        }
    }
}
