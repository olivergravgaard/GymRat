import SwiftUI

struct AuthView: View {
    @ObservedObject var authFormStore: AuthFormStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(authFormStore.mode == .login ? "Welcome back" : "Create account")
                        .font(.system(size: 32, weight: .bold))
                    Text("GymRat")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Card
                VStack(spacing: 20) {
                    modeToggle

                    Group {
                        if authFormStore.mode == .register {
                            nameFields
                        }
                        emailField
                        if authFormStore.mode == .register {
                            usernameField
                        }
                        passwordField
                        if authFormStore.mode == .register {
                            confirmPasswordField
                        }
                    }

                    if let error = authFormStore.generalError {
                        Text("\(error)")
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }

                    submitButton
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.9))
                        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 16)

                Spacer()
            }
        }
    }

    // MARK: - Subviews

    private var modeToggle: some View {
        HStack(spacing: 4) {
            modePill(title: "Log ind", isActive: authFormStore.mode == .login) {
                if authFormStore.mode != .login {
                    authFormStore.toggleMode()
                }
            }
            modePill(title: "Registrer", isActive: authFormStore.mode == .register) {
                if authFormStore.mode != .register {
                    authFormStore.toggleMode()
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    private func modePill(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isActive ? Color.accentColor : .clear)
                )
                .foregroundColor(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var nameFields: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Fornavn", text: $authFormStore.firstname)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemGray6))
                        )

                    if case let .message(msg)? = authFormStore.firstnameError {
                        Text(msg)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Efternavn", text: $authFormStore.lastname)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemGray6))
                        )

                    if case let .message(msg)? = authFormStore.lastnameError {
                        Text(msg)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Email", text: $authFormStore.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray6))
                )

            if case let .message(msg)? = authFormStore.emailError {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Username", text: $authFormStore.username)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray6))
                )

            if case let .message(msg)? = authFormStore.usernameError {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField("Password", text: $authFormStore.password)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray6))
                )

            if case let .message(msg)? = authFormStore.passwordError {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

    private var confirmPasswordField: some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField("Confirm password", text: $authFormStore.confirmPassword)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray6))
                )

            if case let .message(msg)? = authFormStore.confirmPasswordError {
                Text(msg)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

    private var submitButton: some View {
        Button {
            Task {
                await authFormStore.submit()
            }
        } label: {
            HStack {
                if authFormStore.isSubmitting {
                    ProgressView()
                } else {
                    Text(authFormStore.mode == .login ? "Log ind" : "Opret konto")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .disabled(!authFormStore.canSubmit)
    }
}
