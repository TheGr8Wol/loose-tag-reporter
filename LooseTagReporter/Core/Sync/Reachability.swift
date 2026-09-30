import Foundation
import Network
import TagReportingCore

final class Reachability: ReachabilityProviding, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.example.loosetagreporter.reachability")
    private let lock = NSLock()
    private var _status: ReachabilityStatus = .offline

    /// Fired on every status change (including first path). Used to trigger sync on reconnect.
    var onStatusChange: ((ReachabilityStatus) -> Void)?

    var status: ReachabilityStatus {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _status
        }
    }

    func startMonitoring() async {
        // Seed from current path so launch sync is not stuck offline (A4-L-007).
        apply(path: monitor.currentPath, notify: false)

        monitor.pathUpdateHandler = { [weak self] path in
            self?.apply(path: path, notify: true)
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() async {
        monitor.cancel()
    }

    private func apply(path: NWPath, notify: Bool) {
        let next: ReachabilityStatus = path.status == .satisfied ? .online : .offline
        lock.lock()
        let previous = _status
        _status = next
        let handler = onStatusChange
        lock.unlock()
        if notify, previous != next {
            handler?(next)
        }
    }
}
