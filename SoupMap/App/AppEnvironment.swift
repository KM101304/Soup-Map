import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    let configuration: AppConfiguration
    let supabaseService: SupabaseService
    let authService: AuthService
    let profileService: ProfileService
    let activityService: ActivityService
    let moderationService: ModerationService
    let locationManager: LocationManager
    let notificationManager: NotificationManager
    let sessionStore: SessionStore

    init() {
        let configuration = AppConfiguration()
        let supabaseService = SupabaseService(configuration: configuration)
        let authService = AuthService(supabaseService: supabaseService, configuration: configuration)
        let profileService = ProfileService(supabaseService: supabaseService)
        let activityService = ActivityService(supabaseService: supabaseService)
        let moderationService = ModerationService(supabaseService: supabaseService)
        let locationManager = LocationManager()
        let notificationManager = NotificationManager()
        let sessionStore = SessionStore(
            authService: authService,
            profileService: profileService,
            configuration: configuration
        )

        self.configuration = configuration
        self.supabaseService = supabaseService
        self.authService = authService
        self.profileService = profileService
        self.activityService = activityService
        self.moderationService = moderationService
        self.locationManager = locationManager
        self.notificationManager = notificationManager
        self.sessionStore = sessionStore
    }
}
