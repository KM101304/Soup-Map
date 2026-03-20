import Foundation

enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "Spam"
    case unsafe = "Unsafe"
    case harassment = "Harassment"
    case misleading = "Misleading"
    case other = "Other"

    var id: String { rawValue }
}
