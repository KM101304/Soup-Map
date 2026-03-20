import CoreLocation
import Foundation

enum ActivityState: String, CaseIterable, Codable {
    case upcoming
    case active
    case full
    case ended

    static func resolve(
        now: Date = .now,
        start: Date,
        end: Date,
        participantCount: Int,
        capacity: Int?
    ) -> ActivityState {
        if end <= now {
            return .ended
        }
        if let capacity, participantCount >= capacity {
            return .full
        }
        if start <= now {
            return .active
        }
        return .upcoming
    }

    var title: String {
        rawValue.capitalized
    }
}

struct Activity: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let latitude: Double
    let longitude: Double
    let startTime: Date
    let endTime: Date
    let capacity: Int?
    let participantCount: Int
    let isRemoved: Bool
    let hostID: UUID
    let hostUsername: String
    let hostDisplayName: String
    let hostAvatarURL: URL?
    let categoryID: UUID
    let categorySlug: String
    let categoryName: String
    let categoryAccentHex: String
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case latitude
        case longitude
        case startTime = "start_time"
        case endTime = "end_time"
        case capacity
        case participantCount = "participant_count"
        case isRemoved = "is_removed"
        case hostID = "host_id"
        case hostUsername = "host_username"
        case hostDisplayName = "host_display_name"
        case hostAvatarURL = "host_avatar_url"
        case categoryID = "category_id"
        case categorySlug = "category_slug"
        case categoryName = "category_name"
        case categoryAccentHex = "category_accent_hex"
        case tags
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var category: ActivityCategoryKind {
        ActivityCategoryKind(rawValue: categorySlug) ?? .social
    }

    func state(now: Date = .now) -> ActivityState {
        ActivityState.resolve(
            now: now,
            start: startTime,
            end: endTime,
            participantCount: participantCount,
            capacity: capacity
        )
    }

    var locationSummary: String {
        title
    }

    func withParticipantCount(_ participantCount: Int) -> Activity {
        Activity(
            id: id,
            title: title,
            description: description,
            latitude: latitude,
            longitude: longitude,
            startTime: startTime,
            endTime: endTime,
            capacity: capacity,
            participantCount: participantCount,
            isRemoved: isRemoved,
            hostID: hostID,
            hostUsername: hostUsername,
            hostDisplayName: hostDisplayName,
            hostAvatarURL: hostAvatarURL,
            categoryID: categoryID,
            categorySlug: categorySlug,
            categoryName: categoryName,
            categoryAccentHex: categoryAccentHex,
            tags: tags
        )
    }
}

struct JoinedActivityRecord: Codable {
    let activityID: UUID

    enum CodingKeys: String, CodingKey {
        case activityID = "activity_id"
    }
}

struct ActivityInsertRecord: Encodable {
    let title: String
    let description: String
    let categoryID: UUID
    let hostID: UUID
    let latitude: Double
    let longitude: Double
    let startTime: Date
    let endTime: Date
    let capacity: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case categoryID = "category_id"
        case hostID = "host_id"
        case latitude
        case longitude
        case startTime = "start_time"
        case endTime = "end_time"
        case capacity
    }
}

struct ActivityIDRecord: Decodable {
    let id: UUID
}
