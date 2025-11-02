import Foundation
import Combine
import Network

protocol NetworkStatusProviding {
    var isConnectedCurrent: Bool { get }
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
}

@MainActor
final class NetworkMonitor: ObservableObject, NetworkStatusProviding {
    @Published private(set) var isConnected: Bool = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "network-monitor")

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    var isConnectedCurrent: Bool { isConnected }

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        $isConnected.eraseToAnyPublisher()
    }
}
