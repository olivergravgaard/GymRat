import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import Combine

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private lazy var db = Firestore.firestore()
    
    init () {
        self.user = Auth.auth().currentUser
        
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            
            Task { @MainActor in
                self.user = user
            }
        }
    }
    
    func login (email: String, password: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await signIn(email: email, password: password)
        }catch {
            handleAuthError(error)
        }
    }
    
    func register (
        email: String,
        password: String,
        username: String,
        firstname: String,
        lastname: String
    ) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            let taken = try await isUsernameTaken(username)
            if taken {
                errorMessage = "Username is already taken."
                return
            }
            
            let result = try await createUser(email: email, password: password)
            
            let uid = result.user.uid
            try await db.collection("users").document(uid).setData([
                "username": username,
                "email": email,
                "firstname": firstname,
                "lastname": lastname,
                "createdAt": FieldValue.serverTimestamp()
            ])
        }catch {
            handleAuthError(error)
        }
    }
    
    func logout () {
        do {
            try Auth.auth().signOut()
            user = nil
        }catch {
            handleAuthError(error)
        }
    }
    
    func validateSessionIfNeeded () async {
        guard let authUser = user else { return }
        await validateSession(for: authUser)
    }
    
    func validateSession (for authUser: User) async {
        do {
            try await reloadUser(authUser)
            
            let doc = try await db.collection("users").document(authUser.uid).getDocument()
            if !doc.exists {
                try Auth.auth().signOut()
                self.user = nil
            }
        }catch {
            if let nsError = error as NSError?,
               let code = AuthErrorCode(rawValue: nsError.code) {
                switch code {
                case .userNotFound, .userDisabled:
                    try? Auth.auth().signOut()
                    self.user = nil
                    
                case .networkError:
                    print("Validate session: network error, keeping user localy.")
                    
                default:
                    print("Validate session: other auth error: \(nsError)")
                }
            }else {
                print("Validate session: generic error \(error)")
            }
        }
    }
    
    private func reloadUser (_ user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.reload { error in
                if let error = error {
                    continuation.resume(throwing: error)
                }else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func handleAuthError(_ error: Error) {
        if let nsError = error as NSError?,
           let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .emailAlreadyInUse:
                errorMessage = "Der findes allerede en bruger med denne email."
            case .invalidEmail:
                errorMessage = "Email-adressen er ikke gyldig."
            case .weakPassword:
                errorMessage = "Password er for svagt."
            case .wrongPassword:
                errorMessage = "Forkert password."
            case .userNotFound:
                errorMessage = "Der findes ingen bruger med denne email."
            default:
                errorMessage = nsError.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }
    
    private func isUsernameTaken(_ username: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            db.collection("users")
                .whereField("username", isEqualTo: username)
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    }else if let snapshot = snapshot {
                        continuation.resume(returning: !snapshot.documents.isEmpty)
                    }else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
        }
    }
    
    private func createUser (email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                }else if let result = result {
                    continuation.resume(returning: result)
                }else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
        }
    }
    
    private func signIn (email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    print(error.localizedDescription)
                    continuation.resume(throwing: error)
                }else if let result = result {
                    print("Logged in!")
                    continuation.resume(returning: result)
                }else {
                    print("Bad error")
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
        }
    }
}
