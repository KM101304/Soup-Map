import Foundation
import Supabase

final class ActivityService {
    private let supabaseService: SupabaseService
    private var realtimeTask: Task<Void, Never>?

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    func fetchActivities() async throws -> [Activity] {
        try await supabaseService.client
            .from("activity_feed")
            .select()
            .gt("end_time", value: ISO8601DateFormatter().string(from: Date()))
            .gte("latitude", value: AppConstants.vancouverLatitudeRange.lowerBound)
            .lte("latitude", value: AppConstants.vancouverLatitudeRange.upperBound)
            .gte("longitude", value: AppConstants.vancouverLongitudeRange.lowerBound)
            .lte("longitude", value: AppConstants.vancouverLongitudeRange.upperBound)
            .order("start_time")
            .limit(200)
            .execute()
            .value
    }

    func fetchJoinedActivityIDs(userID: UUID) async throws -> Set<UUID> {
        let records: [JoinedActivityRecord] = try await supabaseService.client
            .from("activity_participants")
            .select("activity_id")
            .eq("user_id", value: userID)
            .execute()
            .value

        return Set(records.map(\.activityID))
    }

    func createActivity(draft: ActivityDraft, hostID: UUID) async throws {
        let categoryID = try await resolveCategoryID(for: draft.category)

        let record = ActivityInsertRecord(
            title: draft.title,
            description: draft.description,
            categoryID: categoryID,
            hostID: hostID,
            latitude: draft.coordinate.latitude,
            longitude: draft.coordinate.longitude,
            startTime: draft.startTime,
            endTime: draft.endTime,
            capacity: draft.capacity
        )

        let inserted: ActivityIDRecord = try await supabaseService.client
            .from("activities")
            .insert(record)
            .select("id")
            .single()
            .execute()
            .value

        try await syncTags(draft.normalizedTags, activityID: inserted.id)
    }

    func joinActivity(activityID: UUID, userID: UUID) async throws {
        struct ParticipantInsertRecord: Encodable {
            let activityID: UUID
            let userID: UUID

            enum CodingKeys: String, CodingKey {
                case activityID = "activity_id"
                case userID = "user_id"
            }
        }

        _ = try await supabaseService.client
            .from("activity_participants")
            .insert(ParticipantInsertRecord(activityID: activityID, userID: userID))
            .execute()
    }

    func leaveActivity(activityID: UUID, userID: UUID) async throws {
        _ = try await supabaseService.client
            .from("activity_participants")
            .delete()
            .eq("activity_id", value: activityID)
            .eq("user_id", value: userID)
            .execute()
    }

    func endActivity(activityID: UUID) async throws {
        struct ActivityEndRecord: Encodable {
            let endTime: Date

            enum CodingKeys: String, CodingKey {
                case endTime = "end_time"
            }
        }

        _ = try await supabaseService.client
            .from("activities")
            .update(ActivityEndRecord(endTime: .now))
            .eq("id", value: activityID)
            .execute()
    }

    func observeFeedChanges(_ onChange: @escaping @MainActor () -> Void) {
        realtimeTask?.cancel()
        realtimeTask = Task {
            let channel = supabaseService.client.channel("activity-feed")

            async let activitiesChanges: Void = consume(
                stream: channel.postgresChange(AnyAction.self, schema: "public", table: "activities"),
                onChange: onChange
            )
            async let participantsChanges: Void = consume(
                stream: channel.postgresChange(AnyAction.self, schema: "public", table: "activity_participants"),
                onChange: onChange
            )
            async let tagsChanges: Void = consume(
                stream: channel.postgresChange(AnyAction.self, schema: "public", table: "activity_tags"),
                onChange: onChange
            )
            async let blocksChanges: Void = consume(
                stream: channel.postgresChange(AnyAction.self, schema: "public", table: "blocks"),
                onChange: onChange
            )

            await channel.subscribe()
            _ = await (activitiesChanges, participantsChanges, tagsChanges, blocksChanges)
        }
    }

    func stopObserving() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    private func resolveCategoryID(for category: ActivityCategoryKind) async throws -> UUID {
        struct CategoryRecord: Codable {
            let id: UUID
        }

        let record: CategoryRecord = try await supabaseService.client
            .from("categories")
            .select("id")
            .eq("slug", value: category.rawValue)
            .single()
            .execute()
            .value

        return record.id
    }

    private func syncTags(_ tags: [String], activityID: UUID) async throws {
        guard tags.isEmpty == false else { return }

        let normalized = tags.map { tag in
            tag
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
        }

        let existing: [TagRecord] = try await supabaseService.client
            .from("tags")
            .select()
            .in("slug", values: normalized)
            .execute()
            .value

        let existingSlugs = Set(existing.map(\.slug))
        let missing = normalized
            .filter { existingSlugs.contains($0) == false }
            .map { slug in
                TagInsertRecord(
                    slug: slug,
                    name: slug.replacingOccurrences(of: "-", with: " ").capitalized
                )
            }

        if missing.isEmpty == false {
            _ = try await supabaseService.client
                .from("tags")
                .insert(missing)
                .execute()
        }

        let synced: [TagRecord] = try await supabaseService.client
            .from("tags")
            .select()
            .in("slug", values: normalized)
            .execute()
            .value

        struct ActivityTagInsertRecord: Encodable {
            let activityID: UUID
            let tagID: UUID

            enum CodingKeys: String, CodingKey {
                case activityID = "activity_id"
                case tagID = "tag_id"
            }
        }

        let records = synced.map { tag in
            ActivityTagInsertRecord(activityID: activityID, tagID: tag.id)
        }

        _ = try await supabaseService.client
            .from("activity_tags")
            .insert(records)
            .execute()
    }

    private func consume(
        stream: AsyncStream<AnyAction>,
        onChange: @escaping @MainActor () -> Void
    ) async {
        for await _ in stream {
            if Task.isCancelled { return }
            await onChange()
        }
    }
}
