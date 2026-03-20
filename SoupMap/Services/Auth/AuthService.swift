import Foundation
import Supabase

struct AppleProfileHint {
    let displayName: String?
    let email: String?
}

final class AuthService {
    private let supabaseService: SupabaseService
    private let configuration: AppConfiguration

    init(supabaseService: SupabaseService, configuration: AppConfiguration) {
        self.supabaseService = supabaseService
        self.configuration = configuration
    }

    func currentSession() async throws -> Session? {
        try? await supabaseService.client.auth.session
    }

    @discardableResult
    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        try await supabaseService.client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
    }

    func sendMagicLink(to email: String) async throws {
        try await supabaseService.client.auth.signInWithOTP(
            email: email,
            redirectTo: configuration.authCallbackURL
        )
    }

    @discardableResult
    func handleIncoming(url: URL) async throws -> Session {
        try await supabaseService.client.auth.session(from: url)
    }

    func signOut() async throws {
        try await supabaseService.client.auth.signOut()
    }
}
