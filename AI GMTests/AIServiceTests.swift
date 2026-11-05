//
//  AIServiceTests.swift
//  AI GMTests
//

import XCTest
@testable import AI_GM

final class AIServiceTests: XCTestCase {

    private func makeConfig() -> AIHostConfiguration {
        AIHostConfiguration(
            provider: "OpenAI",
            apiFormat: .openAICompatible,
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4o-mini",
            apiKey: "test-key",
            systemPrompt: "You are a GM."
        )
    }

    private func openAIResponseData(content: String) -> Data {
        let json: [String: Any] = [
            "choices": [
                ["message": ["role": "assistant", "content": content]]
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - JSON Parsing

    func testValidJSONResponse() async throws {
        let mock = MockHTTPClient()
        let narrationJSON = #"{"narration":"你站在一座古老的城堡前。"}"#
        mock.enqueueResponse(data: openAIResponseData(content: narrationJSON), statusCode: 200)

        let service = AIService(configuration: makeConfig(), httpClient: mock)
        let response = try await service.sendMessage(messages: [
            .init(role: .user, content: "test")
        ])

        XCTAssertEqual(response.narration, "你站在一座古老的城堡前。")
    }

    func testFencedJSONResponse() async throws {
        let mock = MockHTTPClient()
        let fenced = """
        ```json
        {"narration":"一條巨龍出現在你面前。"}
        ```
        """
        mock.enqueueResponse(data: openAIResponseData(content: fenced), statusCode: 200)

        let service = AIService(configuration: makeConfig(), httpClient: mock)
        let response = try await service.sendMessage(messages: [
            .init(role: .user, content: "test")
        ])

        XCTAssertEqual(response.narration, "一條巨龍出現在你面前。")
    }

    func testFallbackToPlainText() async throws {
        let mock = MockHTTPClient()
        let plainText = "你走進了一座森林，四周瀰漫著霧氣。"
        mock.enqueueResponse(data: openAIResponseData(content: plainText), statusCode: 200)

        let service = AIService(configuration: makeConfig(), httpClient: mock)
        let response = try await service.sendMessage(messages: [
            .init(role: .user, content: "test")
        ])

        XCTAssertEqual(response.narration, plainText)
    }

    private func parse(_ content: String) async throws -> AIResponse {
        let mock = MockHTTPClient()
        mock.enqueueResponse(data: openAIResponseData(content: content), statusCode: 200)
        let service = AIService(configuration: makeConfig(), httpClient: mock)
        return try await service.sendMessage(messages: [.init(role: .user, content: "test")])
    }

    func testResponseWithoutResultsHasNoResults() async throws {
        let response = try await parse(#"{"narration":"故事。"}"#)

        XCTAssertEqual(response.results, [])
    }

    func testResultsAreParsed() async throws {
        let response = try await parse("""
        {"narration":"故事。","results":[{"player":"P1","stat":"STR","dc":12,"hpChange":-3,"reason":"被砍中"}]}
        """)

        XCTAssertEqual(response.results, [
            AIPlayerResult(player: "P1", stat: "STR", dc: 12, hpChange: -3, reason: "被砍中")
        ])
    }

    func testNullStatAndDifficultyAreAccepted() async throws {
        let response = try await parse("""
        {"narration":"故事。","results":[{"player":"P1","stat":null,"dc":null,"hpChange":0,"reason":null}]}
        """)

        XCTAssertEqual(response.results, [
            AIPlayerResult(player: "P1", stat: nil, dc: nil, hpChange: 0, reason: nil)
        ])
    }

    func testMalformedResultIsSkippedWithoutLosingTheOthers() async throws {
        let response = try await parse("""
        {"narration":"故事。","results":[{"stat":"STR"},"壞掉的",{"player":"P2","hpChange":-1}]}
        """)

        XCTAssertEqual(response.narration, "故事。")
        XCTAssertEqual(response.results, [
            AIPlayerResult(player: "P2", stat: nil, dc: nil, hpChange: -1, reason: nil)
        ])
    }

    func testResultsOfWrongTypeStillKeepNarration() async throws {
        let response = try await parse(#"{"narration":"故事。","results":"沒有結果"}"#)

        XCTAssertEqual(response.narration, "故事。", "results 格式不對時，不該把整段 JSON 當成劇情")
        XCTAssertEqual(response.results, [])
    }

    func testMissingHPChangeCountsAsNoChange() async throws {
        let response = try await parse(#"{"narration":"故事。","results":[{"player":"P1","stat":"DEX","dc":10}]}"#)

        XCTAssertEqual(response.results.first?.hpChange, 0)
        XCTAssertEqual(response.results.first?.dc, 10)
    }

    func testNumbersWrittenAsTextAreAccepted() async throws {
        let response = try await parse("""
        {"narration":"故事。","results":[
          {"player":"P1","dc":"12","hpChange":"-3"},
          {"player":"P2","dc":"高","hpChange":"+4"},
          {"player":"P3","dc":11.0,"hpChange":"−2"},
          {"player":"P4","hpChange":1e300}
        ]}
        """)

        XCTAssertEqual(response.results.map(\.dc), [12, nil, 11, nil])
        XCTAssertEqual(response.results.map(\.hpChange), [-3, 4, -2, 0])
    }

    func testPlusSignedNumberDoesNotBreakTheResponse() async throws {
        let response = try await parse(#"{"narration":"故事。","results":[{"player":"P1","hpChange": +3}]}"#)

        XCTAssertEqual(response.narration, "故事。", "+3 不是合法 JSON，但很多模型會這樣寫，不該把整段 JSON 當成劇情")
        XCTAssertEqual(response.results.first?.hpChange, 3)
    }

    func testEmptyResponseThrows() async {
        let mock = MockHTTPClient()
        mock.enqueueResponse(data: openAIResponseData(content: "   "), statusCode: 200)

        let service = AIService(configuration: makeConfig(), httpClient: mock)

        do {
            _ = try await service.sendMessage(messages: [
                .init(role: .user, content: "test")
            ])
            XCTFail("Expected parseError to be thrown")
        } catch {
            guard case AIService.AIServiceError.parseError = error else {
                XCTFail("Expected parseError, got \(error)")
                return
            }
        }
    }

    // MARK: - Retry Logic

    func testRetryOnServerError() async throws {
        let mock = MockHTTPClient()

        let errorData = try! JSONSerialization.data(withJSONObject: ["error": "Internal Server Error"])
        mock.enqueueResponse(data: errorData, statusCode: 500)

        let narrationJSON = #"{"narration":"成功了！"}"#
        mock.enqueueResponse(data: openAIResponseData(content: narrationJSON), statusCode: 200)

        let service = AIService(configuration: makeConfig(), httpClient: mock)
        let response = try await service.sendMessage(messages: [
            .init(role: .user, content: "test")
        ])

        XCTAssertEqual(response.narration, "成功了！")
        XCTAssertEqual(mock.requestCount, 2, "Should have retried once after 500 error")
    }

    func testNoRetryOnClientError() async {
        let mock = MockHTTPClient()

        let errorData = try! JSONSerialization.data(withJSONObject: ["error": "Unauthorized"])
        mock.enqueueResponse(data: errorData, statusCode: 401)

        let service = AIService(configuration: makeConfig(), httpClient: mock)

        do {
            _ = try await service.sendMessage(messages: [
                .init(role: .user, content: "test")
            ])
            XCTFail("Expected httpError to be thrown")
        } catch {
            guard case AIService.AIServiceError.httpError(let statusCode, _) = error else {
                XCTFail("Expected httpError, got \(error)")
                return
            }
            XCTAssertEqual(statusCode, 401)
            XCTAssertTrue(error.localizedDescription.contains("API Key"), "401 應提示是 API Key 的問題")
            XCTAssertTrue(error.localizedDescription.contains("Unauthorized"), "應保留伺服器回傳的原因")
        }

        XCTAssertEqual(mock.requestCount, 1, "Should NOT retry on 4xx error")
    }

    func testCancellationDuringRetry() async {
        let mock = MockHTTPClient()

        let errorData = try! JSONSerialization.data(withJSONObject: ["error": "Server Error"])
        mock.enqueueResponse(data: errorData, statusCode: 500)
        mock.enqueueResponse(data: errorData, statusCode: 500)

        let service = AIService(configuration: makeConfig(), httpClient: mock)

        let task = Task {
            try await service.sendRawJSON(messages: [
                .init(role: .user, content: "test")
            ])
        }

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(error)")
        }
    }
}
