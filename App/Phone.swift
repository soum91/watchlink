import SwiftUI
import UIKit

@main struct WatchLinkPhone: App {
    @StateObject private var model = WatchLinkModel()
    @State private var exporting = false
    @State private var sharing = false
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Section {
                        Label("WatchLink", systemImage: "applewatch").font(.title2.bold())
                        Text("Pairing access research").foregroundStyle(.secondary)
                        Text("Installed version: \(watchLinkVersion)").font(.caption.monospaced())
                    }
                    Section("Scan") {
                        Toggle("Probe protected paths", isOn: $model.protectedAccess).disabled(model.running)
                        Text("Checks pairing-storage candidates. Protected probing temporarily changes the dedicated App Group cache link and restores it. Pairing records and MobileGestalt are never changed.").font(.footnote)
                        Button(model.running ? "Scanning…" : "Run access scan") { model.scan() }.disabled(model.running)
                        Text(model.status).font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Watch") {
                        Text("Install the signed Watch app on the currently paired Watch. Run its scan, then tap Send report. Sileo installs the iPhone companion only.").font(.footnote)
                        Text("Phone switching and a second native pairing are not implemented.").font(.footnote).foregroundStyle(.orange)
                    }
                    Section("Report") {
                        HStack {
                            Button("Copy") { UIPasteboard.general.string = model.report; model.status = "Report copied." }
                            Spacer(); Button("Share") { sharing = true }
                            Spacer(); Button("Save") { exporting = true }
                        }
                        Text(model.report).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                .navigationTitle("WatchLink")
                .fileExporter(isPresented: $exporting, document: ReportDocument(text: model.report), contentType: .json,
                    defaultFilename: "WatchLink-report") { result in
                    model.status = (try? result.get()) == nil ? "Export cancelled or failed." : "Report exported."
                }
                .sheet(isPresented: $sharing) { ReportShare(text: model.report) }
            }.tint(.cyan)
        }
    }
}

struct ReportShare: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
