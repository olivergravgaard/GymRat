import Foundation
import Combine

@MainActor
final class AuthFormStore: ObservableObject {
    enum Mode {
        case login
        case register
    }
    
    enum FieldError: Equatable {
        case message(String)
    }
    
    @Published var mode: Mode = .login
    @Published var email: String = ""
    @Published var username: String = ""
    @Published var firstname: String = ""
    @Published var lastname: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    
    @Published var emailError: FieldError?
    @Published var usernameError: FieldError?
    @Published var firstnameError: FieldError?
    @Published var lastnameError: FieldError?
    @Published var passwordError: FieldError?
    @Published var confirmPasswordError: FieldError?
    @Published var generalError: FieldError?
    
    @Published var isSubmitting: Bool = false
    
    private let authStore: AuthStore
    
    init (authStore: AuthStore) {
        self.authStore = authStore
    }
    
    private func validateEmail () -> Bool {
        emailError = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            emailError = .message("Email can not be empty.")
            return false
        }
        
        guard trimmed.contains("@"), trimmed.contains(".") else {
            emailError = .message("Please type a valid email.")
            return false
        }
        
        return true
    }
    
    private func validateUsername() -> Bool {
        guard mode == .register else { return true }
        
        usernameError = nil
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 3 else {
            usernameError = .message("Username must contain atleast 3 characters.")
            return false
        }

        let pattern = "^[A-Za-z0-9._-]{3,}$"
        if trimmed.range(of: pattern, options: .regularExpression) == nil {
            usernameError = .message("Username must only contain: 'A-Z, 0-9, .-_'.")
            return false
        }

        return true
    }
    
    private func validateFirstname () -> Bool {
        firstnameError = nil
        
        guard mode == .register else { return true }
        
        let trimmed = firstname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            firstnameError = .message("Please enter your firstname.")
            return false
        }
        
        guard trimmed.count >= 2 else {
            firstnameError = .message("Your firstname must be atleast 2 characters long.")
            return false
        }
        
        return true
    }
    
    private func validateLastname () -> Bool {
        lastnameError = nil
        
        guard mode == .register else { return true }
        
        let trimmed = lastname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastnameError = .message("Please enter your lastname.")
            return false
        }
        
        guard trimmed.count >= 2 else {
            lastnameError = .message("Your lastname must be atleast 2 characters long.")
            return false
        }
        
        return true
    }
    
    private func validatePassword() -> Bool {
        passwordError = nil

        guard !password.isEmpty else {
            passwordError = .message("Please enter password.")
            return false
        }

        guard password.count >= 8 else {
            passwordError = .message("Password must be atleast 8 characters.")
            return false
        }

        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        guard hasUppercase else {
            passwordError = .message("Password must contain atleast 1 capital letter.")
            return false
        }

        return true
    }

    private func validateConfirmPassword() -> Bool {
        confirmPasswordError = nil

        guard mode == .register else { return true }

        guard !confirmPassword.isEmpty else {
            confirmPasswordError = .message("Please repeat your password.")
            return false
        }

        guard confirmPassword == password else {
            confirmPasswordError = .message("Passwords does not match.")
            return false
        }

        return true
    }
    
    var canSubmit: Bool {
        switch mode {
        case .login:
            return !email.isEmpty && !password.isEmpty && !isSubmitting
        case .register:
            return !email.isEmpty &&
                    !username.isEmpty &&
                    !firstname.isEmpty &&
                    !lastname.isEmpty &&
                    !password.isEmpty &&
                    !confirmPassword.isEmpty &&
                    !isSubmitting
        }
    }
    
    func toggleMode () {
        mode = (mode == .login ? .register : .login)
        generalError = nil
        
        emailError = nil
        usernameError = nil
        firstnameError = nil
        lastnameError = nil
        passwordError = nil
        confirmPasswordError = nil
    }
    
    func submit () async {
        generalError = nil
        
        guard validateEmail(),
                validateUsername(),
                validateFirstname(),
                validateLastname(),
                validatePassword(),
                validateConfirmPassword()
        else { return }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        switch mode {
        case .login:
            await authStore.login(email: email, password: password)
            
            if let error = authStore.errorMessage {
                generalError = .message(error)
            }
        case .register:
            await authStore.register(email: email, password: password, username: username, firstname: firstname, lastname: lastname)
            
            if let error = authStore.errorMessage {
                generalError = .message(error)
            }
        }
    }
}
