import AuthenticationServices
import SwiftUI

struct AuthSheetView: View {
    @ObservedObject var environment: AppEnvironment
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Join the city layer.")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Sign in to create, join, report, and shape the bubbles moving across Vancouver.")
                                .font(.system(size: 17, weight: .medium, design: .serif))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        VStack(spacing: 16) {
                            SignInWithAppleButton(.signIn) { request in
                                viewModel.prepareAppleRequest(request)
                            } onCompletion: { result in
                                Task {
                                    await viewModel.handleAppleCompletion(result, sessionStore: sessionStore)
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Email magic link")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)

                                TextField("you@domain.com", text: $viewModel.email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .padding(16)
                                    .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(AppTheme.hairline, lineWidth: 1)
                                    )

                                Button {
                                    Task {
                                        await viewModel.sendMagicLink(sessionStore: sessionStore)
                                    }
                                } label: {
                                    HStack {
                                        if viewModel.isSendingMagicLink {
                                            ProgressView()
                                                .tint(.black.opacity(0.8))
                                        }
                                        Text("Send Sign-In Link")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(.black.opacity(0.84))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(hex: "#F8BA53"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .disabled(viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(18)
                            .soupGlass(cornerRadius: 24)

                            if let message = viewModel.infoMessage ?? sessionStore.authErrorMessage {
                                Text(message)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(AppTheme.danger)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        sessionStore.dismissAuthentication()
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var isSendingMagicLink = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private var currentNonce: String?

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = NonceGenerator.random()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>, sessionStore: SessionStore) async {
        do {
            guard
                case let .success(authorization) = result,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let currentNonce
            else {
                throw NSError(domain: "SoupMapAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign In failed before we received your token."])
            }

            let formatter = PersonNameComponentsFormatter()
            let displayName = credential.fullName.map(formatter.string(from:))?.trimmingCharacters(in: .whitespacesAndNewlines)
            try await sessionStore.finishNativeSignIn(
                idToken: idToken,
                nonce: currentNonce,
                profileHint: AppleProfileHint(
                    displayName: displayName?.isEmpty == true ? nil : displayName,
                    email: credential.email
                )
            )

            errorMessage = nil
            infoMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendMagicLink(sessionStore: SessionStore) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }

        isSendingMagicLink = true
        defer { isSendingMagicLink = false }

        do {
            try await sessionStore.sendMagicLink(to: trimmed)
            infoMessage = "Check your email for a secure sign-in link."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
