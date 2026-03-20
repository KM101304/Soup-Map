import CoreLocation
import Foundation

struct ActivityDraft {
    var title = ""
    var description = ""
    var category: ActivityCategoryKind = .coding
    var coordinate = AppConstants.vancouverCenter
    var startTime = Date().addingTimeInterval(10 * 60)
    var endTime = Date().addingTimeInterval(90 * 60)
    var tags: [String] = ["Coffee"]
    var capacity: Int?

    var normalizedTags: [String] {
        Array(
            Set(
                tags
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty == false }
            )
        )
        .sorted()
    }
}
