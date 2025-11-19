import Foundation
import Network
import Combine

final class ConnectivtyMonitor: ObservableObject {
    @Published private(set) var isOnline: Bool = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitorQueue")
    
    init () {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = (path.status == .satisfied)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
