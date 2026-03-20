import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class MapViewModel: ObservableObject {
    @Published private(set) var activities: [Activity] = []
    @Published private(set) var joinedActivityIDs: Set<UUID> = []
    @Published private(set) var blockedUserIDs: Set<UUID> = []
    @Published var selectedActivity: Activity?
    @Published var selectedClusterActivities: [Activity] = []
    @Published var isShowingClusterSheet = false
    @Published var isShowingCreate = false
    @Published var isShowingProfile = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var cameraZoom = AppConstants.defaultBubbleZoom
    @Published private var ripplingIDs: Set<UUID> = []

    private let activityService: ActivityService
    private let moderationService: ModerationService
    private let exampleActivityIDs: Set<UUID>
    private let exampleActivities: [Activity]
    private var hasStartedObservation = false
    private var lastUserID: UUID?

    init(activityService: ActivityService, moderationService: ModerationService) {
        self.activityService = activityService
        self.moderationService = moderationService
        self.exampleActivities = ExampleActivityFactory.make()
        self.exampleActivityIDs = Set(exampleActivities.map(\.id))
    }

    var visibleActivities: [Activity] {
        let filtered = activities.filter { blockedUserIDs.contains($0.hostID) == false }
        return filtered.isEmpty ? exampleActivities : filtered
    }

    var bubbleNodes: [ActivityBubbleNode] {
        BubbleEngine.nodes(
            from: visibleActivities,
            joinedActivityIDs: joinedActivityIDs,
            ripplingIDs: ripplingIDs,
            zoom: cameraZoom
        )
    }

    var isShowingExamples: Bool {
        activities.filter { blockedUserIDs.contains($0.hostID) == false }.isEmpty
    }

    func load(for userID: UUID?) async {
        isLoading = true
        lastUserID = userID
        defer { isLoading = false }

        do {
            let fetchedActivities = try await activityService.fetchActivities()
            activities = fetchedActivities

            if let userID {
                async let joined = activityService.fetchJoinedActivityIDs(userID: userID)
                async let blocked = moderationService.fetchBlockedUserIDs(for: userID)
                joinedActivityIDs = try await joined
                blockedUserIDs = try await blocked
            } else {
                joinedActivityIDs = []
                blockedUserIDs = []
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        startRealtimeObservationIfNeeded()
    }

    func reload(for userID: UUID?) async {
        await load(for: userID)
    }

    func openCreate(sessionStore: SessionStore) {
        if sessionStore.isAuthenticated {
            isShowingCreate = true
        } else {
            sessionStore.requireAuthentication()
        }
    }

    func openProfile(sessionStore: SessionStore) {
        if sessionStore.isAuthenticated {
            isShowingProfile = true
        } else {
            sessionStore.requireAuthentication()
        }
    }

    func handleTap(on node: ActivityBubbleNode) {
        switch node.kind {
        case let .activity(activity):
            selectedActivity = activity
        case let .cluster(activities):
            selectedClusterActivities = activities.sorted { lhs, rhs in
                lhs.participantCount > rhs.participantCount
            }
            isShowingClusterSheet = true
        }
    }

    func join(activity: Activity, sessionStore: SessionStore, notificationManager: NotificationManager) async {
        guard let userID = sessionStore.currentUser?.id else {
            sessionStore.requireAuthentication()
            return
        }
        guard exampleActivityIDs.contains(activity.id) == false else {
            isShowingCreate = true
            return
        }

        joinedActivityIDs.insert(activity.id)
        incrementParticipants(for: activity.id, delta: 1)
        triggerRipple(for: activity.id)

        do {
            try await activityService.joinActivity(activityID: activity.id, userID: userID)
            if notificationManager.authorizationStatus == .authorized {
                await notificationManager.scheduleReminder(for: activity)
            }
        } catch {
            joinedActivityIDs.remove(activity.id)
            incrementParticipants(for: activity.id, delta: -1)
            errorMessage = error.localizedDescription
        }
    }

    func leave(activity: Activity, sessionStore: SessionStore) async {
        guard let userID = sessionStore.currentUser?.id else { return }
        guard exampleActivityIDs.contains(activity.id) == false else { return }

        joinedActivityIDs.remove(activity.id)
        incrementParticipants(for: activity.id, delta: -1)

        do {
            try await activityService.leaveActivity(activityID: activity.id, userID: userID)
        } catch {
            joinedActivityIDs.insert(activity.id)
            incrementParticipants(for: activity.id, delta: 1)
            errorMessage = error.localizedDescription
        }
    }

    func end(activity: Activity) async {
        do {
            try await activityService.endActivity(activityID: activity.id)
            activities.removeAll { $0.id == activity.id }
            selectedActivity = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func blockHost(of activity: Activity, sessionStore: SessionStore) async {
        guard let userID = sessionStore.currentUser?.id else {
            sessionStore.requireAuthentication()
            return
        }

        do {
            try await moderationService.block(userID: activity.hostID, by: userID)
            blockedUserIDs.insert(activity.hostID)
            activities.removeAll { $0.hostID == activity.hostID }
            selectedActivity = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isJoined(_ activity: Activity) -> Bool {
        joinedActivityIDs.contains(activity.id)
    }

    func isExample(_ activity: Activity) -> Bool {
        exampleActivityIDs.contains(activity.id)
    }

    func isHost(_ activity: Activity, currentUserID: UUID?) -> Bool {
        activity.hostID == currentUserID
    }

    private func startRealtimeObservationIfNeeded() {
        guard hasStartedObservation == false else { return }
        hasStartedObservation = true

        activityService.observeFeedChanges { [weak self] in
            guard let self else { return }
            Task {
                await self.load(for: self.lastUserID)
            }
        }
    }

    private func triggerRipple(for activityID: UUID) {
        ripplingIDs.insert(activityID)
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                ripplingIDs.remove(activityID)
            }
        }
    }

    private func incrementParticipants(for activityID: UUID, delta: Int) {
        activities = activities.map { activity in
            guard activity.id == activityID else { return activity }
            return activity.withParticipantCount(max(1, activity.participantCount + delta))
        }

        if let selectedActivity, selectedActivity.id == activityID {
            self.selectedActivity = selectedActivity.withParticipantCount(max(1, selectedActivity.participantCount + delta))
        }
    }
}

private enum ExampleActivityFactory {
    static func make() -> [Activity] {
        [
            Activity(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                title: "Coding at Breka",
                description: "Example bubble showing how a small coding crew looks on SoupMap.",
                latitude: 49.2806,
                longitude: -123.1308,
                startTime: Date().addingTimeInterval(-30 * 60),
                endTime: Date().addingTimeInterval(90 * 60),
                capacity: 6,
                participantCount: 3,
                isRemoved: false,
                hostID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                hostUsername: "demo_builder",
                hostDisplayName: "Demo Builder",
                hostAvatarURL: nil,
                categoryID: UUID(uuidString: "10101010-1010-1010-1010-101010101010")!,
                categorySlug: "coding",
                categoryName: "Coding",
                categoryAccentHex: "#65D1B6",
                tags: ["Coffee", "Founders"]
            ),
            Activity(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                title: "Studying at UBC",
                description: "Example bubble to keep the city layer legible before network density arrives.",
                latitude: 49.2606,
                longitude: -123.2459,
                startTime: Date().addingTimeInterval(-15 * 60),
                endTime: Date().addingTimeInterval(120 * 60),
                capacity: 8,
                participantCount: 5,
                isRemoved: false,
                hostID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                hostUsername: "demo_student",
                hostDisplayName: "Demo Student",
                hostAvatarURL: nil,
                categoryID: UUID(uuidString: "20202020-2020-2020-2020-202020202020")!,
                categorySlug: "study",
                categoryName: "Study",
                categoryAccentHex: "#70A8FF",
                tags: ["UBC", "Deep Work"]
            ),
            Activity(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                title: "Coworking in Mount Pleasant",
                description: "Example bubble showing a meaningful one-to-few work session.",
                latitude: 49.2635,
                longitude: -123.1017,
                startTime: Date().addingTimeInterval(20 * 60),
                endTime: Date().addingTimeInterval(140 * 60),
                capacity: 4,
                participantCount: 2,
                isRemoved: false,
                hostID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
                hostUsername: "demo_operator",
                hostDisplayName: "Demo Operator",
                hostAvatarURL: nil,
                categoryID: UUID(uuidString: "30303030-3030-3030-3030-303030303030")!,
                categorySlug: "work",
                categoryName: "Work",
                categoryAccentHex: "#F8BA53",
                tags: ["Coworking"]
            )
        ]
    }
}
