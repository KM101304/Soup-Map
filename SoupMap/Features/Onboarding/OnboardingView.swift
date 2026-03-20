import SwiftUI

struct OnboardingView: View {
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var notificationManager: NotificationManager

    @State private var selection = 0

    private let pages = [
        OnboardingPage(
            title: "See the city simmer.",
            subtitle: "SoupMap turns Vancouver into a live layer of bubbles so momentum is visible, not hidden.",
            accent: Color(hex: "#65D1B6"),
            systemImage: "drop.circle"
        ),
        OnboardingPage(
            title: "Join real activity in one tap.",
            subtitle: "Tiny gatherings still feel meaningful. The moment people join, bubbles grow and the map responds.",
            accent: Color(hex: "#70A8FF"),
            systemImage: "person.3.sequence"
        ),
        OnboardingPage(
            title: "Private enough to feel safe.",
            subtitle: "Permissions are contextual, reporting is built in, and you can block people who do not belong in your city layer.",
            accent: Color(hex: "#FF8A73"),
            systemImage: "hand.raised"
        )
    ]

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 28) {
                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: 430)

                VStack(spacing: 14) {
                    PermissionStatusRow(
                        title: "Location",
                        subtitle: locationSubtitle,
                        actionTitle: "Allow",
                        isComplete: locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
                    ) {
                        locationManager.requestWhenInUse()
                    }

                    PermissionStatusRow(
                        title: "Notifications",
                        subtitle: notificationSubtitle,
                        actionTitle: "Enable",
                        isComplete: notificationManager.authorizationStatus == .authorized
                    ) {
                        Task {
                            await notificationManager.requestAuthorization()
                        }
                    }
                }
                .padding(20)
                .soupGlass()

                VStack(spacing: 12) {
                    Button {
                        sessionStore.markOnboardingComplete()
                    } label: {
                        Text("Explore Vancouver")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "#65D1B6"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    Button {
                        sessionStore.markOnboardingComplete()
                        sessionStore.requireAuthentication()
                    } label: {
                        Text("Sign In to Join")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(page.accent.opacity(0.18))
                    .frame(width: 220, height: 220)
                    .blur(radius: 18)

                Circle()
                    .fill(page.accent.opacity(0.35))
                    .frame(width: 162, height: 162)

                Image(systemName: page.systemImage)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Text(page.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(page.subtitle)
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(28)
        .soupGlass(cornerRadius: 32)
    }

    private var locationSubtitle: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            "Ready to center the map around you."
        case .denied, .restricted:
            "You can still browse Vancouver without it."
        default:
            "Used to center the map and place your activity."
        }
    }

    private var notificationSubtitle: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            "Activity reminders are on."
        case .denied:
            "You can still use SoupMap without reminders."
        default:
            "Optional reminders for joined activities."
        }
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let accent: Color
    let systemImage: String
}

private struct PermissionStatusRow: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            if isComplete {
                Label("On", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.success)
            } else {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white, in: Capsule())
            }
        }
    }
}
