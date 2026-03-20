import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    policySection(
                        title: "What we collect",
                        body: "Account identifiers, profile information you provide, activities you create or join, optional location data, and moderation actions like reports or blocks."
                    )
                    policySection(
                        title: "Why we collect it",
                        body: "SoupMap needs this data to render live activity bubbles, let people coordinate safely, and give you control over your presence in the app."
                    )
                    policySection(
                        title: "What we do not do",
                        body: "SoupMap does not sell personal data, does not require always-on background location, and does not use ad tracking for the MVP."
                    )
                    policySection(
                        title: "Your controls",
                        body: "You can edit your profile, leave activities, block users, report activities, and revoke system permissions in Settings."
                    )
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text(body)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .soupGlass(cornerRadius: 24)
    }
}
