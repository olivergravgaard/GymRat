import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private let authStore: AuthStore
    
    init (authStore: AuthStore) {
        self.authStore = authStore
        
        if let user = authStore.user {
            startListening(for: user.uid)
        }
        
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            
            Task { @MainActor in
                self.handleAuthChange(user: user)
            }
        }
    }
    
    deinit {
        listener?.remove()
    }
    
    private func handleAuthChange (user: User?) {
        listener?.remove()
        listener = nil
        profile = nil
        errorMessage = nil
        
        guard let user = user else {
            return
        }
        
        startListening(for: user.uid)
    }
    
    private func startListening (for uid: String) {
        isLoading = true
        errorMessage = nil
        
        listener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                
                Task { @MainActor in
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let snapshot = snapshot, snapshot.exists, let profile = Profile(doc: snapshot) else {
                        self.profile = nil
                        return
                    }
                    
                    self.profile = profile
                }
            }
    }
}
