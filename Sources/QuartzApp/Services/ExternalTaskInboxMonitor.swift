import QuartzKit
import Foundation

@MainActor
final class ExternalTaskInboxMonitor: NSObject {
    private let inbox: ExternalTaskInbox
    private var timer: Timer?
    private var handler: ((ExternalTaskRequest) throws -> Void)?
    private var isPolling = false

    init(inbox: ExternalTaskInbox = ExternalTaskInbox()) {
        self.inbox = inbox
    }

    func start(handler: @escaping (ExternalTaskRequest) throws -> Void) {
        self.handler = handler
        poll()

        guard timer == nil else { return }
        let timer = Timer(
            timeInterval: 0.75,
            target: self,
            selector: #selector(timerDidFire),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func timerDidFire() {
        poll()
    }

    private func poll() {
        guard !isPolling, let handler else { return }
        isPolling = true
        defer { isPolling = false }

        let pendingFiles: [URL]
        do {
            pendingFiles = try inbox.pendingFiles()
        } catch {
            NSLog("Quartz : impossible de lire la boîte de réception locale : %@", error.localizedDescription)
            return
        }

        for fileURL in pendingFiles {
            do {
                let request = try inbox.decode(fileURL)
                _ = try request.makeTask()
                try handler(request)
                try inbox.markProcessed(fileURL)
            } catch {
                NSLog(
                    "Quartz : requête externe rejetée (%@) : %@",
                    fileURL.lastPathComponent,
                    error.localizedDescription
                )
                try? inbox.reject(fileURL)
            }
        }
    }
}
