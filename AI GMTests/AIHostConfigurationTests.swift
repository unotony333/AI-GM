//
//  AIHostConfigurationTests.swift
//  AI GMTests
//

import XCTest
@testable import AI_GM

final class AIHostConfigurationTests: XCTestCase {

    private func makeConfiguration(preset: AIProviderPreset, apiKey: String) -> AIHostConfiguration {
        AIHostConfiguration(
            provider: preset.provider,
            apiFormat: preset.apiFormat,
            baseURL: preset.baseURL,
            model: preset.model,
            apiKey: apiKey,
            systemPrompt: "你是一個TRPG GM。"
        )
    }

    func testCloudProviderWithoutApiKeyCannotHost() {
        let configuration = makeConfiguration(preset: .openRouter, apiKey: "   ")

        XCTAssertThrowsError(try configuration.validatedForHosting()) { error in
            XCTAssertEqual(
                error as? AIHostConfiguration.ValidationError,
                .missingAPIKey(provider: "OpenRouter"),
                "雲端供應商沒填 API Key 應該在建房時就擋下"
            )
        }
    }

    func testCloudProviderWithApiKeyCanHost() throws {
        let configuration = makeConfiguration(preset: .openAI, apiKey: "sk-test")

        XCTAssertEqual(try configuration.validatedForHosting().apiKey, "sk-test")
    }

    func testLocalProvidersCanHostWithoutApiKey() {
        for preset in [AIProviderPreset.ollama, .lmStudio, .customOpenAICompatible, .customOllama] {
            let configuration = makeConfiguration(preset: preset, apiKey: "")

            XCTAssertNoThrow(try configuration.validatedForHosting(), "\(preset.provider) 可以不填 API Key")
        }
    }

    func testSavedConfigurationWithoutApiKeyStillLoads() {
        // 讀取已存設定只檢查格式，沒填 Key 的人才打得開設定補上
        let configuration = makeConfiguration(preset: .openAI, apiKey: "")

        XCTAssertNoThrow(try configuration.validated())
    }
}
