import SwiftUI

enum ActivityCategoryKind: String, CaseIterable, Codable, Identifiable {
    case coding
    case study
    case work
    case fitness
    case creative
    case social

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .study: "book.closed"
        case .work: "briefcase"
        case .fitness: "figure.run"
        case .creative: "paintbrush"
        case .social: "person.3"
        }
    }

    var palette: BubblePalette {
        switch self {
        case .coding:
            BubblePalette(fill: Color(hex: "#65D1B6"), halo: Color(hex: "#1B8072"), text: .white)
        case .study:
            BubblePalette(fill: Color(hex: "#70A8FF"), halo: Color(hex: "#2E5FAE"), text: .white)
        case .work:
            BubblePalette(fill: Color(hex: "#F8BA53"), halo: Color(hex: "#A6701E"), text: .black.opacity(0.8))
        case .fitness:
            BubblePalette(fill: Color(hex: "#7FD76B"), halo: Color(hex: "#3E7F34"), text: .black.opacity(0.8))
        case .creative:
            BubblePalette(fill: Color(hex: "#FF8A73"), halo: Color(hex: "#AD4E3C"), text: .white)
        case .social:
            BubblePalette(fill: Color(hex: "#F58AC8"), halo: Color(hex: "#9D4A7D"), text: .white)
        }
    }
}
