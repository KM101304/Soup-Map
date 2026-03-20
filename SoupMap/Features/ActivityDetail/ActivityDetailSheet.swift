import SwiftUI

struct ActivityDetailSheet: View {
    let activity: Activity
    let isJoined: Bool
    let isHost: Bool
    let isExample: Bool
    let isAuthenticated: Bool
    let moderationService: ModerationService
    let onCreateFromExample: () -> Void
    let onRequireSignIn: () -> Void
    let onJoin: () async -> Void
    let onLeave: () async -> Void
    let onEnd: () async -> Void
    let onBlock: () async -> Void

    @State private var isWorking = false
    @State private var isShowingReport = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 14) {
                        detailRow(title: "Host", value: activity.hostDisplayName)
                        detailRow(title: "Starts", value: activity.startTime.shortClockLabel())
                        detailRow(title: "Ends", value: activity.endTime.shortClockLabel())
                        detailRow(title: "State", value: activity.state().title)
                        detailRow(title: "Participants", value: "\(activity.participantCount)")
                        if let capacity = activity.capacity {
                            detailRow(title: "Capacity", value: "\(capacity)")
                        }
                    }
                    .padding(18)
                    .soupGlass(cornerRadius: 24)

                    if activity.description.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(activity.description)
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    if activity.tags.isEmpty == false {
                        FlexibleTagWrap(tags: activity.tags)
                    }

                    actionSection
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(activity.categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingReport) {
                ReportActivityView(activity: activity, moderationService: moderationService)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(activity.categoryName, systemImage: activity.category.iconName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(activity.category.palette.text.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(activity.category.palette.fill.opacity(0.82), in: Capsule())

                if isExample {
                    Text("Example bubble")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.panelStrong, in: Capsule())
                }
            }

            Text(activity.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text(summaryText)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Task {
                    await handlePrimaryAction()
                }
            } label: {
                HStack {
                    if isWorking {
                        ProgressView()
                            .tint(.black.opacity(0.8))
                    }
                    Text(primaryActionTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.black.opacity(0.84))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(primaryActionColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(isWorking)

            HStack(spacing: 12) {
                Button {
                    if isAuthenticated {
                        isShowingReport = true
                    } else {
                        onRequireSignIn()
                    }
                } label: {
                    Text("Report")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(isAuthenticated == false || isExample)

                Button {
                    Task {
                        await onBlock()
                    }
                } label: {
                    Text("Block Host")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .disabled(isAuthenticated == false || isExample)
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private var summaryText: String {
        if isExample {
            return "This is a seeded example to keep the map alive while SoupMap grows."
        }
        return "\(activity.participantCount) people moving around \(activity.locationSummary)."
    }

    private var primaryActionTitle: String {
        if isExample {
            return "Start a Real Bubble"
        }
        if isAuthenticated == false {
            return "Sign In to Join"
        }
        if isHost {
            return "End Activity"
        }
        return isJoined ? "Leave Bubble" : "Join Bubble"
    }

    private var primaryActionColor: Color {
        if isHost {
            return Color(hex: "#FF8A73")
        }
        return Color(hex: "#65D1B6")
    }

    private func handlePrimaryAction() async {
        isWorking = true
        defer { isWorking = false }

        if isExample {
            onCreateFromExample()
            return
        }
        if isAuthenticated == false {
            onRequireSignIn()
            return
        }
        if isHost {
            await onEnd()
        } else if isJoined {
            await onLeave()
        } else {
            await onJoin()
        }
    }
}

private struct FlexibleTagWrap: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.panelStrong, in: Capsule())
                }
            }
        }
    }
}
