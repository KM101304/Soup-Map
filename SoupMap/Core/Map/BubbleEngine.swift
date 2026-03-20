import CoreLocation
import SwiftUI

struct ActivityBubbleNode: Identifiable {
    enum Kind {
        case activity(Activity)
        case cluster([Activity])
    }

    let id: String
    let kind: Kind
    let coordinate: CLLocationCoordinate2D
    let radius: CGFloat
    let participantCount: Int
    let palette: BubblePalette
    let isJoined: Bool
    let isRippling: Bool
}

enum BubbleEngine {
    static func radius(for participantCount: Int) -> CGFloat {
        min(88, 26 + sqrt(CGFloat(max(1, participantCount))) * 16)
    }

    static func nodes(
        from activities: [Activity],
        joinedActivityIDs: Set<UUID>,
        ripplingIDs: Set<UUID>,
        zoom: Double
    ) -> [ActivityBubbleNode] {
        let groups = clusterActivities(activities, zoom: zoom)
        return groups.map { group in
            if group.count == 1, let activity = group.first {
                return ActivityBubbleNode(
                    id: activity.id.uuidString,
                    kind: .activity(activity),
                    coordinate: activity.coordinate,
                    radius: radius(for: activity.participantCount),
                    participantCount: activity.participantCount,
                    palette: activity.category.palette,
                    isJoined: joinedActivityIDs.contains(activity.id),
                    isRippling: ripplingIDs.contains(activity.id)
                )
            }

            let participantCount = group.reduce(0) { $0 + $1.participantCount }
            let categories = group.map(\.category)
            let primaryCategory = categories
                .reduce(into: [:]) { partialResult, category in
                    partialResult[category, default: 0] += 1
                }
                .max(by: { $0.value < $1.value })?.key ?? .social

            return ActivityBubbleNode(
                id: "cluster-\(group.map(\.id.uuidString).joined(separator: "-"))",
                kind: .cluster(group),
                coordinate: centroid(for: group),
                radius: radius(for: participantCount) + 10,
                participantCount: participantCount,
                palette: primaryCategory.palette,
                isJoined: group.contains(where: { joinedActivityIDs.contains($0.id) }),
                isRippling: false
            )
        }
    }

    private static func clusterActivities(_ activities: [Activity], zoom: Double) -> [[Activity]] {
        let threshold = clusteringThreshold(zoom: zoom)
        var unassigned = activities.sorted { lhs, rhs in
            lhs.participantCount > rhs.participantCount
        }
        var groups: [[Activity]] = []

        while let seed = unassigned.first {
            unassigned.removeFirst()
            var group = [seed]
            var didMerge = true

            while didMerge {
                didMerge = false
                let center = centroid(for: group)

                for index in stride(from: unassigned.count - 1, through: 0, by: -1) {
                    let candidate = unassigned[index]
                    let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                        .distance(from: CLLocation(latitude: candidate.latitude, longitude: candidate.longitude))

                    if distance <= threshold {
                        group.append(candidate)
                        unassigned.remove(at: index)
                        didMerge = true
                    }
                }
            }

            groups.append(group)
        }

        return groups
    }

    private static func centroid(for activities: [Activity]) -> CLLocationCoordinate2D {
        let latitude = activities.map(\.latitude).reduce(0, +) / Double(activities.count)
        let longitude = activities.map(\.longitude).reduce(0, +) / Double(activities.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func clusteringThreshold(zoom: Double) -> CLLocationDistance {
        switch zoom {
        case ..<11:
            280
        case ..<13:
            190
        case ..<14.5:
            120
        default:
            70
        }
    }
}
