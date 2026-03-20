import Foundation

final class ModerationService {
    private let supabaseService: SupabaseService

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    func fetchBlockedUserIDs(for blockerID: UUID) async throws -> Set<UUID> {
        struct BlockRecord: Decodable {
            let blockedUserID: UUID

            enum CodingKeys: String, CodingKey {
                case blockedUserID = "blocked_user_id"
            }
        }

        let blocks: [BlockRecord] = try await supabaseService.client
            .from("blocks")
            .select("blocked_user_id")
            .eq("blocker_id", value: blockerID)
            .execute()
            .value

        return Set(blocks.map(\.blockedUserID))
    }

    func block(userID blockedUserID: UUID, by blockerID: UUID) async throws {
        struct BlockInsertRecord: Encodable {
            let blockerID: UUID
            let blockedUserID: UUID

            enum CodingKeys: String, CodingKey {
                case blockerID = "blocker_id"
                case blockedUserID = "blocked_user_id"
            }
        }

        _ = try await supabaseService.client
            .from("blocks")
            .insert(BlockInsertRecord(blockerID: blockerID, blockedUserID: blockedUserID))
            .execute()
    }

    func reportActivity(
        activityID: UUID,
        reportedUserID: UUID,
        reporterID: UUID,
        reason: ReportReason,
        notes: String
    ) async throws {
        struct ReportInsertRecord: Encodable {
            let reporterID: UUID
            let activityID: UUID
            let reportedUserID: UUID
            let reason: String
            let notes: String

            enum CodingKeys: String, CodingKey {
                case reporterID = "reporter_id"
                case activityID = "activity_id"
                case reportedUserID = "reported_user_id"
                case reason
                case notes
            }
        }

        _ = try await supabaseService.client
            .from("reports")
            .insert(
                ReportInsertRecord(
                    reporterID: reporterID,
                    activityID: activityID,
                    reportedUserID: reportedUserID,
                    reason: reason.rawValue,
                    notes: notes
                )
            )
            .execute()
    }
}
