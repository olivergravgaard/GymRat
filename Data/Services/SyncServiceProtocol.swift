import Foundation
import Combine
import FirebaseFirestore

@MainActor
protocol SyncServiceProtocol: AnyObject, ObservableObject {
    var db: Firestore { get }
    var debounceInterval: Int { get }
    var debounceTask: Task<Void, Never>? { get set }
    
    func pullRemote (userId: String) async throws
    func pushRemote (userId: String) async throws
}

extension SyncServiceProtocol {
    func notifyDomainChange (userId: String) {
        debounceTask?.cancel()
        
        debounceTask = Task { [debounceInterval] in
            try? await Task.sleep(for: .seconds(debounceInterval))
            
            try? await self.pushRemote(userId: userId)
        }
    }
    
    func cancelPendingSync() {
        debounceTask?.cancel()
        debounceTask = nil
    }
}
