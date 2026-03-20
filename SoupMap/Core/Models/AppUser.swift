import Foundation

struct AppUser: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarURL: URL?
    let bio: String
    let interests: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case bio
        case interests
    }
}

struct ProfileUpdateInput: Equatable {
    var username: String
    var displayName: String
    var bio: String
    var interests: [String]
}
