import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: Profile?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
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
    
    func updateAvatar (with data: Data) async {
        guard let user = authStore.user else {
            print("updateAvatar: no authenticated users.")
            return
        }
        
        let uid = user.uid
        
        do {
            try AvatarCache.saveAvatar(data, for: uid)
            
            let filename = "avatar_\(uid).jpg"
            try await db.collection("users")
                .document(uid)
                .updateData([
                    "avatarFilename": filename
                ])
            
            print("Avatar updated (local only)")
        }catch {
            print("Failed to save avatar locally")
            self.errorMessage = "Failed to save avatar locally"
        }
    }
}

enum AvatarCache {
    static func avatarURL (for uid: String) -> URL {
        let filename = "avatar_\(uid).jpg"
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }
    
    static func saveAvatar (_ data: Data, for uid: String) throws {
        let url = avatarURL(for: uid)
        try data.write(to: url, options: [.atomic])
    }
    
    static func loadAvatar (for uid: String) -> UIImage? {
        let url = avatarURL(for: uid)
        return UIImage(contentsOfFile: url.path)
    }
    
    static func deleteAvatar (for uid: String) {
        let url = avatarURL(for: uid)
        try? FileManager.default.removeItem(at: url)
    }
}
