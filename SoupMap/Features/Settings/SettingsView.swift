import SwiftUI

struct SettingsView: View {
    @ObservedObject var environment: AppEnvironment
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingPrivacy = false

    var body: some View {
        List {
            Section("Permissions") {
                Button("Enable location") {
                    environment.locationManager.requestWhenInUse()
                }
                Button("Enable notifications") {
                    Task {
                        await environment.notificationManager.requestAuthorization()
                    }
                }
            }

            Section("Privacy") {
                Button("View privacy policy") {
                    isShowingPrivacy = true
                }
            }

            Section("Account") {
                Button(role: .destructive) {
                    Task {
                        await sessionStore.signOut()
                        dismiss()
                    }
                } label: {
                    Text("Sign out")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingPrivacy) {
            PrivacyPolicyView()
        }
    }
}
