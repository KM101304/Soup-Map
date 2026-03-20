import MapboxMaps
import SwiftUI

@main
struct SoupMapApp: App {
    @StateObject private var environment = AppEnvironment()

    init() {
        let configuration = AppConfiguration()
        MapboxOptions.accessToken = configuration.mapboxAccessToken
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .preferredColorScheme(.dark)
                .environmentObject(environment.sessionStore)
                .onOpenURL { url in
                    Task {
                        await environment.sessionStore.handleIncoming(url: url)
                    }
                }
        }
    }
}
