import XCTest
@testable import FitQuest

final class GameMathTests: XCTestCase {
    func testLevelIsFloorSqrtOfXPOverFifty() {
        XCTAssertEqual(GameState(xp: 0).level, 0)
        XCTAssertEqual(GameState(xp: 50).level, 1)
        XCTAssertEqual(GameState(xp: 199).level, 1)
        XCTAssertEqual(GameState(xp: 200).level, 2)
        XCTAssertEqual(GameState(xp: 1_340).level, 5)
    }

    func testXPRequiredForALevelInvertsTheLevelFormula() {
        for level in 0...20 {
            let needed = GameState.xpRequired(forLevel: level)
            XCTAssertEqual(GameState(xp: needed).level, level)
            if level > 0 { XCTAssertEqual(GameState(xp: needed - 1).level, level - 1) }
        }
    }

    func testProgressTowardNextLevel() {
        // Level 5 starts at 1,250 XP and level 6 at 1,800.
        let game = GameState(xp: 1_340)
        XCTAssertEqual(game.xpToNextLevel, 460)
        XCTAssertEqual(game.progress, 90.0 / 550.0, accuracy: 0.0001)

        XCTAssertEqual(GameState(xp: 1_250).progress, 0)
        XCTAssertEqual(GameState(xp: 0).xpToNextLevel, 50)
    }
}
