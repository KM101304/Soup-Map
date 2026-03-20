import XCTest
@testable import SoupMap

final class BubbleEngineTests: XCTestCase {
    func testBubbleRadiusGrowsNonLinearly() {
        let one = BubbleEngine.radius(for: 1)
        let four = BubbleEngine.radius(for: 4)
        let sixteen = BubbleEngine.radius(for: 16)

        XCTAssertGreaterThan(four, one)
        XCTAssertGreaterThan(sixteen, four)
        XCTAssertLessThan(sixteen - four, 40)
    }

    func testActivityStateResolvesEndedBeforeFull() {
        let now = Date()
        let state = ActivityState.resolve(
            now: now,
            start: now.addingTimeInterval(-3600),
            end: now.addingTimeInterval(-60),
            participantCount: 8,
            capacity: 8
        )

        XCTAssertEqual(state, .ended)
    }
}
