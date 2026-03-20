import Foundation
import Supabase

struct TagRecord: Codable, Hashable {
    let id: UUID
    let slug: String
    let name: String
}

struct TagInsertRecord: Encodable {
    let slug: String
    let name: String
}

final class ProfileService {
    private let supabaseService: SupabaseService

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    func fetchUser(id: UUID) async throws -> AppUser {
        try await supabaseService.client
            .from("users")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func updateProfile(userID: UUID, input: ProfileUpdateInput, avatarURL: URL? = nil) async throws -> AppUser {
        struct ProfileUpdateRecord: Encodable {
            let username: String
            let displayName: String
            let avatarURL: String?
            let bio: String
            let interests: [String]

            enum CodingKeys: String, CodingKey {
                case username
                case displayName = "display_name"
                case avatarURL = "avatar_url"
                case bio
                case interests
            }
        }

        return try await supabaseService.client
            .from("users")
            .update(
                ProfileUpdateRecord(
                    username: input.username.lowercased(),
                    displayName: input.displayName,
                    avatarURL: avatarURL?.absoluteString,
                    bio: input.bio,
                    interests: input.interests
                )
            )
            .eq("id", value: userID)
            .select()
            .single()
            .execute()
            .value
    }

    func uploadAvatar(data: Data, userID: UUID) async throws -> URL {
        let path = "\(userID.uuidString)/avatar.jpg"
        _ = try await supabaseService.client.storage
            .from("avatars")
            .upload(
                path: path,
                file: data,
                options: FileOptions(
                    contentType: "image/jpeg",
                    upsert: true
                )
            )

        return try supabaseService.client.storage
            .from("avatars")
            .getPublicURL(path: path)
    }
}
