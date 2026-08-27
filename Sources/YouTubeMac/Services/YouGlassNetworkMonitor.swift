import Foundation
import Network

final class YouGlassNetworkMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.kevinhowe.YouGlass.network-monitor", qos: .utility)
    private let onStatusChange: @Sendable (Bool) -> Void

    init(onStatusChange: @escaping @Sendable (Bool) -> Void) {
        self.onStatusChange = onStatusChange
    }

    func start() {
        monitor.pathUpdateHandler = { [onStatusChange] path in
            onStatusChange(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
