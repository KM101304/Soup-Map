import SwiftUI

struct RootView: View {
    @ObservedObject var environment: AppEnvironment
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.isBootstrapping {
                SplashView()
            } else if sessionStore.hasCompletedOnboarding == false {
                OnboardingView(
                    sessionStore: sessionStore,
                    locationManager: environment.locationManager,
                    notificationManager: environment.notificationManager
                )
            } else {
                MapScreen(environment: environment)
            }
        }
        .task {
            if sessionStore.isBootstrapping {
                await sessionStore.bootstrap()
            }
        }
        .sheet(isPresented: $sessionStore.isShowingAuthSheet) {
            AuthSheetView(environment: environment)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
