//
//  CampaignModelsTests.swift
//  AI GMTests
//

import XCTest
@testable import AI_GM

final class CampaignModelsTests: XCTestCase {

    private let check = AbilityCheck(stat: .strength, roll: 14, modifier: 2, difficulty: 12)

    // MARK: - Summaries

    func testCheckSummaryShowsFullCalculation() {
        let outcome = RoundOutcome(playerId: "p1", playerName: "Jack", check: check, hpChange: 0, reason: nil)

        XCTAssertEqual(outcome.checkSummary, "Jack 擲 14 + STR 2 = 16，難度 12")
    }

    func testHPSummaryShowsLossWithReason() {
        let outcome = RoundOutcome(playerId: "p1", playerName: "Jack", check: nil, hpChange: -3, reason: "被哥布林砍中")

        XCTAssertEqual(outcome.hpSummary, "Jack −3 HP（被哥布林砍中）")
    }

    func testHPSummaryShowsGainWithoutReason() {
        let outcome = RoundOutcome(playerId: "p1", playerName: "Jack", check: nil, hpChange: 5, reason: nil)

        XCTAssertEqual(outcome.hpSummary, "Jack +5 HP")
    }

    func testSummariesAreOmittedWhenThereIsNothingToShow() {
        let outcome = RoundOutcome(playerId: "p1", playerName: "Jack", check: nil, hpChange: 0, reason: "沒事")

        XCTAssertNil(outcome.checkSummary)
        XCTAssertNil(outcome.hpSummary)
    }

    // MARK: - Firestore data

    func testOutcomeWithCheckSurvivesFirestoreRoundTrip() {
        let outcome = RoundOutcome(playerId: "p1", playerName: "Jack", check: check, hpChange: -3, reason: "被砍中")

        XCTAssertEqual(RoundOutcome(firestoreData: outcome.firestoreData), outcome)
    }

    func testOutcomeWithoutCheckSurvivesFirestoreRoundTrip() {
        let outcome = RoundOutcome(playerId: "p1", playerName: "Jack", check: nil, hpChange: 4, reason: nil)

        XCTAssertEqual(RoundOutcome(firestoreData: outcome.firestoreData), outcome)
    }

    func testOutcomeWithoutPlayerIsRejected() {
        XCTAssertNil(RoundOutcome(firestoreData: ["hpChange": -3]))
    }

    func testOutcomeWithUnknownStatKeepsHPButDropsCheck() {
        let data: [String: Any] = [
            "playerId": "p1",
            "playerName": "Jack",
            "hpChange": -3,
            "check": ["stat": "LUCK", "roll": 14, "modifier": 2, "difficulty": 12]
        ]

        let outcome = RoundOutcome(firestoreData: data)

        XCTAssertEqual(outcome?.hpChange, -3)
        XCTAssertNil(outcome?.check)
    }

    // MARK: - HP stored on the room

    private func makePlayer(id: String, hp: Int) -> Player {
        Player(id: id, name: id, strength: 2, dexterity: 2, intelligence: 2, hp: hp, maxHP: 20)
    }

    func testRoomHPReplacesHPFromPlayerData() {
        // 玩家重新加入房間時，玩家資料的 HP 會被寫回 20，不該蓋掉房間上的 HP
        let players = [makePlayer(id: "p1", hp: 20)].applyingHP(["p1": 7])

        XCTAssertEqual(players.first?.hp, 7)
    }

    func testPlayerMissingFromRoomHPKeepsOwnHP() {
        let players = [makePlayer(id: "p1", hp: 20)].applyingHP(["other": 7])

        XCTAssertEqual(players.first?.hp, 20)
    }

    func testPlayerIsDownOnlyAtZeroHP() {
        XCTAssertTrue(makePlayer(id: "p1", hp: 0).isDown)
        XCTAssertFalse(makePlayer(id: "p1", hp: 1).isDown)
    }
}
