import SwiftUI
import UIKit

@main struct WatchLinkPhone: App {
    @StateObject private var model = WatchLinkModel()
    @State private var exportRequest: ReportExportRequest?
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
                        Button(model.running ? "Scanning…" : "Run access scan") { model.scan() }
                            .disabled(model.running).accessibilityIdentifier("scan.run")
                        Text(model.status).font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Watch") {
                        Button("Get Watch report") { model.requestWatchReport() }
                        Button("Show saved Watch report") { model.showReceivedWatchReport() }
                        Button("Check companion connection") { model.refreshConnection() }
                        Text(model.transferDetails).font(.footnote).textSelection(.enabled)
                        Text("Install the signed Watch app on the currently paired Watch. Run its scan, then tap Send report. Sileo installs the iPhone companion only.").font(.footnote)
                        Text("Phone switching and a second native pairing are not implemented.").font(.footnote).foregroundStyle(.orange)
                    }
                    Section("Direct Watch report transfer") {
                        LocalReceiverView(link: model.localLink)
                    }
                    Section("Report") {
                        Text(model.reportSource).font(.footnote.bold()).accessibilityIdentifier("report.origin")
                        HStack {
                            Button("Copy") {
                                if let error = DWCopyReport(model.report) { model.status = error }
                                else { model.status = "Report copied." }
                            }.accessibilityIdentifier("report.copy")
                            Spacer()
                            Button("Share") { present(.share) }.accessibilityIdentifier("report.share")
                            Spacer()
                            Button("Save") { present(.save) }.accessibilityIdentifier("report.save")
                        }
                        // Automatic List-row button behavior can activate all three actions.
                        .buttonStyle(.borderless)
                        .disabled(model.running || exportRequest != nil)
                        Text(model.status).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("report.status")
                        Text(model.report).font(.caption.monospaced()).textSelection(.enabled)
                            .accessibilityIdentifier("report.payload")
                    }
                }
                .navigationTitle("WatchLink")
                // One presentation state: Share and Save cannot present concurrently.
                .sheet(item: $exportRequest, onDismiss: {
                    if model.status.hasPrefix("Choose ") { model.status = "Export dismissed." }
                }) { request in
                    ReportExporter(request: request) { message in
                        model.status = message
                        exportRequest = nil
                    }
                }
            }.tint(.cyan)
        }
    }
    private func present(_ kind: ReportExportRequest.Kind) {
        guard exportRequest == nil else { return }
        do {
            exportRequest = try ReportExportRequest.make(kind: kind, text: model.report)
            model.status = kind == .save ? "Choose where to save the report." : "Choose how to share the report."
        } catch {
            model.status = "Could not prepare the report file. Run a scan and retry."
        }
    }
}

struct ReportExportRequest: Identifiable {
    enum Kind: Equatable { case save, share }
    let id: UUID
    let kind: Kind
    let fileURL: URL
    static func make(kind: Kind, text: String) throws -> ReportExportRequest {
        let data = Data(text.utf8)
        guard data.count <= 128 * 1024,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["app"] as? String == "WatchLink" else { throw CocoaError(.fileReadCorruptFile) }
        let id = UUID()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchLinkExports", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let source = json["platform"] as? String == "watchOS" ? "Watch" : "iPhone"
        let fileURL = directory.appendingPathComponent("WatchLink-" + source + "-report.json")
        // Export the displayed report snapshot, including a received Watch report.
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        return ReportExportRequest(id: id, kind: kind, fileURL: fileURL)
    }
}

struct ReportExporter: UIViewControllerRepresentable {
    let request: ReportExportRequest
    let completion: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIViewController {
        if request.kind == .save, let picker = DWMakeReportExporter(request.fileURL) as? UIDocumentPickerViewController {
            picker.delegate = context.coordinator
            picker.view.accessibilityIdentifier = "report.exportSheet"
            return picker
        }
        if request.kind == .share, let share = DWMakeReportSharer(request.fileURL) as? UIActivityViewController {
            share.view.accessibilityIdentifier = "report.shareSheet"
            share.completionWithItemsHandler = { _, completed, _, error in
                context.coordinator.finish(error != nil ? "Report sharing failed." : (completed ? "Report shared." : "Sharing cancelled."))
            }
            if let popover = share.popoverPresentationController {
                popover.sourceView = share.view
                popover.sourceRect = CGRect(x: share.view.bounds.midX, y: share.view.bounds.midY, width: 1, height: 1)
                popover.permittedArrowDirections = []
            }
            return share
        }
        // An unsupported document/clipboard service must leave a usable app.
        let fallback = UIViewController()
        fallback.view.backgroundColor = .systemBackground
        fallback.view.accessibilityIdentifier = "report.exportFailed"
        let label = UILabel()
        label.text = "The export service is unavailable in this installation. Close this sheet and try another report action."
        label.numberOfLines = 0
        let close = UIButton(type: .system)
        close.setTitle("Close", for: .normal)
        close.addTarget(context.coordinator, action: #selector(Coordinator.close), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [label, close])
        stack.axis = .vertical; stack.spacing = 24; stack.translatesAutoresizingMaskIntoConstraints = false
        fallback.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: fallback.view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: fallback.view.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: fallback.view.centerYAnchor)
        ])
        return fallback
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (String) -> Void
        private var finished = false
        init(completion: @escaping (String) -> Void) { self.completion = completion }
        func finish(_ message: String) {
            guard !finished else { return }; finished = true
            DispatchQueue.main.async { self.completion(message) }
        }
        @objc func close() { finish("Export service unavailable. Try another report action.") }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            finish(urls.isEmpty ? "No export destination selected." : "Report exported.")
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish("Export cancelled.") }
    }
}

struct LocalReceiverView: View {
    @ObservedObject var link: LocalReportLink
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Start Wi-Fi receiver") { link.startReceiving() }
            if link.receiving {
                Text(link.receiverName).font(.caption.monospaced())
                Text("Code: " + link.receiverCode).font(.title2.monospaced())
                Button("Stop receiver") { link.stopReceiving() }
            }
            Text(link.status).font(.footnote)
            Text("On Watch: Wi-Fi report transfer → Find iPhone receiver. Enter this code and choose the matching name. Keep both apps open on the same Wi-Fi. Allow Local Network access.").font(.footnote)
        }
    }
}
