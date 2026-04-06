//
//  AIHostConfiguration.swift
//  AI GM
//
//  Created by tony on 2026/3/31.
//

import Foundation

enum AIAPIFormat: String, CaseIterable, Codable, Identifiable {
    case openAICompatible
    case ollama

    var id: String {
        rawValue
    }
}

enum AIProviderPreset: String, CaseIterable, Identifiable {
    case openAI
    case deepSeek
    case groq
    case openRouter
    case ollama
    case lmStudio
    case customOpenAICompatible
    case customOllama

    var id: String {
        rawValue
    }

    var provider: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .deepSeek:
            return "DeepSeek"
        case .groq:
            return "Groq"
        case .openRouter:
            return "OpenRouter"
        case .ollama:
            return "Ollama"
        case .lmStudio:
            return "LM Studio"
        case .customOpenAICompatible:
            return "自訂 OpenAI-compatible"
        case .customOllama:
            return "自訂 Ollama"
        }
    }

    var apiFormat: AIAPIFormat {
        switch self {
        case .ollama, .customOllama:
            return .ollama
        default:
            return .openAICompatible
        }
    }

    var baseURL: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .deepSeek:
            return "https://api.deepseek.com/v1"
        case .groq:
            return "https://api.groq.com/openai/v1"
        case .openRouter:
            return "https://openrouter.ai/api/v1"
        case .ollama, .customOllama:
            return "http://localhost:11434"
        case .lmStudio:
            return "http://localhost:1234/v1"
        case .customOpenAICompatible:
            return "https://example.com/v1"
        }
    }

    var model: String {
        switch self {
        case .openAI:
            return "gpt-4o-mini"
        case .deepSeek:
            return "deepseek-chat"
        case .groq:
            return "llama-3.3-70b-versatile"
        case .openRouter:
            return "openai/gpt-4o-mini"
        case .ollama, .customOllama:
            return "llama3.1"
        case .lmStudio:
            return "local-model"
        case .customOpenAICompatible:
            return "custom-model"
        }
    }

    var description: String {
        switch self {
        case .openAI:
            return "官方 OpenAI 端點，適合直接用標準雲端模型。"
        case .deepSeek:
            return "DeepSeek 官方端點，走 OpenAI-compatible 格式。"
        case .groq:
            return "Groq 官方端點，適合低延遲推理。"
        case .openRouter:
            return "OpenRouter 聚合端點，可切多家模型。"
        case .ollama:
            return "本機或區網上的 Ollama 服務。"
        case .lmStudio:
            return "LM Studio 的本機 OpenAI-compatible server。"
        case .customOpenAICompatible:
            return "自架或第三方 OpenAI-compatible 服務。"
        case .customOllama:
            return "自訂 Ollama 位址，適合遠端或區網主機。"
        }
    }

    func apply(to configuration: AIHostConfiguration) -> AIHostConfiguration {
        AIHostConfiguration(
            provider: provider,
            apiFormat: apiFormat,
            baseURL: baseURL,
            model: model,
            apiKey: configuration.apiKey,
            systemPrompt: configuration.systemPrompt
        )
    }

    static func inferred(from configuration: AIHostConfiguration) -> AIProviderPreset {
        let canonicalConfiguration = configuration.canonicalized()

        if let providerMatch = AIProviderPreset.allCases.first(where: {
            $0.provider == canonicalConfiguration.provider &&
            $0.apiFormat == canonicalConfiguration.apiFormat
        }) {
            return providerMatch
        }

        switch canonicalConfiguration.apiFormat {
        case .openAICompatible:
            return .customOpenAICompatible
        case .ollama:
            return .customOllama
        }
    }
}

struct AIHostConfiguration: Codable, Equatable {
    var provider: String
    var apiFormat: AIAPIFormat
    var baseURL: String
    var model: String
    var apiKey: String
    var systemPrompt: String

    enum ValidationError: Error, Equatable {
        case emptyProvider
        case emptyModel
        case emptyBaseURL
        case invalidBaseURL
    }

    var trimmedProvider: String {
        provider.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func canonicalized() -> AIHostConfiguration {
        AIHostConfiguration(
            provider: trimmedProvider,
            apiFormat: apiFormat,
            baseURL: trimmedBaseURL,
            model: trimmedModel,
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            systemPrompt: systemPrompt
        )
    }

    func validated() throws -> AIHostConfiguration {
        let configuration = canonicalized()

        guard !configuration.provider.isEmpty else {
            throw ValidationError.emptyProvider
        }
        guard !configuration.model.isEmpty else {
            throw ValidationError.emptyModel
        }
        guard !configuration.baseURL.isEmpty else {
            throw ValidationError.emptyBaseURL
        }
        guard let url = URL(string: configuration.baseURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            throw ValidationError.invalidBaseURL
        }

        return configuration
    }
}

struct AISettingsSummary: Equatable {
    let title: String
    let subtitle: String
    let badges: [String]

    init(provider: String, model: String, apiFormat: AIAPIFormat) {
        let trimmedProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatBadge = apiFormat.summaryLabel

        title = trimmedProvider.isEmpty ? "AI 未設定" : trimmedProvider
        subtitle = trimmedModel.isEmpty ? "Model 未設定" : trimmedModel
        badges = title == formatBadge ? [title] : [title, formatBadge]
    }
}

struct AISettingsDraft: Equatable {
    var providerPreset: AIProviderPreset
    var apiFormat: AIAPIFormat
    var baseURL: String
    var model: String
    var apiKey: String
    var systemPrompt: String

    var configuration: AIHostConfiguration {
        AIHostConfiguration(
            provider: providerPreset.provider,
            apiFormat: apiFormat,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            systemPrompt: systemPrompt
        )
    }

    init(
        providerPreset: AIProviderPreset,
        apiFormat: AIAPIFormat,
        baseURL: String,
        model: String,
        apiKey: String,
        systemPrompt: String
    ) {
        self.providerPreset = providerPreset
        self.apiFormat = apiFormat
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.systemPrompt = systemPrompt
    }

    init(configuration: AIHostConfiguration, providerPreset: AIProviderPreset) {
        self.init(
            providerPreset: providerPreset,
            apiFormat: configuration.apiFormat,
            baseURL: configuration.baseURL,
            model: configuration.model,
            apiKey: configuration.apiKey,
            systemPrompt: configuration.systemPrompt
        )
    }

    mutating func applyPreset(_ preset: AIProviderPreset) {
        let updated = preset.apply(to: configuration)
        providerPreset = preset
        apiFormat = updated.apiFormat
        baseURL = updated.baseURL
        model = updated.model
        apiKey = updated.apiKey
        systemPrompt = updated.systemPrompt
    }

}

extension AIAPIFormat {
    var summaryLabel: String {
        switch self {
        case .openAICompatible:
            return "OpenAI"
        case .ollama:
            return "Ollama"
        }
    }
}

enum AIHostConfigurationStore {
    private static let defaults = UserDefaults.standard
    private static let lastUsedKey = "hostAIConfig.lastUsed"

    private static func key(campaignId: String) -> String {
        "hostAIConfig.\(campaignId)"
    }

    static func save(_ configuration: AIHostConfiguration, campaignId: String) throws {
        try save(configuration, forKey: key(campaignId: campaignId))
    }

    static func load(campaignId: String) throws -> AIHostConfiguration? {
        try load(forKey: key(campaignId: campaignId))
    }

    static func saveLastUsed(_ configuration: AIHostConfiguration) throws {
        try save(configuration, forKey: lastUsedKey)
    }

    static func loadLastUsed() throws -> AIHostConfiguration? {
        try load(forKey: lastUsedKey)
    }

    static func clearLastUsed() {
        defaults.removeObject(forKey: lastUsedKey)
    }

    private static func save(_ configuration: AIHostConfiguration, forKey key: String) throws {
        let canonicalConfiguration = try configuration.validated()
        let encoder = JSONEncoder()
        let data = try encoder.encode(canonicalConfiguration)
        defaults.set(data, forKey: key)
    }

    private static func load(forKey key: String) throws -> AIHostConfiguration? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(AIHostConfiguration.self, from: data)
        return try decoded.validated()
    }
}
