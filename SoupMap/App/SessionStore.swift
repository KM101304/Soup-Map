import Foundation
import Supabase
import SwiftUI

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var currentSession: Session?
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isBootstrapping = true
    @Published var isShowingAuthSheet = false
    @Published var authErrorMessage: String?
    @Published var hasCompletedOnboarding: Bool

    private let authService: AuthService
    private let profileService: ProfileService
    private let configuration: AppConfiguration
    private let defaults: UserDefaults

    init(
        authService: AuthService,
        profileService: ProfileService,
        configuration: AppConfiguration,
        defaults: UserDefaults = .standard
    ) {
        self.authService = authService
        self.profileService = profileService
        self.configuration = configuration
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)
    }

    var isAuthenticated: Bool {
        currentSession != nil && currentUser != nil
    }

    func bootstrap() async {
        defer { isBootstrapping = false }
        await refreshSession()
    }

    func refreshSession() async {
        do {
            currentSession = try await authService.currentSession()
            if let userID = currentSession?.user.id {
                currentUser = try await profileService.fetchUser(id: userID)
            } else {
                currentUser = nil
            }
            authErrorMessage = nil
        } catch {
            currentSession = nil
            currentUser = nil
            authErrorMessage = error.localizedDescription
        }
    }

    func markOnboardingComplete() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
    }

    func requireAuthentication() {
        isShowingAuthSheet = true
    }

    func dismissAuthentication() {
        isShowingAuthSheet = false
    }

    func handleIncoming(url: URL) async {
        do {
            _ = try await authService.handleIncoming(url: url)
            await refreshSession()
            isShowingAuthSheet = false
        } catch {
            authErrorMessage = error.localizedDescription
            isShowingAuthSheet = true
        }
    }

    func finishNativeSignIn(
        idToken: String,
        nonce: String,
        profileHint: AppleProfileHint?
    ) async throws {
        _ = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
        await refreshSession()

        if
            let userID = currentSession?.user.id,
            let profileHint,
            let displayName = profileHint.displayName,
            !displayName.isEmpty
        {
            _ = try? await profileService.updateProfile(
                userID: userID,
                input: .init(
                    username: currentUser?.username ?? String(userID.uuidString.prefix(12)).lowercased(),
                    displayName: displayName,
                    bio: currentUser?.bio ?? "",
                    interests: currentUser?.interests ?? []
                )
            )
            await refreshSession()
        }

        isShowingAuthSheet = false
    }

    func sendMagicLink(to email: String) async throws {
        try await authService.sendMagicLink(to: email)
    }

    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            authErrorMessage = error.localizedDescription
        }
        currentSession = nil
        currentUser = nil
        isShowingAuthSheet = false
    }
}

private enum UserDefaultsKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
