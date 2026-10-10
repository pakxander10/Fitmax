import XCTest
@testable import FitQuest

final class GameMathTests: XCTestCase {
    // feature_game.md A3
    func testRankThresholdsMatchSpec() {
        let cases: [(Int, HunterRank)] = [
            (0, .e), (499, .e), (500, .d), (1_499, .d), (1_500, .c),
            (3_499, .c), (3_500, .b), (7_000, .a), (12_000, .s),
        ]
        for (xp, rank) in cases {
            XCTAssertEqual(HunterRank.forXP(xp), rank, "xp \(xp)")
        }
    }

    func testLevelIsFloorSqrtOfXPOverFifty() {
        XCTAssertEqual(GameState(xp: 0).level, 0)
        XCTAssertEqual(GameState(xp: 50).level, 1)
        XCTAssertEqual(GameState(xp: 199).level, 1)
        XCTAssertEqual(GameState(xp: 200).level, 2)
        XCTAssertEqual(GameState(xp: 1_340).level, 5)
    }

    func testProgressTowardNextRank() {
        let game = GameState(xp: 1_340)
        XCTAssertEqual(game.rank, .d)
        XCTAssertEqual(game.nextRank, .c)
        XCTAssertEqual(game.xpToNext, 160)
        XCTAssertEqual(game.progress, 0.84, accuracy: 0.0001)
    }

    func testTopRankHasNoNextRank() {
        let game = GameState(xp: 20_000)
        XCTAssertEqual(game.rank, .s)
        XCTAssertNil(game.nextRank)
        XCTAssertEqual(game.xpToNext, 0)
        XCTAssertEqual(game.progress, 1)
    }
}
